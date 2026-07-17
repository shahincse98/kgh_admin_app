import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../product/controller/product_controller.dart';

class OrderController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final orders = <OrderModel>[].obs;
  final loading = false.obs;
  final hasMore = true.obs;

  final selectedStatus = 'all'.obs;
  final searchText = ''.obs;
  final pendingCount = 0.obs;

  DocumentSnapshot? lastDoc;
  final int limit = 20;

  StreamSubscription? _pendingSub;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
    _listenPendingCount();
    // Re-enrich phones & due whenever users list changes (handles load-order
    // race: orders may arrive before UserController finishes fetching users)
    try {
      final uc = Get.find<UserController>();
      ever(uc.users, (_) => _enrichUserPhones());
    } catch (_) {/* UserController not ready — enrichment runs via try/catch in _enrichUserPhones */}
  }

  void _listenPendingCount() {
    _pendingSub?.cancel();
    _pendingSub = _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snap) { pendingCount.value = snap.docs.length; },
          onError: (_) {},
        );
  }

  @override
  void onClose() {
    _pendingSub?.cancel();
    super.onClose();
  }

  Future<void> fetchOrders({bool loadMore = false}) async {
    if (loading.value) return;

    loading.value = true;

    final statusFilter = selectedStatus.value;
    // 'all' and 'scheduled' both need unfiltered fetch (scheduled is
    // derived from scheduledDeliveryDate, not a status field).
    final needsStatusFilter =
        statusFilter != 'all' && statusFilter != 'scheduled';

    Query query;
    if (needsStatusFilter) {
      query = _db
          .collection('orders')
          .where('status', isEqualTo: statusFilter)
          .orderBy('createdAt', descending: true)
          .limit(limit);
    } else {
      query = _db
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    if (lastDoc != null && loadMore) {
      query = query.startAfterDocument(lastDoc!);
    }

    final snap = await query.get();

    if (snap.docs.isNotEmpty) {
      lastDoc = snap.docs.last;
    }

    final newOrders =
        snap.docs.map((e) => OrderModel.fromFirestore(e)).toList();

    if (loadMore) {
      orders.addAll(newOrders);
    } else {
      orders.assignAll(newOrders);
    }

    if (snap.docs.length < limit) {
      hasMore.value = false;
    }

    _enrichUserPhones();
    loading.value = false;
  }

  /// Fills in userPhone/userDue from the permanently-loaded UserController.
  /// Tries userId match first, then shopName, then shopPhone ↔ user.phone.
  void _enrichUserPhones() {
    try {
      final uc = Get.find<UserController>();
      bool changed = false;
      for (final order in orders) {
        // Already fully enriched
        if (order.userPhone.isNotEmpty && order.userDue != 0) continue;

        UserModel? user;

        // 1. Match by userId (Firebase Auth UID)
        if (order.userId.isNotEmpty) {
          user = uc.users.firstWhereOrNull((u) => u.id == order.userId);
        }

        // 2. Fallback: match by shopName
        if (user == null && order.shopName.isNotEmpty) {
          final nameKey = order.shopName.trim().toLowerCase();
          user = uc.users.firstWhereOrNull(
              (u) => u.shopName.trim().toLowerCase() == nameKey);
        }

        // 3. Fallback: match shopPhone against user.phone
        if (user == null && order.shopPhone.isNotEmpty) {
          user = uc.users
              .firstWhereOrNull((u) => u.phone == order.shopPhone);
        }

        if (user != null) {
          if (order.userPhone.isEmpty && user.phone.isNotEmpty) {
            order.userPhone = user.phone;
            changed = true;
          }
          if (user.totalDue != 0) {
            order.userDue = user.totalDue;
            changed = true;
          }
        }
      }
      if (changed) orders.refresh();
    } catch (_) {/* UserController not ready yet, skip */}
  }

  List<OrderModel> get filteredOrders {
    List<OrderModel> list = orders;
    // 'scheduled' is a derived filter (not a Firestore status field),
    // so we filter it locally. Other status filters are already
    // applied at the Firestore query level in fetchOrders().
    if (selectedStatus.value == 'scheduled') {
      list = list
          .where((o) =>
              (o.scheduledDeliveryDate != null ||
               o.deliveryAssignedSrId.isNotEmpty) &&
              o.status != 'delivered' &&
              o.status != 'cancelled')
          .toList();
    }
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((o) =>
              o.shopName.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.shopPhone.contains(q) ||
              o.userPhone.contains(q) ||
              o.localMemo.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> updateOrderStatus(String id, String status,
      {String? previousStatus, List items = const [], String? deliveredBySrId}) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'delivered') {
      data['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBySrId != null && deliveredBySrId.isNotEmpty) {
        data['deliveredBySrId'] = deliveredBySrId;
      }
    }

    final prev = previousStatus ?? '';

    // ── Stock deduction ───────────────────────────────────────
    // Deduct stock when going to 'delivered' directly from
    // pending/approved (dispatched state already deducted stock).
    final needsStockDeduction = status == 'delivered' &&
        prev != 'dispatched' &&
        prev != 'delivered';

    // ── Stock restoration ─────────────────────────────────────
    // Restore stock when reverting from dispatched/delivered back
    // to pending/approved/cancelled (stock was previously cut).
    final needsStockRestore = (prev == 'dispatched' || prev == 'delivered') &&
        (status == 'pending' ||
            status == 'approved' ||
            status == 'cancelled');

    if ((needsStockDeduction || needsStockRestore) && items.isNotEmpty) {
      final batch = _db.batch();
      for (final item in items) {
        final productId = (item is Map)
            ? (item['productId'] ?? '').toString()
            : '';
        final qty = (item is Map)
            ? (item['quantity'] as num?)?.toInt() ?? 0
            : 0;
        if (productId.isEmpty || qty == 0) continue;
        final delta = needsStockDeduction ? -qty : qty;
        batch.update(_db.collection('products').doc(productId),
            {'stock': FieldValue.increment(delta)});
      }
      batch.update(_db.collection('orders').doc(id), data);
      await batch.commit();

      // Refresh products globally
      try {
        Get.find<ProductController>().fetchProducts(forceRefresh: true);
      } catch (_) {}
    } else {
      await _db.collection('orders').doc(id).update(data);
    }
  }

  /// Update the deliveredAt timestamp for an order (edit delivery date).
  Future<void> updateDeliveredAt(String id, DateTime date) async {
    await _db.collection('orders').doc(id).update({
      'deliveredAt': Timestamp.fromDate(date),
    });
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: date,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  /// Update the createdAt timestamp for an order (edit order date).
  Future<void> updateCreatedAt(String id, DateTime date) async {
    await _db.collection('orders').doc(id).update({
      'createdAt': Timestamp.fromDate(date),
    });
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: date,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  /// Update the dispatchedAt timestamp for an order.
  Future<void> updateDispatchedAt(String id, DateTime date) async {
    await _db.collection('orders').doc(id).update({
      'dispatchedAt': Timestamp.fromDate(date),
    });
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: date,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  Future<void> dispatchOrder({
    required String orderId,
    required List items,
    required String memoNumber,
  }) async {
    final currentUser = await _getCurrentUserId();

    // 1. Deduct stock
    final batch = _db.batch();
    for (final item in items) {
      final productId = (item is Map)
          ? (item['productId'] ?? '').toString()
          : '';
      final qty = (item is Map)
          ? (item['quantity'] as num?)?.toInt() ?? 0
          : 0;
      if (productId.isEmpty || qty == 0) continue;
      final ref = _db.collection('products').doc(productId);
      batch.update(ref, {'stock': FieldValue.increment(-qty)});
    }

    // 2. Update order with dispatch info
    batch.update(_db.collection('orders').doc(orderId), {
      'status': 'dispatched',
      'memoNumber': memoNumber,
      'dispatchedAt': FieldValue.serverTimestamp(),
      'dispatchedBy': currentUser,
    });

    await batch.commit();

    // Refresh products globally
    try {
      Get.find<ProductController>().fetchProducts(forceRefresh: true);
    } catch (_) {}

    // 3. Update local cache
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: 'dispatched',
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: memoNumber,
        dispatchedAt: DateTime.now(),
        dispatchedBy: currentUser,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  Future<String> _getCurrentUserId() async {
    try {
      final auth = Get.find<AuthController>();
      return auth.currentUser?.uid ?? '';
    } catch (_) {}
    return '';
  }

  Future<void> updatePaidAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'paidAmount': amount});
  }

  Future<void> setScheduledDelivery(String id, DateTime? date) async {
    await _db.collection('orders').doc(id).update({
      'scheduledDeliveryDate':
          date != null ? Timestamp.fromDate(date) : FieldValue.delete(),
    });
    // Update locally so the list view reflects the change immediately
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: date,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }

  Future<void> assignDelivery(
      String orderId, String srId, String srName, DateTime? date) async {
    final updates = <String, dynamic>{};
    if (srId.isNotEmpty) {
      updates['deliveryAssignedSrId'] = srId;
      updates['deliveryAssignedSrName'] = srName;
    } else {
      updates['deliveryAssignedSrId'] = FieldValue.delete();
      updates['deliveryAssignedSrName'] = FieldValue.delete();
    }
    if (date != null) {
      updates['scheduledDeliveryDate'] = Timestamp.fromDate(date);
    }
    await _db.collection('orders').doc(orderId).update(updates);
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: date ?? o.scheduledDeliveryDate,
        deliveryAssignedSrId: srId,
        deliveryAssignedSrName: srName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }

  Future<void> updateUserDue(String userId, int newDue) async {
    await _db.collection('users').doc(userId).update({'totalDue': newDue});
    // Update local UserController cache
    try {
      final uc = Get.find<UserController>();
      final idx = uc.users.indexWhere((u) => u.id == userId);
      if (idx != -1) {
        final u = uc.users[idx];
        uc.users[idx] = UserModel(
          id: u.id,
          shopName: u.shopName,
          proprietorName: u.proprietorName,
          phone: u.phone,
          email: u.email,
          address: u.address,
          deliveryDay: u.deliveryDay,
          totalDue: newDue,
          totalPayableToCustomer: u.totalPayableToCustomer,
          isBlocked: u.isBlocked,
          createdAt: u.createdAt,
        );
      }
    } catch (_) {}
  }

  Future<void> recordDuePayment({
    required String orderId,
    required String userId,
    required int amount,
    required String paymentMethod,
    required DateTime date,
    String note = '',
  }) async {
    final batch = _db.batch();

    // 1. Save payment record in orders/{orderId}/due_payments/
    final payRef = _db
        .collection('orders')
        .doc(orderId)
        .collection('due_payments')
        .doc();
    batch.set(payRef, {
      'amount': amount,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Increment order's paidAmount
    batch.update(_db.collection('orders').doc(orderId), {
      'paidAmount': FieldValue.increment(amount),
    });

    // 3. Decrement user's totalDue
    if (userId.isNotEmpty) {
      batch.update(_db.collection('users').doc(userId), {
        'totalDue': FieldValue.increment(-amount),
      });
    }

    await batch.commit();

    // Update local UserController cache
    if (userId.isNotEmpty) {
      try {
        final uc = Get.find<UserController>();
        final idx = uc.users.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          final u = uc.users[idx];
          final newDue = (u.totalDue - amount).clamp(0, 9999999);
          uc.users[idx] = UserModel(
            id: u.id,
            shopName: u.shopName,
            proprietorName: u.proprietorName,
            phone: u.phone,
            email: u.email,
            address: u.address,
            deliveryDay: u.deliveryDay,
            totalDue: newDue,
            totalPayableToCustomer: u.totalPayableToCustomer,
            isBlocked: u.isBlocked,
            createdAt: u.createdAt,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> updateOrderItems(String id, List<OrderItem> items) async {
    final newTotal =
        items.fold<num>(0, (s, i) => s + i.totalPrice);
    await _db.collection('orders').doc(id).update({
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': newTotal,
    });
    // Update locally — no Firestore re-fetch needed
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: items,
        status: o.status,
        totalAmount: newTotal.toDouble(),
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }

  Future<void> updateItemPurchasePrice(String orderId, int itemIndex, num purchasePrice) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final o = orders[idx];
    final updatedItems = o.items.toList();
    if (itemIndex < 0 || itemIndex >= updatedItems.length) return;
    updatedItems[itemIndex] = OrderItem(
      productId: updatedItems[itemIndex].productId,
      productName: updatedItems[itemIndex].productName,
      image: updatedItems[itemIndex].image,
      quantity: updatedItems[itemIndex].quantity,
      pricePerUnit: updatedItems[itemIndex].pricePerUnit,
      totalPrice: updatedItems[itemIndex].totalPrice,
      purchasePrice: purchasePrice,
    );
    await _db.collection('orders').doc(orderId).update({
      'items': updatedItems.map((i) => i.toMap()).toList(),
    });
    orders[idx] = OrderModel(
      id: o.id,
      createdAt: o.createdAt,
      items: updatedItems,
      status: o.status,
      totalAmount: o.totalAmount,
      paidAmount: o.paidAmount,
      shopName: o.shopName,
      shopAddress: o.shopAddress,
      shopPhone: o.shopPhone,
      userId: o.userId,
      orderedBy: o.orderedBy,
      orderedByEmail: o.orderedByEmail,
      deliveredBySrId: o.deliveredBySrId,
      commissionConfirmed: o.commissionConfirmed,
      scheduledDeliveryDate: o.scheduledDeliveryDate,
      deliveryAssignedSrId: o.deliveryAssignedSrId,
      deliveryAssignedSrName: o.deliveryAssignedSrName,
      memoNumber: o.memoNumber,
      dispatchedAt: o.dispatchedAt,
      dispatchedBy: o.dispatchedBy,
      deliveredAt: o.deliveredAt,
      localMemo: o.localMemo,
      returnAmount: o.returnAmount,
      deductionAmount: o.deductionAmount,
      previousDue: o.previousDue,
      discountAmount: o.discountAmount,
      userPhone: o.userPhone,
      userDue: o.userDue,
    );
  }

  Future<void> changeCustomer({
      required String orderId,
      required String userId,
    required String shopName,
    required String shopPhone,
    required String shopAddress,
    required String userPhone,
    required int userDue,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'userId': userId,
      'shopName': shopName,
      'shopPhone': shopPhone,
      'shopAddress': shopAddress,
      'userPhone': userPhone,
      'userDue': userDue,
    });

    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        userId: userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: userPhone,
        userDue: userDue,
      );
      orders.refresh();
    }
  }

  /// Save the total return/deduction amount on the order.
  Future<void> saveReturnAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'returnAmount': amount});
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: amount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  /// Save the total replace deduction amount on the order.
  Future<void> saveDeductionAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'deductionAmount': amount});
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: amount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  /// Save discount amount on the order.
  Future<void> saveDiscountAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'discountAmount': amount});
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: o.deliveredBySrId,
        commissionConfirmed: o.commissionConfirmed,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: amount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  void changeFilter(String value) {
    if (selectedStatus.value == value) return;
    selectedStatus.value = value;
    lastDoc = null;
    hasMore.value = true;
    fetchOrders();
  }

  /// Admin deletes an order. If the order was dispatched or delivered,
  /// stock is restored first. Commission records (if any) are also
  /// removed so that SR ledger stays consistent.
  Future<void> deleteOrder(String orderId) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final o = orders[idx];

    final batch = _db.batch();

    // 1. Restore stock if it was deducted (dispatched or delivered)
    if (o.status == 'dispatched' || o.status == 'delivered') {
      for (final item in o.items) {
        if (item.productId.isEmpty) continue;
        batch.update(
          _db.collection('products').doc(item.productId),
          {'stock': FieldValue.increment(item.quantity)},
        );
      }
    }

    // 2. Delete commission payment record (if any)
    if (o.commissionConfirmed) {
      final paySnap = await _db
          .collection('sr_payments')
          .where('orderId', isEqualTo: orderId)
          .get();
      for (final doc in paySnap.docs) {
        batch.delete(doc.reference);
      }
    }

    // 3. Delete the order document
    batch.delete(_db.collection('orders').doc(orderId));

    await batch.commit();

    // 4. Refresh products globally
    try {
      Get.find<ProductController>().fetchProducts(forceRefresh: true);
    } catch (_) {}

    // 5. Remove from local cache
    orders.removeAt(idx);
  }

  /// Admin confirms delivery and credits SR commission.
  /// Sets commissionConfirmed=true and records the SR doc ID on the order.
  Future<void> confirmDeliveryWithCommission({
    required String orderId,
    required String srDocId,
    required num orderTotal,
  }) async {
    // 1. Mark commission confirmed on the order
    await _db.collection('orders').doc(orderId).update({
      'commissionConfirmed': true,
      'deliveredBySrId': srDocId,
      'commissionConfirmedAt': FieldValue.serverTimestamp(),
    });

    // 2. Fetch SR profile to get commission %
    final srDoc = await _db.collection('sr_staff').doc(srDocId).get();
    if (!srDoc.exists) return;
    final commPct = (srDoc.data()?['commissionPercent'] as num?)?.toDouble() ?? 0;
    final commission = orderTotal * (commPct / 100.0);

    // 3. Write a commission entry in sr_payments
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await _db.collection('sr_payments').add({
      'srId': srDocId,
      'orderId': orderId,
      'type': 'commission',
      'amount': commission,
      'month': monthKey,
      'note': 'অর্ডার ডেলিভারি কমিশন',
      'paidAt': FieldValue.serverTimestamp(),
    });

    // Update locally — no Firestore re-fetch needed
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final o = orders[idx];
      orders[idx] = OrderModel(
        id: o.id,
        createdAt: o.createdAt,
        items: o.items,
        status: o.status,
        totalAmount: o.totalAmount,
        paidAmount: o.paidAmount,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        shopPhone: o.shopPhone,
        userId: o.userId,
        orderedBy: o.orderedBy,
        orderedByEmail: o.orderedByEmail,
        deliveredBySrId: srDocId,
        commissionConfirmed: true,
        scheduledDeliveryDate: o.scheduledDeliveryDate,
        deliveryAssignedSrId: o.deliveryAssignedSrId,
        deliveryAssignedSrName: o.deliveryAssignedSrName,
        memoNumber: o.memoNumber,
        dispatchedAt: o.dispatchedAt,
        dispatchedBy: o.dispatchedBy,
        deliveredAt: o.deliveredAt,
        localMemo: o.localMemo,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }
}
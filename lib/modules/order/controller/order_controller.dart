import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../product/controller/product_controller.dart';
import '../../replace/controller/admin_replace_controller.dart';
import '../../replace/model/admin_replace_model.dart';
import '../../stock_in/controller/stock_in_controller.dart';
import '../../stock_in/model/stock_in_model.dart';
import '../model/delivery_models.dart';

class OrderController extends GetxController {
  OrderController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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

    Query query;
    if (statusFilter == 'scheduled') {
      // Scheduled: query orders that have a scheduledDeliveryDate set
      query = _db
          .collection('orders')
          .where('scheduledDeliveryDate', isGreaterThan: Timestamp.fromDate(DateTime(2020)))
          .orderBy('scheduledDeliveryDate', descending: true)
          .limit(limit);
    } else if (statusFilter != 'all') {
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
          // Always take the customer's current due; the order carries only a
          // snapshot from the moment it was placed.
          if (order.userDue != user.totalDue) {
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
    // 'scheduled' filter now queries Firestore directly with scheduledDeliveryDate.
    // But we still need to exclude delivered/cancelled locally since the
    // Firestore query returns all scheduled orders regardless of status.
    if (selectedStatus.value == 'scheduled') {
      list = list
          .where((o) => o.status != 'delivered' && o.status != 'cancelled')
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

  /// Changes the order status. Stock moves are derived from the status stored
  /// in Firestore (read inside a transaction), not from what the screen last
  /// saw, so a double tap or a second device can never cut or restore stock
  /// twice. Delivery itself goes through [completeDelivery].
  Future<void> updateOrderStatus(String id, String status,
      {String? deliveredBySrId, DateTime? deliveryDate}) async {
    final orderRef = _db.collection('orders').doc(id);
    var applied = _ProductDeltas();

    await _db.runTransaction((tx) async {
      final deltas = _ProductDeltas();
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final prev = _statusOf(o);
      if (prev == status) {
        applied = deltas;
        return;
      }

      final data = <String, dynamic>{'status': status};
      if (status == 'delivered') {
        data['deliveredAt'] = deliveryDate != null
            ? Timestamp.fromDate(deliveryDate)
            : FieldValue.serverTimestamp();
        if (deliveredBySrId != null && deliveredBySrId.isNotEmpty) {
          data['deliveredBySrId'] = deliveredBySrId;
        }
      }

      // Deduct stock when going to 'delivered' directly (dispatch already
      // deducted it). Restore stock when leaving dispatched/delivered.
      final needsStockDeduction = status == 'delivered' && prev != 'dispatched';
      final needsStockRestore = (prev == 'dispatched' || prev == 'delivered') &&
          (status == 'pending' || status == 'approved' || status == 'cancelled');
      if (needsStockDeduction || needsStockRestore) {
        for (final item in _itemsOf(o)) {
          deltas.addStock(item.productId,
              needsStockDeduction ? -item.quantity : item.quantity);
        }
      }
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      tx.update(orderRef, data);
      _writeProductDeltas(tx, deltas);
      applied = deltas;
    });

    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(id);
  }

  /// Update the deliveredAt timestamp for an order (edit delivery date).
  /// Corrects the delivery date. The payments taken at delivery move with
  /// it, so the sale and the money stay on the same day in the daily report.
  /// Money collected later (on a re-open) keeps its own date.
  Future<void> updateDeliveredAt(String id, DateTime date) async {
    final ref = _db.collection('orders').doc(id);
    await _db.runTransaction((tx) async {
      final o = (await tx.get(ref)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final payments = _mapsOf(o['payments']);
      var moved = false;
      for (var i = 0; i < payments.length; i++) {
        if (payments[i]['laterCollection'] == true) continue;
        payments[i] = {...payments[i], 'date': Timestamp.fromDate(date)};
        moved = true;
      }
      final days = <String>{
        for (final p in payments)
          if (p['date'] is Timestamp)
            paymentDayKey((p['date'] as Timestamp).toDate()),
      }.toList();
      tx.update(ref, {
        'deliveredAt': Timestamp.fromDate(date),
        if (moved) 'payments': payments,
        if (moved) 'paymentDays': days,
      });
    });
    await _afterOrderWrite(id);
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
      orders.refresh();
    }
  }

  /// Stock-out (dispatch). Runs in a transaction that re-reads the order, so
  /// an order that was already dispatched/delivered is refused instead of
  /// having its stock cut a second time.
  Future<void> dispatchOrder({
    required String orderId,
    required String memoNumber,
  }) async {
    final currentUser = await _getCurrentUserId();
    final orderRef = _db.collection('orders').doc(orderId);
    var applied = _ProductDeltas();

    await _db.runTransaction((tx) async {
      final deltas = _ProductDeltas();
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final status = _statusOf(o);
      if (status == 'dispatched' || status == 'delivered') {
        throw OrderOpException('অর্ডারটি আগেই স্টক আউট হয়েছে'.tr);
      }
      if (status == 'cancelled') {
        throw OrderOpException('বাতিল অর্ডার dispatch করা যাবে না'.tr);
      }
      for (final item in _itemsOf(o)) {
        deltas.addStock(item.productId, -item.quantity);
      }
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      tx.update(orderRef, {
        'status': 'dispatched',
        'memoNumber': memoNumber,
        'dispatchedAt': FieldValue.serverTimestamp(),
        'dispatchedBy': currentUser,
      });
      _writeProductDeltas(tx, deltas);
      applied = deltas;
    });

    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(orderId);
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }

  /// Mirrors a customer's new totalDue into the local caches (Firestore has
  /// already been written by the caller's transaction).
  void _applyUserDueLocally(String userId, int newDue) {
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
        uc.users.refresh();
      }
    } catch (_) {}
    bool ordersChanged = false;
    for (final o in orders) {
      if (o.userId == userId && o.userDue != newDue) {
        o.userDue = newDue;
        ordersChanged = true;
      }
    }
    if (ordersChanged) orders.refresh();
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

  /// Saves edited order items. If the order's stock has already gone out
  /// (dispatched/delivered) the stock difference is applied too, and for a
  /// delivered order the change in total is applied to the customer's due.
  Future<void> updateOrderItems(String id, List<OrderItem> items) async {
    final newTotal = items.fold<num>(0, (s, i) => s + i.totalPrice);
    final orderRef = _db.collection('orders').doc(id);
    var applied = _ProductDeltas();
    var userId = '';
    int? newDue;
    // Resolve the customer before the transaction (reads must come first),
    // so a wrong or missing id does not silently skip the due update.
    final orderBefore = (await orderRef.get()).data();
    final customerId =
        orderBefore == null ? '' : await _resolveCustomerId(orderBefore);

    await _db.runTransaction((tx) async {
      final deltas = _ProductDeltas();
      newDue = null;
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final status = _statusOf(o);
      userId = customerId;

      if (status == 'dispatched' || status == 'delivered') {
        for (final old in _itemsOf(o)) {
          deltas.addStock(old.productId, old.quantity);
        }
        for (final i in items) {
          deltas.addStock(i.productId, -i.quantity);
        }
      }
      final totalDelta = newTotal - _num(o['totalAmount']);
      final userRef = (status == 'delivered' && userId.isNotEmpty && totalDelta != 0)
          ? _db.collection('users').doc(userId)
          : null;
      final userSnap = userRef == null ? null : await tx.get(userRef);
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      tx.update(orderRef, {
        'items': items.map((i) => i.toMap()).toList(),
        'totalAmount': newTotal,
      });
      if (userSnap != null && userSnap.exists) {
        newDue = _clampDue(_num(userSnap.data()!['totalDue']) + totalDelta);
        tx.update(userRef!, {'totalDue': newDue});
      }
      _writeProductDeltas(tx, deltas);
      applied = deltas;
    });

    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(id, userId: userId, newDue: newDue);
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
      replaceItems: o.replaceItems,
      returnItems: o.returnItems,
      isDueCollection: o.isDueCollection,
      returnAmount: o.returnAmount,
      deductionAmount: o.deductionAmount,
      previousDue: o.previousDue,
      discountAmount: o.discountAmount,
      paymentMethod: o.paymentMethod,
      payments: o.payments,
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
        userPhone: userPhone,
        userDue: userDue,
      );
      orders.refresh();
    }
  }

  // ── Delivery / replace / return / money edits ─────────────────
  //
  // Every operation below touches several documents (order, customer due,
  // product stock, replace entries, stock-in entries). Each one runs as a
  // single Firestore transaction: either everything is written or nothing
  // is, and all amounts are computed from freshly-read values, never from
  // what the screen had cached.

  static const _maxDue = 9999999;

  /// Delivers the order (or, when it is already delivered, adds extra
  /// payments / replaces / returns to it) in one atomic transaction.
  ///
  /// [expectAlreadyDelivered] is what the screen believed; if Firestore says
  /// otherwise (someone else delivered or reverted it meanwhile) nothing is
  /// written and an [OrderOpException] is thrown.
  Future<OrderMoneyState> completeDelivery({
    required String orderId,
    required bool expectAlreadyDelivered,
    String? deliveredBySrId,
    required DateTime deliveryDate,
    List<Map<String, dynamic>> payments = const [],
    String paymentMethod = '',
    num discount = 0,
    String localMemo = '',
    List<ReplaceLine> replaceLines = const [],
    List<ReturnLine> returnLines = const [],
    List<String> pendingReplaceIds = const [],
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final createdBy = await _getCurrentUserId();
    final now = DateTime.now();
    // Resolve the customer before the transaction (reads must come first).
    final orderBefore = (await orderRef.get()).data();
    final customerId =
        orderBefore == null ? '' : await _resolveCustomerId(orderBefore);
    // Ids are allocated once, outside the transaction, so a retried
    // transaction can never create duplicate replace / stock-in entries.
    final replaceRefs = [
      for (final l in replaceLines)
        l.createsReplaceEntry
            ? _db.collection('admin_replace_entries').doc()
            : null,
    ];
    final stockInRefs = [
      for (final _ in returnLines) _db.collection('stock_ins').doc(),
    ];
    final returnNote = '${'অর্ডার'.tr} #$orderId — ফেরত';
    var applied = _ProductDeltas();
    var userId = '';
    var returnSource = '';

    final result = await _db.runTransaction<OrderMoneyState>((tx) async {
      final deltas = _ProductDeltas();

      // ── Reads (all before any write) ──
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final status = _statusOf(o);
      if (status == 'cancelled') {
        throw OrderOpException('বাতিল অর্ডার ডেলিভার করা যাবে না'.tr);
      }
      final alreadyDelivered = status == 'delivered';
      if (alreadyDelivered != expectAlreadyDelivered) {
        throw OrderOpException(_staleMessage);
      }

      userId = customerId;
      final customerName = (o['shopName'] ?? '').toString();
      final customerPhone = (o['shopPhone'] ?? '').toString();
      final customerAddress = (o['shopAddress'] ?? '').toString();
      returnSource = customerName;
      final userRef = userId.isEmpty ? null : _db.collection('users').doc(userId);
      final userSnap = userRef == null ? null : await tx.get(userRef);
      final userExists = userSnap?.exists ?? false;

      final pendingSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in pendingReplaceIds) {
        pendingSnaps
            .add(await tx.get(_db.collection('admin_replace_entries').doc(id)));
      }

      // ── Stock ──
      // Order items leave stock now, unless dispatch already cut them.
      if (!alreadyDelivered && status != 'dispatched') {
        for (final item in _itemsOf(o)) {
          deltas.addStock(item.productId, -item.quantity);
        }
      }
      for (final l in replaceLines) {
        if (l.takesStockOut) deltas.addStock(l.productId, -l.quantity);
        if (l.createsReplaceEntry) deltas.addReplaceCount(l.productId, l.quantity);
      }
      final pendingToDeliver = <DocumentSnapshot<Map<String, dynamic>>>[];
      var skipped = 0;
      for (final s in pendingSnaps) {
        final d = s.data();
        if (d == null || d['deliveredToCustomer'] == true) {
          skipped++;
          continue;
        }
        pendingToDeliver.add(s);
        if (d['customerResolutionType'] == 'product_replace') {
          deltas.addStock((d['replaceProductId'] ?? '').toString(),
              -_num(d['quantity']).round());
        }
      }
      for (final r in returnLines) {
        deltas.addStock(r.productId, r.quantity);
      }
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      // ── Money ──
      final paidNow = payments.fold<num>(0, (s, p) => s + _num(p['amount']));
      final deduction = replaceLines
          .where((l) => l.isMoneyDeduct)
          .fold<num>(0, (s, l) => s + l.deductionAmount);
      final returnTotal = returnLines.fold<num>(0, (s, r) => s + r.total);
      final credit = paidNow + deduction + returnTotal;

      final total = _num(o['totalAmount']);
      final paidBefore = _num(o['paidAmount']);
      final discountBefore = _num(o['discountAmount']);
      final dueBefore =
          userExists ? _num(userSnap!.data()!['totalDue']).round() : 0;
      // First delivery adds this order's remaining amount to the due; a
      // re-open only subtracts what is credited now.
      final dueDelta = alreadyDelivered
          ? -(credit + discount)
          : (total - paidBefore - discountBefore) - credit - discount;
      final newDue = _clampDue(dueBefore + dueDelta);

      // Each payment carries the day it was received, so the daily report
      // counts money taken on a later re-open on that later day.
      final paidOn = alreadyDelivered ? now : deliveryDate;
      final datedPayments = [
        for (final p in payments)
          {
            ...p,
            'date': Timestamp.fromDate(paidOn),
            // Taken after the delivery, so it belongs to its own day and
            // must not move when the delivery date is corrected.
            if (alreadyDelivered) 'laterCollection': true,
            if (deliveredBySrId != null && deliveredBySrId.isNotEmpty)
              'srId': deliveredBySrId,
          },
      ];
      final paymentDays = {
        ...((o['paymentDays'] as List?) ?? const []).map((e) => e.toString()),
        if (payments.isNotEmpty) paymentDayKey(paidOn),
      }.toList();

      final newReplaceItems = <Map<String, dynamic>>[
        for (var i = 0; i < replaceLines.length; i++)
          _replaceItemMap(replaceLines[i], replaceRefs[i]?.id),
      ];
      final update = <String, dynamic>{
        'paidAmount': paidBefore + credit,
        'discountAmount': discountBefore + discount,
        'deductionAmount': _num(o['deductionAmount']) + deduction,
        'returnAmount': _num(o['returnAmount']) + returnTotal,
        'payments': [..._mapsOf(o['payments']), ...datedPayments],
        if (payments.isNotEmpty) 'paymentDays': paymentDays,
        'replaceItems': [..._mapsOf(o['replaceItems']), ...newReplaceItems],
        // What the customer returned, so the order shows it (the stock-in
        // entries hold the same lines).
        if (returnLines.isNotEmpty)
          'returnItems': [
            ..._mapsOf(o['returnItems']),
            for (var i = 0; i < returnLines.length; i++)
              {
                'productId': returnLines[i].productId,
                'productName': returnLines[i].productName,
                'quantity': returnLines[i].quantity,
                'unitPrice': returnLines[i].unitPrice,
                'totalPrice': returnLines[i].total,
                'stockInId': stockInRefs[i].id,
                'date': Timestamp.fromDate(alreadyDelivered ? now : deliveryDate),
              },
          ],
        if (payments.isNotEmpty || !alreadyDelivered)
          'paymentMethod': paymentMethod,
        if (localMemo.isNotEmpty) 'localMemo': localMemo,
      };
      if (userExists && _userIdOf(o) != userId) update['userId'] = userId;
      if (!alreadyDelivered) {
        update['status'] = 'delivered';
        update['deliveredAt'] = Timestamp.fromDate(deliveryDate);
        if (deliveredBySrId != null && deliveredBySrId.isNotEmpty) {
          update['deliveredBySrId'] = deliveredBySrId;
        }
        if (userExists) update['previousDue'] = dueBefore;
      }

      // ── Writes ──
      tx.update(orderRef, update);
      if (userExists) tx.update(userRef!, {'totalDue': newDue});
      for (var i = 0; i < replaceLines.length; i++) {
        final ref = replaceRefs[i];
        if (ref == null) continue;
        tx.set(
          ref,
          _customerInEntry(
            id: ref.id,
            orderId: orderId,
            line: replaceLines[i],
            customerId: userId,
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
            date: deliveryDate,
            now: now,
            note: '${'ডেলিভারি'.tr} #$orderId এ ফেরত',
          ),
        );
      }
      for (final s in pendingToDeliver) {
        tx.update(s.reference, {
          'deliveredToCustomer': true,
          'deliveredToCustomerAt': Timestamp.fromDate(now),
          'note': '${'অর্ডার'.tr} #$orderId এর সাথে ডেলিভারি',
        });
      }
      for (var i = 0; i < returnLines.length; i++) {
        final r = returnLines[i];
        tx.set(stockInRefs[i], {
          'productId': r.productId,
          'productName': r.productName,
          'image': r.image,
          'quantity': r.quantity,
          'unitPrice': r.unitPrice,
          'totalPrice': r.total,
          'source': customerName,
          'note': returnNote,
          'orderId': orderId,
          'date': Timestamp.fromDate(deliveryDate),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': createdBy,
        });
      }
      _writeProductDeltas(tx, deltas);
      applied = deltas;

      return _moneyStateOf({...o, ...update},
          newUserDue: userExists ? newDue : null, skipped: skipped);
    });

    // ── Local caches (Firestore is already consistent) ──
    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(orderId, userId: userId, newDue: result.newUserDue);
    if (replaceLines.isNotEmpty || pendingReplaceIds.isNotEmpty) {
      _refreshReplaceEntries();
    }
    if (returnLines.isNotEmpty && Get.isRegistered<StockInController>()) {
      Get.find<StockInController>().entries.insertAll(0, [
        for (var i = 0; i < returnLines.length; i++)
          StockInModel(
            id: stockInRefs[i].id,
            productId: returnLines[i].productId,
            productName: returnLines[i].productName,
            image: returnLines[i].image,
            quantity: returnLines[i].quantity,
            unitPrice: returnLines[i].unitPrice,
            totalPrice: returnLines[i].total,
            source: returnSource,
            note: returnNote,
            date: deliveryDate,
            createdAt: now,
            createdBy: createdBy,
          ),
      ]);
    }
    return result;
  }

  /// Adds one replace line to an order from the order details page.
  /// A money_deduct line credits the customer the same way it does at
  /// delivery: paid/deduction go up, and if the order is already delivered
  /// the customer's due goes down.
  Future<OrderMoneyState> addReplaceToOrder({
    required String orderId,
    required ReplaceLine line,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final entryRef = line.createsReplaceEntry
        ? _db.collection('admin_replace_entries').doc()
        : null;
    final now = DateTime.now();
    var applied = _ProductDeltas();
    var userId = '';
    // Resolve the customer before the transaction (reads must come first),
    // so a wrong or missing id does not silently skip the due update.
    final orderBefore = (await orderRef.get()).data();
    final customerId =
        orderBefore == null ? '' : await _resolveCustomerId(orderBefore);

    final result = await _db.runTransaction<OrderMoneyState>((tx) async {
      final deltas = _ProductDeltas();
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final status = _statusOf(o);
      if (status == 'cancelled') {
        throw OrderOpException('বাতিল অর্ডারে রিপ্লেস যোগ করা যাবে না'.tr);
      }
      userId = customerId;
      final credit = line.isMoneyDeduct ? line.deductionAmount : 0;
      final userRef = (credit > 0 && status == 'delivered' && userId.isNotEmpty)
          ? _db.collection('users').doc(userId)
          : null;
      final userSnap = userRef == null ? null : await tx.get(userRef);
      final userExists = userSnap?.exists ?? false;

      if (line.takesStockOut) deltas.addStock(line.productId, -line.quantity);
      if (line.createsReplaceEntry) {
        deltas.addReplaceCount(line.productId, line.quantity);
      }
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      final update = <String, dynamic>{
        'replaceItems': [
          ..._mapsOf(o['replaceItems']),
          _replaceItemMap(line, entryRef?.id),
        ],
        if (credit > 0) 'paidAmount': _num(o['paidAmount']) + credit,
        if (credit > 0) 'deductionAmount': _num(o['deductionAmount']) + credit,
      };
      int? newDue;
      if (userExists) {
        newDue = _clampDue(_num(userSnap!.data()!['totalDue']) - credit);
      }

      tx.update(orderRef, update);
      if (newDue != null) tx.update(userRef!, {'totalDue': newDue});
      if (entryRef != null) {
        tx.set(
          entryRef,
          _customerInEntry(
            id: entryRef.id,
            orderId: orderId,
            line: line,
            customerId: userId,
            customerName: (o['shopName'] ?? '').toString(),
            customerPhone: (o['shopPhone'] ?? '').toString(),
            customerAddress: (o['shopAddress'] ?? '').toString(),
            date: now,
            now: now,
            note: '${'অর্ডার'.tr} #$orderId — ${'রিপ্লেস'.tr}',
          ),
        );
      }
      _writeProductDeltas(tx, deltas);
      applied = deltas;
      return _moneyStateOf({...o, ...update}, newUserDue: newDue);
    });

    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(orderId, userId: userId, newDue: result.newUserDue);
    if (line.createsReplaceEntry) _refreshReplaceEntries();
    return result;
  }

  /// Removes one replace line from an order and reverses exactly what adding
  /// it did (stock, replace entry, and — for lines added by this version of
  /// the app, marked `accounted` — the money credit).
  ///
  /// Refused when the linked replace entry has already been resolved in the
  /// replace section, because its stock has moved on from there.
  Future<OrderMoneyState> removeReplaceFromOrder({
    required String orderId,
    required Map<String, dynamic> item,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final type = (item['resolutionType'] ?? '').toString();
    final productId = (item['productId'] ?? '').toString();
    final qty = _num(item['quantity']).round();
    final accounted = item['accounted'] == true;

    var entryId = (item['replaceEntryId'] ?? '').toString();
    if (entryId.isEmpty && type != 'replace_given') {
      entryId = await _findLegacyReplaceEntry(orderId, item) ?? '';
    }
    final entryRef = entryId.isEmpty
        ? null
        : _db.collection('admin_replace_entries').doc(entryId);
    var applied = _ProductDeltas();
    var userId = '';
    // Resolve the customer before the transaction (reads must come first),
    // so a wrong or missing id does not silently skip the due update.
    final orderBefore = (await orderRef.get()).data();
    final customerId =
        orderBefore == null ? '' : await _resolveCustomerId(orderBefore);

    final result = await _db.runTransaction<OrderMoneyState>((tx) async {
      final deltas = _ProductDeltas();
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      final list = _mapsOf(o['replaceItems']);
      final idx = list.indexWhere((m) => _sameReplaceItem(m, item));
      if (idx == -1) throw OrderOpException(_staleMessage);

      final entrySnap = entryRef == null ? null : await tx.get(entryRef);
      final entry = entrySnap?.data();
      if (entry != null && entry['status'] == 'resolved') {
        throw OrderOpException(
            'এই রিপ্লেসটি রিপ্লেস পেজে ইতিমধ্যে সমাধান হয়েছে — সেখান থেকে ঠিক করুন'
                .tr);
      }

      userId = customerId;
      final credit = (type == 'money_deduct' && accounted)
          ? _num(item['deductionAmount'])
          : 0;
      final userRef =
          (credit > 0 && _statusOf(o) == 'delivered' && userId.isNotEmpty)
              ? _db.collection('users').doc(userId)
              : null;
      final userSnap = userRef == null ? null : await tx.get(userRef);
      final userExists = userSnap?.exists ?? false;

      if (type == 'product_replace' || type == 'replace_given') {
        deltas.addStock(productId, qty);
      }
      if (entry != null) {
        deltas.addReplaceCount((entry['productId'] ?? '').toString(),
            -_num(entry['quantity']).round());
      }
      deltas.keepOnly(await _existingProducts(tx, deltas.ids));

      list.removeAt(idx);
      final update = <String, dynamic>{
        'replaceItems': list,
        if (credit > 0) 'paidAmount': _num(o['paidAmount']) - credit,
        if (credit > 0) 'deductionAmount': _num(o['deductionAmount']) - credit,
      };
      int? newDue;
      if (userExists) {
        newDue = _clampDue(_num(userSnap!.data()!['totalDue']) + credit);
      }

      tx.update(orderRef, update);
      if (newDue != null) tx.update(userRef!, {'totalDue': newDue});
      if (entrySnap != null && entrySnap.exists) tx.delete(entryRef!);
      _writeProductDeltas(tx, deltas);
      applied = deltas;
      return _moneyStateOf({...o, ...update}, newUserDue: newDue);
    });

    _applyProductDeltasLocally(applied);
    await _afterOrderWrite(orderId, userId: userId, newDue: result.newUserDue);
    if (entryRef != null) _refreshReplaceEntries();
    return result;
  }

  /// Manual correction of an order's money fields. Pass only the fields that
  /// change (new absolute values). Replace/return credits are part of
  /// paidAmount, so changing them moves paidAmount by the same difference.
  /// For a delivered order the customer's due moves by the net difference,
  /// applied to the freshly-read due (never recomputed from this order).
  Future<OrderMoneyState> adjustOrderAmounts(
    String orderId, {
    num? paidAmount,
    num? discountAmount,
    num? deductionAmount,
    num? returnAmount,
    int? previousDue,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    var userId = '';
    // Resolve the customer before the transaction (reads must come first),
    // so a wrong or missing id does not silently skip the due update.
    final orderBefore = (await orderRef.get()).data();
    final customerId =
        orderBefore == null ? '' : await _resolveCustomerId(orderBefore);

    final result = await _db.runTransaction<OrderMoneyState>((tx) async {
      final o = (await tx.get(orderRef)).data();
      if (o == null) throw OrderOpException('অর্ডারটি পাওয়া যায়নি'.tr);
      userId = customerId;

      var paid = _num(o['paidAmount']);
      var disc = _num(o['discountAmount']);
      var ded = _num(o['deductionAmount']);
      var ret = _num(o['returnAmount']);
      var prev = _num(o['previousDue']).round();
      num dueDelta = 0;
      if (paidAmount != null) {
        dueDelta -= paidAmount - paid;
        paid = paidAmount;
      }
      if (discountAmount != null) {
        dueDelta -= discountAmount - disc;
        disc = discountAmount;
      }
      if (deductionAmount != null) {
        final d = deductionAmount - ded;
        ded = deductionAmount;
        paid += d;
        dueDelta -= d;
      }
      if (returnAmount != null) {
        final d = returnAmount - ret;
        ret = returnAmount;
        paid += d;
        dueDelta -= d;
      }
      if (previousDue != null) {
        dueDelta += previousDue - prev;
        prev = previousDue;
      }

      final userRef =
          (_statusOf(o) == 'delivered' && userId.isNotEmpty && dueDelta != 0)
              ? _db.collection('users').doc(userId)
              : null;
      final userSnap = userRef == null ? null : await tx.get(userRef);
      int? newDue;
      if (userSnap != null && userSnap.exists) {
        newDue = _clampDue(_num(userSnap.data()!['totalDue']) + dueDelta);
      }

      final update = <String, dynamic>{
        'paidAmount': paid,
        'discountAmount': disc,
        'deductionAmount': ded,
        'returnAmount': ret,
        if (previousDue != null) 'previousDue': prev,
      };
      tx.update(orderRef, update);
      if (newDue != null) tx.update(userRef!, {'totalDue': newDue});
      return _moneyStateOf({...o, ...update}, newUserDue: newDue);
    });

    await _afterOrderWrite(orderId, userId: userId, newDue: result.newUserDue);
    return result;
  }

  /// Records a due collection (বাকি আদায়) from a customer: a delivered
  /// "due collection" order plus the customer's due, in one transaction that
  /// starts from the freshly-read due. [srDocId] marks an SR collection so it
  /// counts in that SR's daily account. Returns the customer's new due.
  Future<int> collectDue({
    required UserModel customer,
    required num amount,
    required String method,
    required DateTime date,
    String note = '',
    String? srDocId,
    String orderedBy = '',
    String orderedByEmail = '',
  }) async {
    if (amount <= 0) throw OrderOpException('সঠিক টাকার পরিমাণ লিখুন'.tr);
    final orderRef = _db.collection('orders').doc();
    final userRef = _db.collection('users').doc(customer.id);
    final isSr = srDocId != null && srDocId.isNotEmpty;
    var newDue = 0;
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final dueBefore = _num(userSnap.data()?['totalDue']).round();
      newDue = _clampDue(dueBefore - amount);
      tx.set(orderRef, {
        'userId': customer.id,
        'shopName': customer.shopName,
        'shopAddress': customer.address,
        'shopPhone': customer.phone,
        'userPhone': customer.phone,
        'userDue': dueBefore,
        'previousDue': dueBefore,
        'items': <Map<String, dynamic>>[],
        'totalAmount': 0,
        'paidAmount': amount,
        'status': 'delivered',
        'isDueCollection': true,
        'paymentMethod': method,
        'payments': [
          {
            'amount': amount,
            'method': method,
            'date': Timestamp.fromDate(date),
            if (isSr) 'srId': srDocId,
          }
        ],
        'paymentDays': [paymentDayKey(date)],
        if (note.isNotEmpty) 'localMemo': note,
        if (isSr) 'deliveredBySrId': srDocId,
        'deliveredAt': Timestamp.fromDate(date),
        'orderedBy': orderedBy.isNotEmpty ? orderedBy : (srDocId ?? ''),
        'orderedByEmail': orderedByEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (userSnap.exists) tx.update(userRef, {'totalDue': newDue});
    });
    _applyUserDueLocally(customer.id, newDue);
    return newDue;
  }

  /// Fresh totalDue of a customer (null when unknown), used to show the
  /// delivery dialog figures from the real current due.
  Future<int?> fetchUserDue(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final d = (await _db.collection('users').doc(userId).get()).data();
      return d == null ? null : _num(d['totalDue']).round();
    } catch (_) {
      return null;
    }
  }

  // ── Helpers for the transactional operations ──────────────────

  static const _staleMessage =
      'অর্ডারটি অন্য কোথাও থেকে পরিবর্তন হয়েছে — পেজটি আবার খুলে চেষ্টা করুন';

  /// Day key stored in an order's `paymentDays`, used by the daily report
  /// to find orders that received a payment on a given day.
  static String paymentDayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static num _num(dynamic v) =>
      v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  static int _clampDue(num v) => v.round().clamp(0, _maxDue);

  /// Finds the customer document for an order. Older orders may carry an id
  /// that is not the customer document's id (e.g. an auth uid), so the phone
  /// and then the shop name are used as a fallback. Returns '' when the
  /// customer cannot be found — then there is no due to update.
  Future<String> _resolveCustomerId(Map<String, dynamic> o) async {
    final id = _userIdOf(o);
    if (id.isNotEmpty) {
      try {
        if ((await _db.collection('users').doc(id).get()).exists) return id;
      } catch (_) {
        return id;
      }
    }
    final phone = (o['shopPhone'] ?? o['userPhone'] ?? '').toString().trim();
    final shopName = (o['shopName'] ?? '').toString().trim();
    for (final q in [
      if (phone.isNotEmpty) _db.collection('users').where('phone', isEqualTo: phone),
      if (shopName.isNotEmpty)
        _db.collection('users').where('shopName', isEqualTo: shopName),
    ]) {
      try {
        final snap = await q.limit(1).get();
        if (snap.docs.isNotEmpty) return snap.docs.first.id;
      } catch (_) {}
    }
    return '';
  }

  /// The customer's document id. Orders placed from the customer app store
  /// it as `uid`, admin/SR orders as `userId` — both must update the due.
  static String _userIdOf(Map<String, dynamic> o) =>
      (o['userId'] ?? o['uid'] ?? '').toString();

  static String _statusOf(Map<String, dynamic> o) =>
      (o['status'] ?? 'pending').toString().toLowerCase();

  static List<OrderItem> _itemsOf(Map<String, dynamic> o) =>
      (o['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

  static List<Map<String, dynamic>> _mapsOf(dynamic v) => (v as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  static Map<String, dynamic> _replaceItemMap(ReplaceLine l, String? entryId) => {
        'productId': l.productId,
        'productName': l.productName,
        'quantity': l.quantity,
        'resolutionType': l.resolutionType,
        'deductionAmount': l.isMoneyDeduct ? l.deductionAmount : 0,
        // Stock and money for this line were applied by the transactional
        // code, so removing it can reverse them exactly.
        'accounted': true,
        'replaceEntryId': ?entryId,
      };

  static bool _sameReplaceItem(Map<String, dynamic> a, Map<String, dynamic> b) {
    final id = (b['replaceEntryId'] ?? '').toString();
    if (id.isNotEmpty) return a['replaceEntryId'] == id;
    return a['replaceEntryId'] == null &&
        a['productId'] == b['productId'] &&
        _num(a['quantity']) == _num(b['quantity']) &&
        a['resolutionType'] == b['resolutionType'] &&
        _num(a['deductionAmount']) == _num(b['deductionAmount']);
  }

  static OrderMoneyState _moneyStateOf(Map<String, dynamic> m,
          {int? newUserDue, int skipped = 0}) =>
      OrderMoneyState(
        paidAmount: _num(m['paidAmount']),
        discountAmount: _num(m['discountAmount']),
        deductionAmount: _num(m['deductionAmount']),
        returnAmount: _num(m['returnAmount']),
        previousDue: _num(m['previousDue']).round(),
        payments: _mapsOf(m['payments']),
        replaceItems: _mapsOf(m['replaceItems']),
        returnItems: _mapsOf(m['returnItems']),
        paymentMethod: (m['paymentMethod'] ?? '').toString(),
        localMemo: (m['localMemo'] ?? '').toString(),
        newUserDue: newUserDue,
        skippedPendingReplaces: skipped,
      );

  static Map<String, dynamic> _customerInEntry({
    required String id,
    required String orderId,
    required ReplaceLine line,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required DateTime date,
    required DateTime now,
    required String note,
  }) {
    // "রিপ্লেস নেওয়া হল": the customer got a new unit on the spot, so the
    // customer side of the entry is already complete.
    final handedOver = line.resolutionType == 'product_replace';
    return {
      ...AdminReplaceModel(
        id: id,
        productId: line.productId,
        productName: line.productName,
        quantity: line.quantity,
        entryType: 'customer_in',
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        replaceProductId: handedOver ? line.productId : '',
        replaceProductName: handedOver ? line.productName : '',
        deliveredToCustomer: handedOver,
        deliveredToCustomerAt: handedOver ? now : null,
        customerResolutionType: line.resolutionType,
        deductionAmount: line.isMoneyDeduct ? line.deductionAmount : 0,
        supplierId: '',
        supplierName: '',
        status: 'at_shop',
        currentLocation: 'shop',
        resolution: '',
        resolvedQty: 0,
        note: note,
        date: date,
        createdAt: now,
      ).toMap(),
      'orderId': orderId,
    };
  }

  /// Replace lines saved by older app versions carry no entry id; find the
  /// replace entry that was created for them.
  Future<String?> _findLegacyReplaceEntry(
      String orderId, Map<String, dynamic> item) async {
    try {
      final o = (await _db.collection('orders').doc(orderId).get()).data();
      final userId = (o?['userId'] ?? '').toString();
      if (userId.isEmpty) return null;
      final snap = await _db
          .collection('admin_replace_entries')
          .where('customerId', isEqualTo: userId)
          .where('productId', isEqualTo: item['productId'])
          .get();
      final candidates = snap.docs.where((d) {
        final e = d.data();
        return _num(e['quantity']) == _num(item['quantity']) &&
            e['customerResolutionType'] == item['resolutionType'] &&
            e['status'] != 'resolved';
      }).toList();
      if (candidates.isEmpty) return null;
      final fromThisOrder = candidates.firstWhereOrNull(
          (d) => (d.data()['note'] ?? '').toString().contains(orderId));
      return (fromThisOrder ?? candidates.first).id;
    } catch (_) {
      return null;
    }
  }

  /// Reads the given products inside [tx] and returns the ids that still
  /// exist. Stock of a product that has since been deleted is not tracked,
  /// so it must not make the whole operation fail.
  Future<Set<String>> _existingProducts(
      Transaction tx, Iterable<String> ids) async {
    final existing = <String>{};
    for (final id in ids.toSet()) {
      if (id.isEmpty) continue;
      final snap = await tx.get(_db.collection('products').doc(id));
      if (snap.exists) existing.add(id);
    }
    return existing;
  }

  void _writeProductDeltas(Transaction tx, _ProductDeltas d) {
    for (final id in d.ids) {
      final stock = d.stock[id] ?? 0;
      final replaceCount = d.replaceCount[id] ?? 0;
      tx.update(_db.collection('products').doc(id), {
        if (stock != 0) 'stock': FieldValue.increment(stock),
        if (replaceCount != 0) 'replaceCount': FieldValue.increment(replaceCount),
      });
    }
  }

  void _applyProductDeltasLocally(_ProductDeltas d) {
    if (d.ids.isEmpty) return;
    try {
      final pc = Get.find<ProductController>();
      for (final id in d.ids) {
        final idx = pc.products.indexWhere((p) => p.id == id);
        if (idx == -1) continue;
        final p = pc.products[idx];
        pc.products[idx] = p.copyWithMap({
          'stock': p.stock + (d.stock[id] ?? 0),
          'replaceCount': p.replaceCount + (d.replaceCount[id] ?? 0),
        });
      }
      pc.products.refresh();
    } catch (_) {}
  }

  /// Re-reads the order into the list and mirrors the customer's new due.
  /// Called after a successful commit; a failure here only affects the cache.
  Future<void> _afterOrderWrite(String orderId,
      {String userId = '', int? newDue}) async {
    try {
      final snap = await _db.collection('orders').doc(orderId).get();
      final idx = orders.indexWhere((o) => o.id == orderId);
      if (idx != -1 && snap.exists) {
        final fresh = OrderModel.fromFirestore(snap);
        final old = orders[idx];
        if (fresh.userPhone.isEmpty) fresh.userPhone = old.userPhone;
        fresh.userDue = old.userDue;
        orders[idx] = fresh;
        orders.refresh();
      }
    } catch (_) {}
    if (newDue != null && userId.isNotEmpty) _applyUserDueLocally(userId, newDue);
  }

  void _refreshReplaceEntries() {
    if (!Get.isRegistered<AdminReplaceController>()) return;
    Get.find<AdminReplaceController>()
        .fetchEntries(force: true)
        .catchError((_) {});
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

    // 4. Update product stock locally (no need to re-fetch all products)
    try {
      final pc = Get.find<ProductController>();
      if (o.status == 'dispatched' || o.status == 'delivered') {
        for (final item in o.items) {
          if (item.productId.isEmpty) continue;
          pc.updateStockLocally(item.productId, item.quantity);
        }
      }
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
        replaceItems: o.replaceItems,
        returnItems: o.returnItems,
        isDueCollection: o.isDueCollection,
        returnAmount: o.returnAmount,
        deductionAmount: o.deductionAmount,
        previousDue: o.previousDue,
        discountAmount: o.discountAmount,
        paymentMethod: o.paymentMethod,
        payments: o.payments,
        userPhone: o.userPhone,
        userDue: o.userDue,
      );
    }
  }
}

/// Per-product stock / replaceCount changes of one transaction.
class _ProductDeltas {
  final stock = <String, int>{};
  final replaceCount = <String, int>{};

  void addStock(String productId, int delta) {
    if (productId.isEmpty || delta == 0) return;
    stock[productId] = (stock[productId] ?? 0) + delta;
  }

  void addReplaceCount(String productId, int delta) {
    if (productId.isEmpty || delta == 0) return;
    replaceCount[productId] = (replaceCount[productId] ?? 0) + delta;
  }

  Set<String> get ids => {...stock.keys, ...replaceCount.keys};

  /// Drops products that no longer exist and changes that net out to zero.
  void keepOnly(Set<String> existing) {
    stock.removeWhere((k, v) => v == 0 || !existing.contains(k));
    replaceCount.removeWhere((k, v) => v == 0 || !existing.contains(k));
  }
}

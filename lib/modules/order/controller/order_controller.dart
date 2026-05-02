import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';

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
    _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      pendingCount.value = snap.docs.length;
    });
  }

  Future<void> fetchOrders({bool loadMore = false}) async {
    if (loading.value) return;

    loading.value = true;

    Query query = _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit);

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
    if (selectedStatus.value == 'scheduled') {
      list = list.where((o) => o.scheduledDeliveryDate != null).toList();
    } else if (selectedStatus.value != 'all') {
      list = list.where((o) => o.status == selectedStatus.value).toList();
    }
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((o) =>
              o.shopName.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.shopPhone.contains(q) ||
              o.userPhone.contains(q))
          .toList();
    }
    return list;
  }

  Future<void> updateOrderStatus(String id, String status,
      {String? previousStatus, List items = const [], String? deliveredBySrId}) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'delivered' && deliveredBySrId != null && deliveredBySrId.isNotEmpty) {
      data['deliveredBySrId'] = deliveredBySrId;
    }
    await _db.collection('orders').doc(id).update(data);

    // Deduct stock when order moves TO 'approved' (only once)
    if (status == 'approved' && previousStatus != 'approved' && items.isNotEmpty) {
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
      await batch.commit();
    }
  }

  Future<void> updatePaidAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'paidAmount': amount});
  }

  Future<void> setScheduledDelivery(String id, DateTime? date) async {
    await _db.collection('orders').doc(id).update({
      'scheduledDeliveryDate':
          date != null ? Timestamp.fromDate(date) : FieldValue.delete(),
    });
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) await fetchOrders();
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

  Future<void> updateOrderItems(String id, List<OrderItem> items) async {
    final newTotal =
        items.fold<num>(0, (s, i) => s + i.totalPrice);
    await _db.collection('orders').doc(id).update({
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': newTotal,
    });
    // Refresh local list
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx != -1) {
      lastDoc = null;
      hasMore.value = true;
      await fetchOrders();
    }
  }

  void changeFilter(String value) {
    selectedStatus.value = value;
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

    // Refresh local list
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      await fetchOrders();
    }
  }
}
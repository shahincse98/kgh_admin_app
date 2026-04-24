import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';
import '../../user/controller/user_controller.dart';

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

  /// Fills in userPhone from the permanently-loaded UserController.
  void _enrichUserPhones() {
    try {
      final uc = Get.find<UserController>();
      for (final order in orders) {
        if (order.userPhone.isNotEmpty) continue;
        if (order.userId.isEmpty) continue;
        final user = uc.users.firstWhereOrNull((u) => u.id == order.userId);
        if (user != null && user.phone.isNotEmpty) {
          order.userPhone = user.phone;
        }
      }
      orders.refresh();
    } catch (_) {/* UserController not ready yet, skip */}
  }

  List<OrderModel> get filteredOrders {
    List<OrderModel> list = orders;
    if (selectedStatus.value != 'all') {
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
      {String? previousStatus, List items = const []}) async {
    await _db.collection('orders').doc(id).update({'status': status});

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
}
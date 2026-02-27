import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';

class OrderController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final orders = <OrderModel>[].obs;
  final loading = false.obs;
  final hasMore = true.obs;

  final selectedStatus = 'all'.obs;

  DocumentSnapshot? lastDoc;

  final int limit = 20; // প্রতি পেজে ২০টা

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
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

    loading.value = false;
  }

  List<OrderModel> get filteredOrders {
    if (selectedStatus.value == 'all') return orders;
    return orders
        .where((o) => o.status == selectedStatus.value)
        .toList();
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _db.collection('orders').doc(id).update({'status': status});
  }

  Future<void> updatePaidAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'paidAmount': amount});
  }

  void changeFilter(String value) {
    selectedStatus.value = value;
  }
}
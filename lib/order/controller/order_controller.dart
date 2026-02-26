import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';

class OrderController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final orders = <OrderModel>[].obs;
  final loading = true.obs;
  final selectedStatus = 'all'.obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _listenOrders();
  }

  void _listenOrders() {
    _sub = _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      orders.assignAll(
        snapshot.docs.map((e) => OrderModel.fromFirestore(e)),
      );
      loading.value = false;
    });
  }

  List<OrderModel> get filteredOrders {
    if (selectedStatus.value == 'all') return orders;
    return orders.where((o) => o.status == selectedStatus.value).toList();
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _db.collection('orders').doc(id).update({'status': status});
  }

  Future<void> updatePaidAmount(String id, num amount) async {
    await _db.collection('orders').doc(id).update({'paidAmount': amount});
  }

  void changeFilter(String v) {
    selectedStatus.value = v;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../order/model/order_model.dart';
import '../../order/controller/order_controller.dart';

class DispatchController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final orders = <OrderModel>[].obs;
  final loading = false.obs;
  final searchText = ''.obs;

  // For multi-select dispatch
  final selectedOrderIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDispatchableOrders();
  }

  Future<void> fetchDispatchableOrders() async {
    loading.value = true;
    try {
      // Fetch pending + approved orders (need dispatching)
      final snap = await _db
          .collection('orders')
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      // Fetch delivered orders that were never dispatched (no memoNumber)
      // Use recent 90 days to avoid fetching ALL delivered orders ever
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
      final deliveredSnap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(ninetyDaysAgo))
          .get();

      final list = <OrderModel>[];
      for (final doc in snap.docs) {
        list.add(OrderModel.fromFirestore(doc));
      }
      for (final doc in deliveredSnap.docs) {
        final order = OrderModel.fromFirestore(doc);
        if (order.memoNumber.isEmpty) {
          list.add(order);
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      orders.assignAll(list);
    } catch (_) {}
    loading.value = false;
  }

  List<OrderModel> get filteredOrders {
    var list = orders.toList();
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((o) =>
              o.shopName.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.shopPhone.contains(q) ||
              o.memoNumber.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void toggleSelection(String orderId) {
    if (selectedOrderIds.contains(orderId)) {
      selectedOrderIds.remove(orderId);
    } else {
      selectedOrderIds.add(orderId);
    }
  }

  void selectAll() {
    if (selectedOrderIds.length == orders.length) {
      selectedOrderIds.clear();
    } else {
      selectedOrderIds.assignAll(orders.map((o) => o.id));
    }
  }

  int get totalItems =>
      orders
          .where((o) => selectedOrderIds.contains(o.id))
          .fold(0, (s, o) => s + o.items.length);

  Future<void> dispatchSelected({required String memoNumber}) async {
    final oc = Get.find<OrderController>();
    final selected = orders
        .where((o) => selectedOrderIds.contains(o.id))
        .toList();

    for (final order in selected) {
      await oc.dispatchOrder(
        orderId: order.id,
        items: order.items
            .map((i) => {
                  'productId': i.productId,
                  'quantity': i.quantity,
                })
            .toList(),
        memoNumber: memoNumber,
      );
    }
    await fetchDispatchableOrders();
    selectedOrderIds.clear();
  }
}

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../order/model/order_model.dart';
import '../../order/controller/order_controller.dart';
import '../../order/model/delivery_models.dart';

class DispatchController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final orders = <OrderModel>[].obs;
  final loading = false.obs;

  /// Why the list could not be loaded — shown instead of an empty list.
  final loadError = ''.obs;

  /// Also list orders that were delivered without ever being dispatched
  /// (last 30 days). Off by default: most deliveries skip dispatch, so this
  /// would bury the orders that still need a stock-out.
  final showDeliveredWithoutDispatch = false.obs;

  /// How many such orders were found (for the toggle's label).
  final deliveredWithoutDispatchCount = 0.obs;

  void toggleDeliveredWithoutDispatch(bool v) {
    showDeliveredWithoutDispatch.value = v;
    fetchDispatchableOrders();
  }
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
    loadError.value = '';
    final list = <OrderModel>[];
    try {
      // The dispatch queue: orders whose stock has not gone out yet.
      final snap = await _db
          .collection('orders')
          .where('status', whereIn: ['pending', 'approved'])
          .get();
      for (final doc in snap.docs) {
        list.add(OrderModel.fromFirestore(doc));
      }
    } catch (e) {
      loadError.value = '$e';
    }

    // Delivered but never dispatched, last 30 days. Only the date
    // is filtered in the query — adding the status would need a composite
    // index — so the status is checked here.
    try {
      final from = DateTime.now().subtract(const Duration(days: 30));
      final snap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .get();
      final delivered = <OrderModel>[];
      for (final doc in snap.docs) {
        final order = OrderModel.fromFirestore(doc);
        // Dispatch no longer takes a memo, so "dispatched" is told by its
        // time; older dispatches also have a memo number.
        if (order.status == 'delivered' &&
            order.dispatchedAt == null &&
            order.memoNumber.isEmpty) {
          delivered.add(order);
        }
      }
      deliveredWithoutDispatchCount.value = delivered.length;
      if (showDeliveredWithoutDispatch.value) list.addAll(delivered);
    } catch (e) {
      if (loadError.isEmpty) loadError.value = '$e';
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orders.assignAll(list);
    loading.value = false;
  }

  List<OrderModel> get filteredOrders {
    var list = orders.toList();
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (o) =>
                o.shopName.toLowerCase().contains(q) ||
                o.id.toLowerCase().contains(q) ||
                o.shopPhone.contains(q) ||
                o.memoNumber.toLowerCase().contains(q),
          )
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

  int get totalItems => orders
      .where((o) => selectedOrderIds.contains(o.id))
      .fold(0, (s, o) => s + o.items.length);

  Future<void> dispatchSelected() async {
    final oc = Get.find<OrderController>();
    final selected = orders
        .where((o) => selectedOrderIds.contains(o.id))
        .toList();

    for (final order in selected) {
      try {
        await oc.dispatchOrder(orderId: order.id);
      } on OrderOpException {
        // Already dispatched/delivered elsewhere — its stock is already out.
      }
    }
    await fetchDispatchableOrders();
    selectedOrderIds.clear();
  }
}

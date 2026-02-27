import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/order_controller.dart';
import '../model/order_model.dart';
import 'order_details_view.dart';
import 'package:intl/intl.dart';

class OrderListView extends StatefulWidget {
  const OrderListView({super.key});

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView> {
  final controller = Get.find<OrderController>();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (scrollController.position.pixels ==
              scrollController.position.maxScrollExtent &&
          controller.hasMore.value) {
        controller.fetchOrders(loadMore: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [_statusFilter()],
      ),
      body: Obx(() {
        final orders = controller.filteredOrders;

        if (orders.isEmpty && controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final grouped = _groupByDate(orders);

        return ListView(
          controller: scrollController,
          children: [
            ...grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dateHeader(entry.key),
                  ...entry.value.map(_orderTile),
                ],
              );
            }),
            if (controller.loading.value)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      }),
    );
  }

  Widget _orderTile(OrderModel order) {
    final time = DateFormat('h:mm a').format(order.createdAt);

    return Card(
      child: ListTile(
        title: Text(order.shopName),
        subtitle: Text(
            'ID: ${order.id}\nTime: $time\n৳${order.totalAmount}'),
        onTap: () {
          Get.to(() => OrderDetailsView(order: order));
        },
      ),
    );
  }

  Widget _dateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        date,
        style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusFilter() {
    const filters = ['all', 'pending', 'approved', 'delivered', 'cancelled'];

    return Obx(() => DropdownButton<String>(
          value: controller.selectedStatus.value,
          underline: const SizedBox(),
          items: filters
              .map((f) =>
                  DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.changeFilter(v);
          },
        ));
  }

  Map<String, List<OrderModel>> _groupByDate(
      List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (var o in orders) {
      final date = DateFormat('dd MMMM yyyy').format(o.createdAt);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }
}
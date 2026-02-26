import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/order_controller.dart';
import '../model/order_model.dart';
import 'order_details_view.dart';
import 'package:intl/intl.dart';

class OrderListView extends GetView<OrderController> {
  const OrderListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [_statusFilter()],
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = controller.filteredOrders;
        if (orders.isEmpty) {
          return const Center(child: Text('No orders found'));
        }

        final grouped = _groupByDate(orders);

        return ListView(
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateHeader(entry.key),
                ...entry.value.map(_orderTile),
              ],
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _orderTile(OrderModel order) {
    final time = DateFormat('h:mm a').format(order.createdAt);
    const statuses = ['pending', 'approved', 'delivered', 'cancelled'];
    final value =
        statuses.contains(order.status) ? order.status : 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(order.shopName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${order.id}'),
            Text('Time: $time'),
            Text('Address: ${order.shopAddress}'),
          ],
        ),
        trailing: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          items: statuses
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.capitalizeFirst!),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              controller.updateOrderStatus(order.id, v);
            }
          },
        ),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusFilter() {
    const filters = ['all', 'pending', 'approved', 'delivered', 'cancelled'];

    return Obx(() {
      final value = filters.contains(controller.selectedStatus.value)
          ? controller.selectedStatus.value
          : 'all';

      return DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: filters
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(f.capitalizeFirst!),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) controller.changeFilter(v);
        },
      );
    });
  }

  Map<String, List<OrderModel>> _groupByDate(List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (var o in orders) {
      final date = DateFormat('dd MMMM').format(o.createdAt);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }
}
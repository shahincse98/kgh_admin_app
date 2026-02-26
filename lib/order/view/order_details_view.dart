import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../model/order_model.dart';
import '../controller/order_controller.dart';
import 'package:intl/intl.dart';

class OrderDetailsView extends StatelessWidget {
  final OrderModel order;
  const OrderDetailsView({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrderController>();
    final paidCtrl =
        TextEditingController(text: order.paidAmount.toString());

    final time = DateFormat('h:mm a').format(order.createdAt);
    final date = DateFormat('dd MMMM yyyy').format(order.createdAt);

    const statuses = ['pending', 'approved', 'delivered', 'cancelled'];
    final statusValue =
        statuses.contains(order.status) ? order.status : 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Order ID: ${order.id}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Date: $date'),
          Text('Time: $time'),
          const Divider(),

          Text('Shop: ${order.shopName}'),
          Text('Address: ${order.shopAddress}'),
          const Divider(),

          Row(
            children: [
              const Text('Status: '),
              DropdownButton<String>(
                value: statusValue,
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
            ],
          ),

          const Divider(),

          ...order.items.map(
            (i) => ListTile(
              leading: Image.network(i.image, width: 50),
              title: Text(i.productName),
              subtitle: Text(
                '${i.quantity} x ${i.pricePerUnit} = ৳${i.totalPrice}',
              ),
            ),
          ),

          const Divider(),
          Text('Total Amount: ৳${order.totalAmount}'),
          TextField(
            controller: paidCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Paid Amount'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await controller.updatePaidAmount(
                order.id,
                num.tryParse(paidCtrl.text) ?? order.paidAmount,
              );
              Get.back();
            },
            child: const Text('Update Paid Amount'),
          ),
        ],
      ),
    );
  }
}
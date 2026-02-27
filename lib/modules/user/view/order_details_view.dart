import 'package:flutter/material.dart';
import '../model/user_order_model.dart';

class OrderDetailsView extends StatelessWidget {
  final UserOrderModel order;

  const OrderDetailsView({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Order ${order.id}")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Status: ${order.status}"),
          Text("Total Items: ${order.totalItems}"),
          Text("Total Amount: ${order.totalAmount}"),
          Text("Paid: ${order.paidAmount}"),
          const Divider(),
          ...order.items.map((item) {
            return Card(
              child: ListTile(
                leading: Image.network(item['image'],
                    width: 50, height: 50, fit: BoxFit.cover),
                title: Text(item['productName']),
                subtitle: Text(
                    "Qty: ${item['quantity']} | Price: ${item['pricePerUnit']} | Total: ${item['totalPrice']}"),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
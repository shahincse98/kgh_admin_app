import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/user/controller/user_controller.dart';
import '../model/user_model.dart';
import '../model/user_order_model.dart';
import 'order_details_view.dart';

class UserDetailsView extends StatefulWidget {
  final UserModel user;

  const UserDetailsView({super.key, required this.user});

  @override
  State<UserDetailsView> createState() => _UserDetailsViewState();
}

class _UserDetailsViewState extends State<UserDetailsView> {
  final controller = Get.find<UserController>();
  List<UserOrderModel> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    orders = await controller.fetchUserOrders(widget.user.id);
    setState(() => loading = false);
  }

  String formatDate(DateTime date) {
    return "${date.day} ${_monthName(date.month)}, ${date.year}";
  }

  String _monthName(int m) {
    const months = [
      "",
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Scaffold(
      appBar: AppBar(title: Text(u.shopName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text("Owner: ${u.proprietorName}"),
                Text("Phone: ${u.phone}"),
                Text("Email: ${u.email}"),
                Text("Address: ${u.address}"),
                Text("Delivery: ${u.deliveryDay}"),
                Text("Total Due: ${u.totalDue}"),
                const Divider(height: 30),
                const Text("Orders",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...orders.map((o) {
                  final date = o.createdAt?.toDate();
                  return Card(
                    child: ListTile(
                      title: Text("Order: ${o.id}"),
                      subtitle: Text(
                          "${formatDate(date!)} | ${o.status} | ${o.totalAmount}"),
                      onTap: () {
                        Get.to(() => OrderDetailsView(order: o));
                      },
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
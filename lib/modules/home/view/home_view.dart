import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kgh_admin_app/routes/app_routes.dart';
import '../controller/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _drawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final data = controller.dashboard.value;
          return GridView.count(
            crossAxisCount: Get.width < 600 ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _infoCard('Orders', data.totalOrders.toString()),
              _infoCard('Products', data.totalProducts.toString()),
              _infoCard('Revenue', '৳ ${data.totalRevenue}'),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.refreshDashboard,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      elevation: 4,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

Drawer _drawer() {
  return Drawer(
    child: ListView(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Text(
            'Admin Menu',
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          onTap: () {
            Get.back();
            Get.offAllNamed(AppRoutes.home);
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Orders'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.orders);
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Products'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.products);
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Users'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.users);
          },
        ),
        
      ],
    ),
  );
}
}
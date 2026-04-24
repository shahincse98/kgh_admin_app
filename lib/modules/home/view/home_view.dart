import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kgh_admin_app/modules/auth/controller/auth_controller.dart';
import 'package:kgh_admin_app/modules/order/controller/order_controller.dart';
import 'package:kgh_admin_app/routes/app_routes.dart';
import 'package:kgh_admin_app/theme/app_theme.dart';
import '../controller/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Theme পরিবর্তন করুন',
            onPressed: () => AppTheme.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirmed = await Get.dialog<bool>(
                AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('আপনি কি Logout করতে চান?'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('না'),
                    ),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('হ্যাঁ'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                Get.find<AuthController>().logout();
              }
            },
          ),
        ],
      ),
      drawer: _drawer(),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = controller.dashboard.value;
        return RefreshIndicator(
          onRefresh: controller.refreshDashboard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1200
                  ? 5
                  : width >= 900
                      ? 4
                      : width >= 650
                          ? 3
                          : 2;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(
                            Icons.space_dashboard_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          const Text(
                            'Welcome to KGH Control Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Overview',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        _infoCard('Orders', data.totalOrders.toString(),
                            Icons.shopping_bag_rounded, const Color(0xFF0EA5E9)),
                        _infoCard('Pending', data.pendingOrders.toString(),
                            Icons.pending_actions_rounded, const Color(0xFFF59E0B)),
                        _infoCard('Products', data.totalProducts.toString(),
                            Icons.inventory_2_rounded, const Color(0xFF10B981)),
                        _infoCard('Users', data.totalUsers.toString(),
                            Icons.groups_rounded, const Color(0xFF6366F1)),
                        _infoCard(
                          'Revenue',
                          '৳ ${_formatNumber(data.totalRevenue)}',
                          Icons.payments_rounded,
                          const Color(0xFF0891B2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Quick Actions',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _actionButton('Orders', Icons.receipt_long_rounded,
                            const Color(0xFF0EA5E9), () => Get.toNamed(AppRoutes.orders)),
                        _actionButton('Products', Icons.inventory_2_rounded,
                            const Color(0xFF10B981), () => Get.toNamed(AppRoutes.products)),
                        _actionButton('Users', Icons.people_alt_rounded,
                            const Color(0xFF6366F1), () => Get.toNamed(AppRoutes.users)),
                        _actionButton('Finance', Icons.query_stats_rounded,
                            const Color(0xFF7C3AED), () => Get.toNamed(AppRoutes.finance)),
                        _actionButton('Expenses', Icons.receipt_long_rounded,
                            const Color(0xFFD97706), () => Get.toNamed(AppRoutes.expenses)),
                        _actionButton('SR', Icons.person_pin_circle_rounded,
                            const Color(0xFF0891B2), () => Get.toNamed(AppRoutes.sr)),
                        _actionButton('Purchase', Icons.shopping_cart_rounded,
                            const Color(0xFF6366F1), () => Get.toNamed(AppRoutes.purchases)),
                        _actionButton('Sales', Icons.bar_chart_rounded,
                            const Color(0xFF16A34A), () => Get.toNamed(AppRoutes.sales)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Monthly Revenue',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _revenueChart(),
                  ],
                ),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.refreshDashboard,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _infoCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            const SizedBox(height: 3),
            Text(title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _revenueChart() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Obx(() {
      final data = controller.monthlyRevenue;
      if (data.isEmpty) {
        return const SizedBox(
          height: 200,
          child: Center(child: Text('Data নেই', style: TextStyle(color: Colors.grey))),
        );
      }

      final bars = List.generate(12, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[i] ?? 0,
              color: Colors.blue,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      });

      final maxY = data.values.fold(0.0, (a, b) => a > b ? a : b);

      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                barGroups: bars,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        months[v.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (v, _) => Text(
                        _formatNumber(v.toInt()),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, tooltipIndex) => BarTooltipItem(
                      '${months[group.x]}\n৳${_formatNumber(rod.toY.toInt())}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  String _formatNumber(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

Drawer _drawer() {
  return Drawer(
    child: ListView(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 36),
              SizedBox(height: 8),
              Text(
                'KGH Admin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
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
          leading: const Icon(Icons.receipt_long),
          title: Obx(() {
            final count =
                Get.find<OrderController>().pendingCount.value;
            return Row(
              children: [
                const Text('Orders'),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            );
          }),
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
          leading: const Icon(Icons.people),
          title: const Text('Users'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.users);
          },
        ),
        ListTile(
          leading: const Icon(Icons.query_stats),
          title: const Text('Finance'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.finance);
          },
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Expenses'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.expenses);
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_pin_circle),
          title: const Text('SR Performance'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.sr);
          },
        ),
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text('Purchase Ledger'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.purchases);
          },
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('Sales Analytics'),
          onTap: () {
            Get.back();
            Get.toNamed(AppRoutes.sales);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout',
              style: TextStyle(color: Colors.red)),
          onTap: () {
            Get.back();
            Get.find<AuthController>().logout();
          },
        ),
      ],
    ),
  );
}
}
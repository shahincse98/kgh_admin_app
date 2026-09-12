import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kgh_admin_app/modules/auth/controller/auth_controller.dart';
import 'package:kgh_admin_app/routes/app_routes.dart';
import 'package:kgh_admin_app/theme/app_theme.dart';
import '../controller/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: Text('Admin Dashboard'.tr),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Theme পরিবর্তন করুন'.tr,
            onPressed: () => AppTheme.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings'.tr,
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout'.tr,
            onPressed: () async {
              final confirmed = await Get.dialog<bool>(
                AlertDialog(
                  title: Text('Logout'.tr),
                  content: Text('আপনি কি Logout করতে চান?'.tr),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: Text('না'.tr),
                    ),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: Text('হ্যাঁ'.tr),
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
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = controller.dashboard.value;
        return RefreshIndicator(
          onRefresh: () => controller.refreshDashboard(force: true),
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
                          Text(
                            'Welcome to KGH Control Hub'.tr,
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
                      'Overview'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                        _infoCard(
                          'Orders'.tr,
                          data.totalOrders.toString(),
                          Icons.shopping_bag_rounded,
                          const Color(0xFF0EA5E9),
                        ),
                        _infoCard(
                          'Pending'.tr,
                          data.pendingOrders.toString(),
                          Icons.pending_actions_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        _infoCard(
                          'Products'.tr,
                          data.totalProducts.toString(),
                          Icons.inventory_2_rounded,
                          const Color(0xFF10B981),
                        ),
                        _infoCard(
                          'Users'.tr,
                          data.totalUsers.toString(),
                          Icons.groups_rounded,
                          const Color(0xFF6366F1),
                        ),
                        _infoCard(
                          'Revenue'.tr,
                          '৳ ${_formatNumber(data.totalRevenue)}',
                          Icons.payments_rounded,
                          const Color(0xFF0891B2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Quick Actions'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _actionButton(
                          'Orders'.tr,
                          Icons.receipt_long_rounded,
                          const Color(0xFF0EA5E9),
                          () => Get.toNamed(AppRoutes.orders),
                        ),
                        _actionButton(
                          'নতুন অর্ডার'.tr,
                          Icons.add_shopping_cart_rounded,
                          const Color(0xFF7C3AED),
                          () => Get.toNamed(AppRoutes.createOrder),
                        ),
                        _actionButton(
                          'Products'.tr,
                          Icons.inventory_2_rounded,
                          const Color(0xFF10B981),
                          () => Get.toNamed(AppRoutes.products),
                        ),
                        _actionButton(
                          'Users'.tr,
                          Icons.people_alt_rounded,
                          const Color(0xFF6366F1),
                          () => Get.toNamed(AppRoutes.users),
                        ),
                        _actionButton(
                          'Finance'.tr,
                          Icons.query_stats_rounded,
                          const Color(0xFF7C3AED),
                          () => Get.toNamed(AppRoutes.finance),
                        ),
                        _actionButton(
                          'Expenses'.tr,
                          Icons.receipt_long_rounded,
                          const Color(0xFFD97706),
                          () => Get.toNamed(AppRoutes.expenses),
                        ),
                        _actionButton(
                          'SR'.tr,
                          Icons.person_pin_circle_rounded,
                          const Color(0xFF0891B2),
                          () => Get.toNamed(AppRoutes.srManagement),
                        ),
                        _actionButton(
                          'Purchase'.tr,
                          Icons.shopping_cart_rounded,
                          const Color(0xFF6366F1),
                          () => Get.toNamed(AppRoutes.purchases),
                        ),
                        _actionButton(
                          'Sales'.tr,
                          Icons.bar_chart_rounded,
                          const Color(0xFF16A34A),
                          () => Get.toNamed(AppRoutes.sales),
                        ),
                        _actionButton(
                          'বিক্রয় পরিকল্পনা'.tr,
                          Icons.assignment_turned_in_rounded,
                          const Color(0xFFD97706),
                          () => Get.toNamed(AppRoutes.salesPlan),
                        ),
                        _actionButton(
                          'সাপ্লাইয়ার'.tr,
                          Icons.store_mall_directory_rounded,
                          const Color(0xFF0891B2),
                          () => Get.toNamed(AppRoutes.suppliers),
                        ),
                        _actionButton(
                          'রিপ্লেস'.tr,
                          Icons.swap_horiz_rounded,
                          Color(0xFF7C3AED),
                          () => Get.toNamed(AppRoutes.replaceManagement),
                        ),
                        _actionButton(
                          'স্টক আউট / Dispatch'.tr,
                          Icons.receipt_long_rounded,
                          Color(0xFFD97706),
                          () => Get.toNamed(AppRoutes.dispatchHistory),
                        ),
                        _actionButton(
                          'স্টক ইন'.tr,
                          Icons.add_shopping_cart_rounded,
                          Color(0xFF16A34A),
                          () => Get.toNamed(AppRoutes.stockIn),
                        ),
                      ],
                    ),
                    SizedBox(height: 22),
                    Text(
                      'Monthly Revenue'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    _revenueChart(),
                  ],
                ),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.refreshDashboard(force: true),
        tooltip: 'Refresh'.tr,
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 25),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _revenueChart() {
    final months = [
      'Jan'.tr,
      'Feb'.tr,
      'Mar'.tr,
      'Apr'.tr,
      'May'.tr,
      'Jun'.tr,
      'Jul'.tr,
      'Aug'.tr,
      'Sep'.tr,
      'Oct'.tr,
      'Nov'.tr,
      'Dec'.tr,
    ];

    return Obx(() {
      final data = controller.monthlyRevenue;
      if (data.isEmpty) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Text('Data নেই'.tr, style: TextStyle(color: Colors.grey)),
          ),
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
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, tooltipIndex) =>
                        BarTooltipItem(
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
}

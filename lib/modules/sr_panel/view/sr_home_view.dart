import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../theme/app_theme.dart';
import 'sr_panel_shell.dart';

class SrHomeView extends GetView<SrPanelController> {
  const SrHomeView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Obx(() => Text(
              controller.srProfile.value != null
                  ? 'হ্যালো, ${controller.srProfile.value!.name}'
                  : 'SR প্যানেল',
              style: const TextStyle(fontWeight: FontWeight.w800),
            )),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: AppTheme.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              final ok = await Get.dialog<bool>(AlertDialog(
                title: const Text('Logout'),
                content: const Text('আপনি কি Logout করতে চান?'),
                actions: [
                  TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('না')),
                  TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('হ্যাঁ')),
                ],
              ));
              if (ok == true) Get.find<AuthController>().logout();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            await controller.loadDashboard();
            await controller.loadMyOrders();
          },
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Month navigator
              _monthNav(context, scheme),
              const SizedBox(height: 14),

              // KPI grid
              _kpiGrid(context, scheme),
              const SizedBox(height: 14),

              // Frozen alert
              Obx(() {
                if (controller.frozenAmount.value <= 0) {
                  return const SizedBox();
                }
                return Column(
                  children: [
                    _frozenAlert(scheme),
                    const SizedBox(height: 14),
                  ],
                );
              }),

              // Balance card
              _balanceCard(scheme),
              const SizedBox(height: 20),

              // Quick actions
              Text('Quick Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _quickActions(context, scheme),
              const SizedBox(height: 20),

              // Recent orders preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('সাম্প্রতিক অর্ডার',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () =>
                        Get.find<SrNavController>(tag: 'sr_nav').tabIndex.value = 2,
                    child: const Text('সব দেখুন'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _recentOrders(scheme),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  Widget _monthNav(BuildContext context, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: controller.prevMonth,
            ),
            Obx(() => Text(
                  DateFormat('MMMM yyyy')
                      .format(controller.selectedMonth.value),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                )),
            Obx(() {
              final m = controller.selectedMonth.value;
              final now = DateTime.now();
              final isCurrent =
                  m.year == now.year && m.month == now.month;
              return IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: isCurrent ? Colors.grey : null),
                onPressed: isCurrent ? null : controller.nextMonth,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth >= 600 ? 3 : 2;
      return Obx(() => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _kpi('ডেলিভারি',
                  '${controller.totalDeliveries.value}',
                  Icons.local_shipping_rounded,
                  const Color(0xFF0EA5E9)),
              _kpi('বিক্রয়',
                  '৳ ${_fmt.format(controller.totalRevenue.value.toInt())}',
                  Icons.payments_rounded,
                  const Color(0xFF10B981)),
              _kpi('কমিশন',
                  '৳ ${_fmt.format(controller.commissionDue.value.toInt())}',
                  Icons.percent_rounded,
                  const Color(0xFF6366F1)),
              _kpi('বেতন',
                  '৳ ${_fmt.format(controller.totalSalary.value.toInt())}',
                  Icons.badge_rounded,
                  const Color(0xFFF59E0B)),
              _kpi('মোট প্রাপ্য',
                  '৳ ${_fmt.format(controller.totalDue.value.toInt())}',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF0891B2)),
              _kpi('পরিশোধিত',
                  '৳ ${_fmt.format(controller.totalPaid.value.toInt())}',
                  Icons.check_circle_rounded,
                  const Color(0xFF22C55E)),
            ],
          ));
    });
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _frozenAlert(ColorScheme scheme) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.red.withAlpha(80), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.red, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('বেতন ফ্রিজ সতর্কতা',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.red)),
                    const SizedBox(height: 4),
                    Text(
                      '৳${_fmt.format(controller.frozenAmount.value.toInt())} ফ্রিজ হয়েছে। '
                      'গ্রাহকের বাকি আদায় করলে ফ্রিজ মুক্ত হবে।',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _balanceCard(ColorScheme scheme) {
    return Obx(() {
      final net = controller.netPayable.value;
      final isPaid = net <= 0;
      final color =
          isPaid ? Colors.green.shade600 : Colors.orange.shade700;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
                isPaid
                    ? Icons.check_circle_outline_rounded
                    : Icons.account_balance_wallet_rounded,
                color: color,
                size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('নেট প্রদেয়',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: color)),
                Text(
                  '৳ ${_fmt.format(net.abs().toInt())}${net < 0 ? ' (অতিরিক্ত)' : ''}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _quickActions(BuildContext context, ColorScheme scheme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionBtn(
          'নতুন অর্ডার',
          Icons.add_shopping_cart_rounded,
          const Color(0xFF0EA5E9),
          () => Get.find<SrNavController>(tag: 'sr_nav').tabIndex.value = 1,
        ),
        _actionBtn(
          'আমার দোকান',
          Icons.store_rounded,
          const Color(0xFF6366F1),
          () => Get.find<SrNavController>(tag: 'sr_nav').tabIndex.value = 3,
        ),
        _actionBtn(
          'বাকি তালিকা',
          Icons.receipt_long_rounded,
          const Color(0xFFDC2626),
          () => Get.find<SrNavController>(tag: 'sr_nav').tabIndex.value = 4,
        ),
      ],
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _recentOrders(ColorScheme scheme) {
    return Obx(() {
      final orders = controller.myOrders.take(5).toList();
      if (controller.ordersLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (orders.isEmpty) {
        return Center(
          child: Text('কোনো অর্ডার নেই',
              style: TextStyle(
                  color: scheme.onSurface.withAlpha(120))),
        );
      }
      final fmt = NumberFormat('#,##,##0');
      return Column(
        children: orders.map((o) {
          final statusColor = _statusColor(o.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(o.shopName.isEmpty ? 'Unknown' : o.shopName,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${o.items.length} পণ্য  •  ${DateFormat('dd MMM').format(o.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '৳ ${fmt.format(o.totalAmount.toInt())}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0891B2)),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}



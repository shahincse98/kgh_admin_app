import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modules/auth/controller/auth_controller.dart';
import '../modules/order/controller/order_controller.dart';
import '../routes/app_routes.dart';

/// পাতাটি নেভিগেশন স্ট্যাকের গোড়ায় থাকলে ড্রয়ার দেয়, নইলে `null` —
/// ফলে AppBar back তীর দেখায়।
///
/// একই পাতা কখনো ড্রয়ার থেকে খোলা হয় (তখন সে-ই গোড়ার পাতা, ড্রয়ার দরকার),
/// আবার কখনো অন্য পাতা থেকে (তখন ফিরে যাওয়ার তীর দরকার)। Flutter-এ ড্রয়ার
/// থাকলে সেটি back তীরকে সরিয়ে দেয়, তাই এই বাছাইটা জরুরি।
Widget? appDrawerFor(BuildContext context) =>
    Navigator.of(context).canPop() ? null : const AppDrawer();

/// অ্যাপের প্রধান নেভিগেশন ড্রয়ার।
///
/// কাজগুলো বিষয় অনুযায়ী গুচ্ছবদ্ধ — প্রতিটি গুচ্ছ তীর চিহ্ন দিয়ে খোলা-বন্ধ করা
/// যায়। বর্তমানে যে পাতায় আছি সেই গুচ্ছটি নিজে থেকেই খোলা থাকে এবং আইটেমটি
/// হাইলাইট হয়, ফলে "আমি কোথায় আছি" বোঝা যায়।
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = Get.currentRoute;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _header(scheme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _SingleTile(
                    icon: Icons.space_dashboard_rounded,
                    label: 'Dashboard'.tr,
                    route: AppRoutes.home,
                    current: current,
                  ),
                  for (final group in _groups)
                    _GroupTile(group: group, current: current),
                  const Divider(height: 8),
                  _SingleTile(
                    icon: Icons.settings_rounded,
                    label: 'Settings'.tr,
                    route: AppRoutes.settings,
                    current: current,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      'Logout'.tr,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Scaffold.of(context).closeDrawer();
                      final ok = await Get.dialog<bool>(
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
                      if (ok == true) Get.find<AuthController>().logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    final email = Get.find<AuthController>().currentUser?.email ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'KGH Admin'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── নেভিগেশনের কাঠামো ────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem(this.icon, this.label, this.route, {this.badge = false});

  final IconData icon;

  /// অনুবাদের key — দেখানোর সময় `.tr` করা হয়।
  final String label;
  final String route;

  /// সত্য হলে পেন্ডিং অর্ডারের সংখ্যা ব্যাজ হিসেবে দেখায়।
  final bool badge;
}

class _NavGroup {
  const _NavGroup(this.icon, this.label, this.items);

  final IconData icon;
  final String label;
  final List<_NavItem> items;
}

const List<_NavGroup> _groups = [
  _NavGroup(Icons.receipt_long_rounded, 'Orders', [
    _NavItem(
      Icons.list_alt_rounded,
      'অর্ডার তালিকা',
      AppRoutes.orders,
      badge: true,
    ),
    _NavItem(
      Icons.add_shopping_cart_rounded,
      'নতুন অর্ডার',
      AppRoutes.createOrder,
    ),
    _NavItem(
      Icons.local_shipping_rounded,
      'স্টক আউট / Dispatch',
      AppRoutes.dispatch,
    ),
    _NavItem(
      Icons.history_rounded,
      'Dispatch History',
      AppRoutes.dispatchHistory,
    ),
  ]),
  _NavGroup(Icons.inventory_2_rounded, 'Products', [
    _NavItem(Icons.view_list_rounded, 'পণ্যের তালিকা', AppRoutes.products),
    _NavItem(
      Icons.add_box_rounded,
      'নতুন পণ্য যোগ করুন',
      AppRoutes.productForm,
    ),
    _NavItem(
      Icons.warehouse_rounded,
      'স্টক ম্যানেজমেন্ট',
      AppRoutes.stockManagement,
    ),
    _NavItem(
      Icons.camera_alt_rounded,
      'স্টক স্ন্যাপশট ইতিহাস',
      AppRoutes.stockSnapshots,
    ),
    _NavItem(
      Icons.swap_horiz_rounded,
      'রিপ্লেস ম্যানেজমেন্ট',
      AppRoutes.replaceManagement,
    ),
    _NavItem(
      Icons.assignment_return_rounded,
      'রিপ্লেস অনুরোধ',
      AppRoutes.replaceRequests,
    ),
  ]),
  _NavGroup(Icons.inventory_rounded, 'স্টক ও ক্রয়', [
    _NavItem(Icons.add_shopping_cart_rounded, 'স্টক ইন', AppRoutes.stockIn),
    _NavItem(Icons.history_rounded, 'স্টক ইন ইতিহাস', AppRoutes.stockInHistory),
    _NavItem(
      Icons.shopping_cart_rounded,
      'Purchase Ledger',
      AppRoutes.purchases,
    ),
    _NavItem(
      Icons.store_mall_directory_rounded,
      'সাপ্লাইয়ার',
      AppRoutes.suppliers,
    ),
  ]),
  _NavGroup(Icons.bar_chart_rounded, 'Sales', [
    _NavItem(Icons.query_stats_rounded, 'Sales Analytics', AppRoutes.sales),
    _NavItem(
      Icons.assignment_turned_in_rounded,
      'বিক্রয় পরিকল্পনা',
      AppRoutes.salesPlan,
    ),
  ]),
  _NavGroup(Icons.account_balance_wallet_rounded, 'Finance', [
    _NavItem(
      Icons.query_stats_rounded,
      'Finance & Analytics',
      AppRoutes.finance,
    ),
    _NavItem(Icons.receipt_rounded, 'Expense Ledger', AppRoutes.expenses),
  ]),
  _NavGroup(Icons.groups_rounded, 'কাস্টমার ও SR', [
    _NavItem(Icons.people_alt_rounded, 'Users', AppRoutes.users),
    _NavItem(Icons.badge_rounded, 'SR ব্যবস্থাপনা', AppRoutes.srManagement),
    _NavItem(Icons.insights_rounded, 'SR Performance', AppRoutes.sr),
  ]),
];

// ── টাইল ─────────────────────────────────────────────────────────────────────

/// সব গন্তব্যই স্ট্যাকের গোড়ায় বসে, ফলে স্ট্যাক বাড়ে না এবং প্রতিটি পাতায়
/// ড্রয়ারের হ্যামবার্গার পাওয়া যায়।
///
/// ড্রয়ার বন্ধ করতে অবশ্যই [ScaffoldState.closeDrawer] ব্যবহার করতে হবে —
/// ড্রয়ার কোনো রুট নয়, তাই `Get.back()` ড্রয়ারের বদলে চলতি পাতাটাই pop করে দেয়।
void _go(BuildContext context, String route) {
  Scaffold.of(context).closeDrawer();
  if (Get.currentRoute == route) return;
  Get.offAllNamed(route);
}

class _SingleTile extends StatelessWidget {
  const _SingleTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
  });

  final IconData icon;
  final String label;
  final String route;
  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = current == route;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.10),
      selectedColor: scheme.primary,
      leading: Icon(icon),
      title: Text(label),
      onTap: () => _go(context, route),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.current});

  final _NavGroup group;
  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActive = group.items.any((i) => i.route == current);

    return ExpansionTile(
      // বর্তমান পাতাটি যে গুচ্ছে আছে সেটি খোলা অবস্থায় দেখায়।
      initiallyExpanded: hasActive,
      leading: Icon(group.icon, color: hasActive ? scheme.primary : null),
      title: Text(
        group.label.tr,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: hasActive ? scheme.primary : null,
        ),
      ),
      childrenPadding: const EdgeInsets.only(left: 8),
      children: group.items
          .map((item) => _ItemTile(item: item, current: current))
          .toList(),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.current});

  final _NavItem item;
  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = current == item.route;

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.10),
      selectedColor: scheme.primary,
      contentPadding: const EdgeInsets.only(left: 26, right: 16),
      leading: Icon(item.icon, size: 20),
      title: item.badge
          ? _BadgedLabel(label: item.label.tr)
          : Text(item.label.tr),
      onTap: () => _go(context, item.route),
    );
  }
}

/// পেন্ডিং অর্ডারের সংখ্যা সহ লেবেল।
class _BadgedLabel extends StatelessWidget {
  const _BadgedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = Get.isRegistered<OrderController>()
          ? Get.find<OrderController>().pendingCount.value
          : 0;
      return Row(
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      );
    });
  }
}

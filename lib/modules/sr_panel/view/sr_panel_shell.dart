import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/sr_panel_controller.dart';
import 'sr_home_view.dart';
import 'sr_place_order_view.dart';
import 'sr_my_orders_view.dart';
import 'sr_my_customers_view.dart';
import 'sr_due_view.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../main.dart' show srDocIdForStartup;

// Navigation state controller – shared across all SR views
class SrNavController extends GetxController {
  final tabIndex = 0.obs;
}

class SrPanelShell extends StatelessWidget {
  const SrPanelShell({super.key});

  @override
  Widget build(BuildContext context) {
    final srDocId = (Get.arguments as String?)?.isNotEmpty == true
        ? Get.arguments as String
        : (srDocIdForStartup ?? '');
    final navCtrl = Get.put(SrNavController(), tag: 'sr_nav');
    Get.put(SrPanelController(srDocId: srDocId), permanent: false);

    final scheme = Theme.of(context).colorScheme;

    final pages = const [
      SrHomeView(),
      SrPlaceOrderView(),
      SrMyOrdersView(),
      SrMyCustomersView(),
      SrDueView(),
    ];

    return Obx(() => Scaffold(
          body: IndexedStack(
            index: navCtrl.tabIndex.value,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navCtrl.tabIndex.value,
            onDestinationSelected: (i) => navCtrl.tabIndex.value = i,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_rounded),
                label: 'ড্যাশবোর্ড',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_shopping_cart_rounded),
                label: 'অর্ডার করুন',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_rounded),
                label: 'আমার অর্ডার',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_rounded),
                label: 'ইউজার',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'বাকি',
              ),
            ],
          ),
        ));
  }
}

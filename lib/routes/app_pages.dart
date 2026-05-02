import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/order/controller/order_controller.dart';
import 'package:kgh_admin_app/modules/order/controller/create_order_controller.dart';
import 'package:kgh_admin_app/modules/order/view/order_list_view.dart';
import 'package:kgh_admin_app/modules/order/view/create_order_view.dart';
import 'package:kgh_admin_app/modules/user/view/user_list_view.dart';
import 'package:kgh_admin_app/modules/user/controller/user_controller.dart';
import 'package:kgh_admin_app/modules/auth/view/login_view.dart';
import 'package:kgh_admin_app/modules/auth/controller/auth_controller.dart';
import 'package:kgh_admin_app/modules/finance/view/finance_view.dart';
import 'package:kgh_admin_app/modules/finance/controller/finance_controller.dart';
import 'package:kgh_admin_app/modules/expense/view/expense_view.dart';
import 'package:kgh_admin_app/modules/expense/controller/expense_controller.dart';
import 'package:kgh_admin_app/modules/sr/view/sr_view.dart';
import 'package:kgh_admin_app/modules/sr/controller/sr_controller.dart';
import 'package:kgh_admin_app/modules/sr/view/sr_management_view.dart';
import 'package:kgh_admin_app/modules/sr/view/sr_detail_view.dart';
import 'package:kgh_admin_app/modules/sr/controller/sr_management_controller.dart';
import 'package:kgh_admin_app/modules/sr_panel/view/sr_panel_shell.dart';
import 'package:kgh_admin_app/modules/purchase/view/purchase_view.dart';
import 'package:kgh_admin_app/modules/purchase/controller/purchase_controller.dart';
import 'package:kgh_admin_app/modules/sales/view/sales_view.dart';
import 'package:kgh_admin_app/modules/sales/controller/sales_controller.dart';
import '../modules/home/view/home_view.dart';
import '../modules/home/controller/home_controller.dart';
import '../modules/product/view/product_list_view.dart';
import '../modules/product/controller/product_controller.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<HomeController>(() => HomeController());
      }),
    ),
    GetPage(
      name: AppRoutes.orders,
      page: () => const OrderListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<OrderController>(() => OrderController());
      }),
    ),
    GetPage(
      name: AppRoutes.createOrder,
      page: () => const CreateOrderView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CreateOrderController>(() => CreateOrderController());
      }),
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProductController>(() => ProductController());
      }),
    ),
    GetPage(
      name: AppRoutes.users,
      page: () => const UserListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<UserController>(() => UserController());
      }),
    ),
    GetPage(
      name: AppRoutes.finance,
      page: () => const FinanceView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<FinanceController>(() => FinanceController());
      }),
    ),
    GetPage(
      name: AppRoutes.expenses,
      page: () => const ExpenseView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ExpenseController>(() => ExpenseController());
      }),
    ),
    GetPage(
      name: AppRoutes.sr,
      page: () => const SrView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SrController>(() => SrController());
      }),
    ),
    GetPage(
      name: AppRoutes.srManagement,
      page: () => const SrManagementView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SrManagementController>(() => SrManagementController());
      }),
    ),
    GetPage(
      name: AppRoutes.srDetail,
      page: () => const SrDetailView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SrManagementController>(() => SrManagementController());
      }),
    ),
    GetPage(
      name: AppRoutes.purchases,
      page: () => const PurchaseView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PurchaseController>(() => PurchaseController());
      }),
    ),
    GetPage(
      name: AppRoutes.sales,
      page: () => const SalesView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SalesController>(() => SalesController());
      }),
    ),
    GetPage(
      name: AppRoutes.srPanel,
      page: () => const SrPanelShell(),
    ),
  ];
}
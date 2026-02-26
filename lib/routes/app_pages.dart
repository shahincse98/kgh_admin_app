import 'package:get/get.dart';
import 'package:kgh_admin_app/order/controller/order_controller.dart';
import 'package:kgh_admin_app/order/view/order_list_view.dart';
import '../modules/home/view/home_view.dart';
import '../modules/home/controller/home_controller.dart';
import '../modules/product/view/product_list_view.dart';
import '../modules/product/controller/product_controller.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
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
      name: AppRoutes.products,
      page: () => const ProductListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProductController>(() => ProductController());
      }),
    ),
  ];
}
import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/product/controller/product_controller.dart';
import 'package:kgh_admin_app/order/controller/order_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ProductController(), permanent: true);
    Get.put(OrderController(), permanent: true);
  }
  
}
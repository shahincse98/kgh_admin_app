import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/auth/controller/auth_controller.dart';
import 'package:kgh_admin_app/modules/product/controller/product_controller.dart';
import 'package:kgh_admin_app/modules/product/controller/replace_controller.dart';
import 'package:kgh_admin_app/modules/order/controller/order_controller.dart';
import 'package:kgh_admin_app/modules/user/controller/user_controller.dart';
import 'package:kgh_admin_app/modules/sr/controller/sr_management_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(UserController(), permanent: true);
    Get.put(ProductController(), permanent: true);
    Get.put(ReplaceController(), permanent: true);
    Get.put(OrderController(), permanent: true);
    Get.put(SrManagementController(), permanent: true);
  }
  
}
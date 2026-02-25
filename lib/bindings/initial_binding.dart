import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/product/controller/product_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ProductController(), permanent: true);
  }
}
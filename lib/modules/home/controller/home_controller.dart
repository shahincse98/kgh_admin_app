import 'package:get/get.dart';
import '../model/dashboard_model.dart';

class HomeController extends GetxController {
  final dashboard = DashboardModel(
    totalOrders: 120,
    totalProducts: 58,
    totalRevenue: 125000,
  ).obs;

  // Future: load from Firebase
  void refreshDashboard() {
    dashboard.value = DashboardModel(
      totalOrders: dashboard.value.totalOrders + 1,
      totalProducts: dashboard.value.totalProducts,
      totalRevenue: dashboard.value.totalRevenue + 500,
    );
  }
}
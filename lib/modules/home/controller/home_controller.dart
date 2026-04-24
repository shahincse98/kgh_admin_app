import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/dashboard_model.dart';

class HomeController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final dashboard = DashboardModel(
    totalOrders: 0,
    totalProducts: 0,
    totalRevenue: 0,
    totalUsers: 0,
    pendingOrders: 0,
  ).obs;

  // month index (0=Jan) → revenue
  final monthlyRevenue = <int, double>{}.obs;

  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    loading.value = true;
    try {
      final results = await Future.wait([
        _db.collection('orders').get(),
        _db.collection('products').get(),
        _db.collection('users').get(),
        _db
            .collection('orders')
            .where('status', isEqualTo: 'pending')
            .get(),
      ]);

      final ordersSnap = results[0];
      final productsSnap = results[1];
      final usersSnap = results[2];
      final pendingSnap = results[3];

      num totalRevenue = 0;
      final monthly = <int, double>{};

      for (final doc in ordersSnap.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num? ?? 0).toDouble();
        totalRevenue += amount;

        final ts = data['createdAt'];
        if (ts is Timestamp) {
          final month = ts.toDate().month - 1; // 0-indexed
          monthly[month] = (monthly[month] ?? 0) + amount;
        }
      }

      monthlyRevenue.assignAll(monthly);

      dashboard.value = DashboardModel(
        totalOrders: ordersSnap.docs.length,
        totalProducts: productsSnap.docs.length,
        totalRevenue: totalRevenue.toInt(),
        totalUsers: usersSnap.docs.length,
        pendingOrders: pendingSnap.docs.length,
      );
    } catch (_) {
      // silent fail
    } finally {
      loading.value = false;
    }
  }
}

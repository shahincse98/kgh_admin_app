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

  bool _loadedOnce = false;
  DateTime? _lastLoaded;

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
  }

  Future<void> refreshDashboard({bool force = false}) async {
    final now = DateTime.now();
    // Skip re-fetch if loaded within last 3 minutes (unless forced)
    if (!force &&
        _loadedOnce &&
        _lastLoaded != null &&
        now.difference(_lastLoaded!) < const Duration(minutes: 3)) {
      return;
    }
    loading.value = true;
    try {
      // Use count() aggregation for counts (avoids downloading full docs)
      // Run all queries in parallel
      final orderSnapFuture = _db.collection('orders').get();
      final aggFutures = Future.wait([
        _db.collection('products').count().get(),
        _db.collection('users').count().get(),
        _db
            .collection('orders')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
      ]);

      final ordersSnap = await orderSnapFuture;
      final aggs = await aggFutures;
      final productsCount = aggs[0].count ?? 0;
      final usersCount = aggs[1].count ?? 0;
      final pendingCount = aggs[2].count ?? 0;

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
        totalProducts: productsCount,
        totalRevenue: totalRevenue.toInt(),
        totalUsers: usersCount,
        pendingOrders: pendingCount,
      );

      _loadedOnce = true;
      _lastLoaded = DateTime.now();
    } catch (_) {
      // silent fail
    } finally {
      loading.value = false;
    }
  }
}

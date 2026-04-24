import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class SalesOrderRow {
  final String id;
  final DateTime createdAt;
  final String shopName;
  final String shopPhone;
  final String status;
  final double totalAmount;
  final List<Map<String, dynamic>> items;

  SalesOrderRow({
    required this.id,
    required this.createdAt,
    required this.shopName,
    required this.shopPhone,
    required this.status,
    required this.totalAmount,
    required this.items,
  });
}

class SalesDayRow {
  final DateTime date;
  final List<SalesOrderRow> orders;
  double get totalRevenue =>
      orders.fold(0.0, (s, o) => s + o.totalAmount);
  int get orderCount => orders.length;

  SalesDayRow({required this.date, required this.orders});
}

class SalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = false.obs;
  final selectedMonth = DateTime.now().obs;

  final allOrders = <SalesOrderRow>[].obs;
  final dayRows = <SalesDayRow>[].obs;

  // Summary observables
  final monthRevenue = 0.0.obs;
  final monthOrderCount = 0.obs;
  final avgOrderValue = 0.0.obs;

  // Top products: {name -> qty}
  final topProducts = <MapEntry<String, int>>[].obs;
  // Top shops: {name -> revenue}
  final topShops = <MapEntry<String, double>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadData();
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    selectedMonth.value = next;
    loadData();
  }

  Future<void> loadData() async {
    loading.value = true;
    try {
      final m = selectedMonth.value;
      final start = DateTime(m.year, m.month);
      final end = DateTime(m.year, m.month + 1);

      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();

      final rows = snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['createdAt'];
        final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
        final items = (data['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        return SalesOrderRow(
          id: doc.id,
          createdAt: createdAt,
          shopName: (data['shopName'] ?? '').toString(),
          shopPhone: (data['shopPhone'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
          totalAmount:
              (data['totalAmount'] as num?)?.toDouble() ?? 0,
          items: items,
        );
      }).toList();

      allOrders.assignAll(rows);
      _buildSummary(rows);
    } finally {
      loading.value = false;
    }
  }

  void _buildSummary(List<SalesOrderRow> rows) {
    // Day grouping
    final dayMap = <String, List<SalesOrderRow>>{};
    for (final r in rows) {
      final key =
          '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')}';
      dayMap.putIfAbsent(key, () => []).add(r);
    }
    final keys = dayMap.keys.toList()..sort((a, b) => b.compareTo(a));
    dayRows.assignAll(keys.map((k) => SalesDayRow(
          date: DateTime.parse(k),
          orders: dayMap[k]!,
        )));

    // Summary
    final total = rows.fold(0.0, (s, r) => s + r.totalAmount);
    monthRevenue.value = total;
    monthOrderCount.value = rows.length;
    avgOrderValue.value = rows.isEmpty ? 0 : total / rows.length;

    // Top products
    final prodMap = <String, int>{};
    for (final r in rows) {
      for (final item in r.items) {
        final name = (item['productName'] ?? item['name'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (name.isNotEmpty) {
          prodMap[name] = (prodMap[name] ?? 0) + qty;
        }
      }
    }
    final sortedProds = prodMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topProducts.assignAll(sortedProds.take(8));

    // Top shops
    final shopMap = <String, double>{};
    for (final r in rows) {
      if (r.shopName.isNotEmpty) {
        shopMap[r.shopName] =
            (shopMap[r.shopName] ?? 0) + r.totalAmount;
      }
    }
    final sortedShops = shopMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topShops.assignAll(sortedShops.take(8));
  }
}

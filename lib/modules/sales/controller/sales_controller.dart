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
  final List<Map<String, dynamic>> payments;

  SalesOrderRow({
    required this.id,
    required this.createdAt,
    required this.shopName,
    required this.shopPhone,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.payments,
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

  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  final allOrders = <SalesOrderRow>[].obs;
  final dayRows = <SalesDayRow>[].obs;

  final monthRevenue = 0.0.obs;
  final monthOrderCount = 0.obs;
  final avgOrderValue = 0.0.obs;
  final totalExpenses = 0.0.obs;
  final totalPurchaseCost = 0.0.obs;

  final topProducts = <MapEntry<String, int>>[].obs;
  final topShops = <MapEntry<String, double>>[].obs;

  final paymentBreakdown = <MapEntry<String, double>>[].obs;

  @override
  void onInit() {
    super.onInit();
    final today = DateTime.now();
    fromDate.value = DateTime(today.year, today.month, today.day);
    toDate.value = DateTime(today.year, today.month, today.day, 23, 59, 59);
    loadData();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to != null ? DateTime(to.year, to.month, to.day, 23, 59, 59) : null;
    loadData();
  }

  Future<void> loadData() async {
    loading.value = true;
    try {
      final start = fromDate.value ?? DateTime.now().subtract(const Duration(days: 30));
      final end = toDate.value ?? DateTime.now();

      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();

      final rows = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        final ts = data['createdAt'];
        final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
        final items = (data['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final paymentsRaw = data['payments'];
        final payments = (paymentsRaw is List)
            ? paymentsRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : <Map<String, dynamic>>[];
        final da = data['deliveredAt'];
        final deliveredAt = da is Timestamp ? da.toDate() : null;
        return SalesOrderRow(
          id: doc.id,
          createdAt: deliveredAt ?? createdAt,
          shopName: (data['shopName'] ?? '').toString(),
          shopPhone: (data['shopPhone'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
          totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
          items: items,
          payments: payments,
        );
      }).whereType<SalesOrderRow>().toList();

      // Filter by date range in Dart (using the order's effective date)
      var filtered = rows;
      if (start != null) {
        filtered = filtered.where((r) {
          final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
          return !d.isBefore(DateTime(start.year, start.month, start.day));
        }).toList();
      }
      if (end != null) {
        filtered = filtered.where((r) {
          final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
          return !d.isAfter(end);
        }).toList();
      }

      allOrders.assignAll(filtered);
      _buildSummary(filtered);

      _loadExpenses(start, end); // fire-and-forget
    } catch (e) {
      print('SalesController loadData error: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> _loadExpenses(DateTime? start, DateTime? end) async {
    try {
      Query q = _db.collection('expenses');
      if (start != null) {
        q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(start.year, start.month, start.day)));
      }
      if (end != null) {
        q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
      final snap = await q.get();
      totalExpenses.value = snap.docs.fold(0.0, (s, d) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) return s;
        return s + ((data['amount'] as num?)?.toDouble() ?? 0);
      });
    } catch (_) {
      totalExpenses.value = 0;
    }

    try {
      Query q = _db.collection('purchases');
      if (start != null) {
        q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(start.year, start.month, start.day)));
      }
      if (end != null) {
        q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
      final snap = await q.get();
      totalPurchaseCost.value = snap.docs.fold(0.0, (s, d) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) return s;
        return s + ((data['totalAmount'] as num?)?.toDouble() ?? 0);
      });
    } catch (_) {
      totalPurchaseCost.value = 0;
    }
  }

  void _buildSummary(List<SalesOrderRow> rows) {
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

    final total = rows.fold(0.0, (s, r) => s + r.totalAmount);
    monthRevenue.value = total;
    monthOrderCount.value = rows.length;
    avgOrderValue.value = rows.isEmpty ? 0 : total / rows.length;

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

    final shopMap = <String, double>{};
    for (final r in rows) {
      if (r.shopName.isNotEmpty) {
        shopMap[r.shopName] = (shopMap[r.shopName] ?? 0) + r.totalAmount;
      }
    }
    final sortedShops = shopMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topShops.assignAll(sortedShops.take(8));

    final payMap = <String, double>{};
    for (final r in rows) {
      if (r.payments.isNotEmpty) {
        for (final p in r.payments) {
          final method = (p['method'] ?? '').toString();
          final amt = (p['amount'] as num?)?.toDouble() ?? 0;
          if (method.isNotEmpty && amt > 0) {
            payMap[method] = (payMap[method] ?? 0) + amt;
          }
        }
      } else if (r.totalAmount > 0) {
        // Fallback: use totalAmount for old orders
        payMap['জমা'] = (payMap['জমা'] ?? 0) + r.totalAmount;
      }
    }
    final sortedPay = payMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    paymentBreakdown.assignAll(sortedPay);
  }
}

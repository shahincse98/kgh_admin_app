import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../order/model/order_model.dart';

class SalesOrderRow {
  final String id;
  final DateTime createdAt;
  final String shopName;
  final String shopPhone;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final double deductionAmount;
  final double returnAmount;
  final double discountAmount;
  final double purchaseCost;
  final int previousDue;
  final String localMemo;
  final String memoNumber;
  final String paymentMethod;
  final String deliveryAssignedSrId;
  final String deliveryAssignedSrName;
  final String deliveredBySrId;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;

  /// Not cut off at zero (see OrderProfit).
  double get netSales =>
      totalAmount - discountAmount - deductionAmount - returnAmount;
  /// Goods that came back are not a loss (see OrderProfit).
  final double recovered;

  double get profit => netSales - purchaseCost + recovered;
  bool get hasSr =>
      deliveryAssignedSrId.isNotEmpty || deliveredBySrId.isNotEmpty;

  SalesOrderRow({
    required this.id,
    required this.createdAt,
    required this.shopName,
    required this.shopPhone,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.deductionAmount,
    required this.returnAmount,
    required this.discountAmount,
    required this.purchaseCost,
    this.recovered = 0,
    required this.previousDue,
    required this.localMemo,
    required this.memoNumber,
    required this.paymentMethod,
    required this.deliveryAssignedSrId,
    required this.deliveryAssignedSrName,
    required this.deliveredBySrId,
    required this.items,
    required this.payments,
  });
}

class SalesDayRow {
  final DateTime date;
  final List<SalesOrderRow> orders;

  /// Expenses dated on this day.
  final double expenses;

  double get totalNetSales =>
      orders.fold(0.0, (s, o) => s + o.netSales);
  double get totalPurchaseCost =>
      orders.fold(0.0, (s, o) => s + o.purchaseCost);
  double get totalRecovered =>
      orders.fold(0.0, (s, o) => s + o.recovered);

  /// Same as the day's page: sales − purchase price + goods back − expenses.
  double get netProfit =>
      totalNetSales - totalPurchaseCost + totalRecovered - expenses;
  double get totalDeduction =>
      orders.fold(0.0, (s, o) => s + o.deductionAmount);
  double get totalReturn =>
      orders.fold(0.0, (s, o) => s + o.returnAmount);
  double get totalDiscount =>
      orders.fold(0.0, (s, o) => s + o.discountAmount);
  int get orderCount => orders.length;

  SalesDayRow({required this.date, required this.orders, this.expenses = 0});
}

class SalesController extends GetxController {
  SalesController({this.srId});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// When set, only this SR's sales, collections and expenses are shown
  /// (the SR panel's day-wise sales).
  final String? srId;

  /// An order belongs to the SR who delivered it; older deliveries did not
  /// record that, so the assigned SR is used for them.
  bool _ownedBySr(SalesOrderRow r) => r.deliveredBySrId.isNotEmpty
      ? r.deliveredBySrId == srId
      : r.deliveryAssignedSrId == srId;

  /// Money collected on the orders of a day (for the SR: only what they took).
  double collectedOn(SalesDayRow row) {
    var sum = 0.0;
    for (final r in row.orders) {
      if (r.payments.isEmpty) {
        sum += (r.paidAmount - r.deductionAmount - r.returnAmount).clamp(0, double.infinity);
        continue;
      }
      for (final p in r.payments) {
        if (_takenBySr(p)) sum += (p['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return sum;
  }

  /// Payment taken by this SR (payments without an SR id belong to the order's SR).
  bool _takenBySr(Map<String, dynamic> p) {
    final by = (p['srId'] ?? '').toString();
    return srId == null || by.isEmpty || by == srId;
  }

  final loading = false.obs;

  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  final allOrders = <SalesOrderRow>[].obs;
  final dayRows = <SalesDayRow>[].obs;

  final monthNetSales = 0.0.obs;
  final monthOrderCount = 0.obs;
  final avgOrderValue = 0.0.obs;
  final totalExpenses = 0.0.obs;
  final totalPurchaseCost = 0.0.obs;
  final totalRecovered = 0.0.obs;
  final totalDeduction = 0.0.obs;
  final totalReturn = 0.0.obs;
  final totalDiscount = 0.0.obs;

  final topProducts = <MapEntry<String, int>>[].obs;
  final topShops = <MapEntry<String, double>>[].obs;

  final paymentBreakdown = <MapEntry<String, double>>[].obs;

  Map<String, num> _productCostById = {};

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
    toDate.value =
        to != null ? DateTime(to.year, to.month, to.day, 23, 59, 59) : null;
    loadData();
  }

  Future<void> _loadProductCosts() async {
    try {
      final snap = await _db.collection('products').get();
      _productCostById = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cost = (data['purchasePrice'] as num?) ?? 0;
        _productCostById[doc.id] = cost;
      }
    } catch (_) {}
  }

  Future<void> loadData() async {
    loading.value = true;
    try {
      await _loadProductCosts();

      final start =
          fromDate.value ?? DateTime.now().subtract(const Duration(days: 30));
      final end = toDate.value ?? DateTime.now();

      // Query a wide range by createdAt so we catch orders created earlier
      // but delivered within the selected period.
      final queryStart = DateTime(start.year - 1, start.month, start.day);
      final queryEnd = DateTime(end.year + 1, end.month, end.day);

      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(queryEnd))
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

        final money = orderProfitOf(data, (id) => _productCostById[id] ?? 0);

        return SalesOrderRow(
          id: doc.id,
          createdAt: deliveredAt ?? createdAt,
          shopName: (data['shopName'] ?? '').toString(),
          shopPhone: (data['shopPhone'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
          totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
          paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
          deductionAmount:
              (data['deductionAmount'] as num?)?.toDouble() ?? 0,
          returnAmount: (data['returnAmount'] as num?)?.toDouble() ?? 0,
          discountAmount:
              (data['discountAmount'] as num?)?.toDouble() ?? 0,
          purchaseCost: money.purchaseCost.toDouble(),
          recovered: money.recovered.toDouble(),
          previousDue: (data['previousDue'] as num?)?.toInt() ?? 0,
          localMemo: (data['localMemo'] ?? '').toString(),
          memoNumber: (data['memoNumber'] ?? '').toString(),
          paymentMethod: (data['paymentMethod'] ?? '').toString(),
          deliveryAssignedSrId:
              (data['deliveryAssignedSrId'] ?? '').toString(),
          deliveryAssignedSrName:
              (data['deliveryAssignedSrName'] ?? '').toString(),
          deliveredBySrId: (data['deliveredBySrId'] ?? '').toString(),
          items: items,
          payments: payments,
        );
      }).whereType<SalesOrderRow>().toList();

      var filtered = rows.where((r) {
        final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
        return !d.isBefore(DateTime(start.year, start.month, start.day)) &&
            !d.isAfter(DateTime(end.year, end.month, end.day)) &&
            (srId == null || _ownedBySr(r));
      }).toList();

      final expensesByDay = await _loadExpenses(start, end);
      allOrders.assignAll(filtered);
      _buildSummary(filtered, expensesByDay);
    } catch (e) {
      print('SalesController loadData error: $e');
    } finally {
      loading.value = false;
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Loads the period's expenses, sets [totalExpenses] and returns them
  /// summed per day (keyed by [_dayKey]).
  Future<Map<String, double>> _loadExpenses(DateTime? start, DateTime? end) async {
    final byDay = <String, double>{};
    try {
      Query q = _db.collection('expenses');
      if (start != null) {
        q = q.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(start.year, start.month, start.day)));
      }
      if (end != null) {
        q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
      final snap = await q.get();
      var total = 0.0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (srId != null && (data['srId'] ?? '').toString() != srId) continue;
        final amt = (data['amount'] as num?)?.toDouble() ?? 0;
        total += amt;
        final ts = data['date'];
        if (ts is Timestamp) {
          final key = _dayKey(ts.toDate());
          byDay[key] = (byDay[key] ?? 0) + amt;
        }
      }
      totalExpenses.value = total;
    } catch (_) {
      totalExpenses.value = 0;
    }
    return byDay;
  }

  void _buildSummary(List<SalesOrderRow> rows, Map<String, double> expensesByDay) {
    final dayMap = <String, List<SalesOrderRow>>{};
    for (final r in rows) {
      dayMap.putIfAbsent(_dayKey(r.createdAt), () => []).add(r);
    }
    // Days with only expenses are listed too, so the days add up to the total.
    final keys = {...dayMap.keys, ...expensesByDay.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    dayRows.assignAll(keys.map((k) => SalesDayRow(
          date: DateTime.parse(k),
          orders: dayMap[k] ?? [],
          expenses: expensesByDay[k] ?? 0,
        )));

    final netSales = rows.fold(0.0, (s, r) => s + r.netSales);
    final purchaseCost = rows.fold(0.0, (s, r) => s + r.purchaseCost);
    final deduction = rows.fold(0.0, (s, r) => s + r.deductionAmount);
    final returnAmt = rows.fold(0.0, (s, r) => s + r.returnAmount);
    final discount = rows.fold(0.0, (s, r) => s + r.discountAmount);

    monthNetSales.value = netSales;
    monthOrderCount.value = rows.length;
    avgOrderValue.value = rows.isEmpty ? 0 : netSales / rows.length;
    totalPurchaseCost.value = purchaseCost;
    totalRecovered.value = rows.fold(0.0, (s, r) => s + r.recovered);
    totalDeduction.value = deduction;
    totalReturn.value = returnAmt;
    totalDiscount.value = discount;

    final prodMap = <String, int>{};
    for (final r in rows) {
      for (final item in r.items) {
        final name =
            (item['productName'] ?? item['name'] ?? '').toString();
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
        shopMap[r.shopName] = (shopMap[r.shopName] ?? 0) + r.netSales;
      }
    }
    final sortedShops = shopMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topShops.assignAll(sortedShops.take(8));

    final payMap = <String, double>{};
    for (final r in rows) {
      if (r.payments.isNotEmpty) {
        for (final p in r.payments) {
          if (!_takenBySr(p)) continue;
          final method = (p['method'] ?? '').toString();
          final amt = (p['amount'] as num?)?.toDouble() ?? 0;
          if (method.isNotEmpty && amt > 0) {
            payMap[method] = (payMap[method] ?? 0) + amt;
          }
        }
      } else {
        final cash = (r.paidAmount - r.deductionAmount - r.returnAmount)
            .clamp(0, double.infinity)
            .toDouble();
        if (cash > 0) payMap['জমা'.tr] = (payMap['জমা'.tr] ?? 0) + cash;
      }
    }
    final sortedPay = payMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    paymentBreakdown.assignAll(sortedPay);
  }
}

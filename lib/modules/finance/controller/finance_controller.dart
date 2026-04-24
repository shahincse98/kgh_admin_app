import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

enum FinanceRange { today, week, month, custom }

class DayLedgerRow {
  final DateTime date;
  final double purchased;
  final double sold;
  double get net => sold - purchased;

  DayLedgerRow({
    required this.date,
    required this.purchased,
    required this.sold,
  });
}

class OrderProfitRow {
  final String id;
  final DateTime createdAt;
  final String shopName;
  final double revenue;
  final double cost;
  final double gross;
  final double commission;
  final double netBeforeSalary;

  OrderProfitRow({
    required this.id,
    required this.createdAt,
    required this.shopName,
    required this.revenue,
    required this.cost,
    required this.gross,
    required this.commission,
    required this.netBeforeSalary,
  });
}

class FinanceController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = false.obs;
  final selectedRange = FinanceRange.month.obs;

  // Custom date range
  final customStart = Rxn<DateTime>();
  final customEnd = Rxn<DateTime>();

  final commissionPercent = 6.0.obs;
  final srMonthlyFixedSalary = 0.0.obs;

  // Stock valuation (always current, not period-filtered)
  final stockCapital = 0.0.obs;
  final stockSaleValue = 0.0.obs;
  final stockAvgMarginPct = 0.0.obs;

  // Period-filtered KPIs
  final totalSales = 0.0.obs;
  final totalCost = 0.0.obs;
  final grossProfit = 0.0.obs;
  final grossMarginPct = 0.0.obs;
  final srCommissionCost = 0.0.obs;
  final salaryAllocated = 0.0.obs;
  final netProfit = 0.0.obs;
  final deliveredOrders = 0.obs;

  final orderRows = <OrderProfitRow>[].obs;

  final totalExpenses = 0.0.obs;
  final finalNetProfit = 0.0.obs;

  final totalPurchased = 0.0.obs;
  final dayLedger = <DayLedgerRow>[].obs;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _expenseDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _purchaseDocs = [];
  Map<String, int> _productCostById = {};

  @override
  void onInit() {
    super.onInit();
    refreshAnalytics();
  }

  Future<void> refreshAnalytics() async {
    loading.value = true;
    try {
      await _loadSettings();
      await _loadData();
      _calculate();
    } finally {
      loading.value = false;
    }
  }

  void setRange(FinanceRange range) {
    if (selectedRange.value == range && range != FinanceRange.custom) return;
    selectedRange.value = range;
    _calculate();
  }

  void setCustomRange(DateTime from, DateTime to) {
    customStart.value = from;
    customEnd.value = DateTime(to.year, to.month, to.day, 23, 59, 59);
    selectedRange.value = FinanceRange.custom;
    _calculate();
  }

  Future<void> saveSettings({
    required double commission,
    required double salary,
  }) async {
    await _db.collection('admin_settings').doc('finance').set({
      'srCommissionPercent': commission,
      'srMonthlyFixedSalary': salary,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    commissionPercent.value = commission;
    srMonthlyFixedSalary.value = salary;
    _calculate();
  }

  Future<void> _loadSettings() async {
    final doc =
        await _db.collection('admin_settings').doc('finance').get();
    final data = doc.data();
    commissionPercent.value =
        (data?['srCommissionPercent'] as num?)?.toDouble() ?? 6.0;
    srMonthlyFixedSalary.value =
        (data?['srMonthlyFixedSalary'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _db.collection('products').get(),
      _db.collection('orders').orderBy('createdAt', descending: true).get(),
      _db.collection('expenses').orderBy('date', descending: true).get(),
      _db.collection('stock_purchases').orderBy('date', descending: true).get(),
    ]);

    final products = results[0].docs;
    _orderDocs = results[1].docs;
    _expenseDocs = results[2].docs;
    _purchaseDocs = results[3].docs;

    _productCostById = {
      for (final p in products)
        p.id: (p.data()['purchasePrice'] as num?)?.toInt() ?? 0,
    };

    // Stock valuation — always current snapshot
    double capital = 0;
    double saleVal = 0;
    for (final p in products) {
      final map = p.data();
      final purchase = (map['purchasePrice'] as num?)?.toDouble() ?? 0;
      final wholesale = (map['wholesalePrice'] as num?)?.toDouble() ?? 0;
      final stock = (map['stock'] as num?)?.toDouble() ?? 0;
      capital += purchase * stock;
      saleVal += wholesale * stock;
    }
    stockCapital.value = capital;
    stockSaleValue.value = saleVal;
    stockAvgMarginPct.value =
        capital > 0 ? ((saleVal - capital) / capital) * 100 : 0;
  }

  void _calculate() {
    final range = selectedRange.value;
    final now = DateTime.now();
    final start = _periodStart(now, range);
    final end = range == FinanceRange.custom
        ? (customEnd.value ?? now)
        : now;

    double sales = 0;
    double cost = 0;
    double gross = 0;
    double commission = 0;
    int delivered = 0;
    final rows = <OrderProfitRow>[];

    for (final doc in _orderDocs) {
      final map = doc.data();
      final status = (map['status'] ?? '').toString().toLowerCase();
      if (status != 'delivered') continue;

      final ts = map['createdAt'];
      if (ts is! Timestamp) continue;
      final createdAt = ts.toDate();
      if (createdAt.isBefore(start)) continue;
      if (createdAt.isAfter(end)) continue;

      final revenue = (map['totalAmount'] as num?)?.toDouble() ?? 0;
      final items = (map['items'] as List?) ?? [];

      double orderCost = 0;
      for (final item in items) {
        if (item is! Map) continue;
        final productId = (item['productId'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        orderCost +=
            (_productCostById[productId] ?? 0).toDouble() * qty;
      }

      final orderGross = revenue - orderCost;
      final orderCommission =
          revenue * (commissionPercent.value / 100.0);

      sales += revenue;
      cost += orderCost;
      gross += orderGross;
      commission += orderCommission;
      delivered += 1;

      rows.add(OrderProfitRow(
        id: doc.id,
        createdAt: createdAt,
        shopName: (map['shopName'] ?? '').toString(),
        revenue: revenue,
        cost: orderCost,
        gross: orderGross,
        commission: orderCommission,
        netBeforeSalary: orderGross - orderCommission,
      ));
    }

    final salary = _salaryForRange(now, range);

    double expenses = 0;
    for (final doc in _expenseDocs) {
      final ts = doc.data()['date'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(start) || dt.isAfter(end)) continue;
      expenses += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }

    double purchased = 0;
    final purchaseDayMap = <String, double>{};
    for (final doc in _purchaseDocs) {
      final ts = doc.data()['date'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(start) || dt.isAfter(end)) continue;
      final amt = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      purchased += amt;
      final key = _dateKey(dt);
      purchaseDayMap[key] = (purchaseDayMap[key] ?? 0) + amt;
    }

    totalSales.value = sales;
    totalCost.value = cost;
    grossProfit.value = gross;
    grossMarginPct.value = sales > 0 ? (gross / sales) * 100 : 0;
    srCommissionCost.value = commission;
    salaryAllocated.value = salary;
    netProfit.value = gross - commission - salary;
    totalExpenses.value = expenses;
    finalNetProfit.value = gross - commission - salary - expenses;
    deliveredOrders.value = delivered;
    totalPurchased.value = purchased;

    final salesDayMap = <String, double>{};
    for (final row in rows) {
      final key = _dateKey(row.createdAt);
      salesDayMap[key] = (salesDayMap[key] ?? 0) + row.revenue;
    }

    final allKeys = <String>{
      ...purchaseDayMap.keys,
      ...salesDayMap.keys,
    };
    final ledger = allKeys.map((k) {
      final date = DateTime.parse(k);
      return DayLedgerRow(
        date: date,
        purchased: purchaseDayMap[k] ?? 0,
        sold: salesDayMap[k] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    dayLedger.assignAll(ledger);

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orderRows.assignAll(rows);
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  DateTime _periodStart(DateTime now, FinanceRange range) {
    switch (range) {
      case FinanceRange.today:
        return DateTime(now.year, now.month, now.day);
      case FinanceRange.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case FinanceRange.month:
        return DateTime(now.year, now.month, 1);
      case FinanceRange.custom:
        return customStart.value ??
            DateTime(now.year, now.month, 1);
    }
  }

  double _salaryForRange(DateTime now, FinanceRange range) {
    if (srMonthlyFixedSalary.value <= 0) return 0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    switch (range) {
      case FinanceRange.today:
        return srMonthlyFixedSalary.value / daysInMonth;
      case FinanceRange.week:
        return (srMonthlyFixedSalary.value / daysInMonth) * 7;
      case FinanceRange.month:
        return srMonthlyFixedSalary.value;
      case FinanceRange.custom:
        if (customStart.value != null && customEnd.value != null) {
          final days =
              customEnd.value!.difference(customStart.value!).inDays + 1;
          return (srMonthlyFixedSalary.value / daysInMonth) * days;
        }
        return srMonthlyFixedSalary.value;
    }
  }
}

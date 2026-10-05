import 'package:cloud_firestore/cloud_firestore.dart';

import '../../order/model/order_model.dart';
import 'bank_loan.dart';

/// Calculation behind the daily accounts page (দিনের হিসাব), kept free of
/// Firestore queries and widgets so it can be tested.
///
/// SR balance for the period:
///   SR হাতে আদায় − খরচ − SR জমা = SR-এর কাছে বাকি
/// A negative result means the SR paid/deposited more and is owed money.

/// Cash collected in hand by the SR (or admin in hand when no SR).
const srHandMethods = {'SR হাতে', 'হাতে'};

/// Money that reaches the business directly, not through the SR's hand.
const directMethods = {'বিকাশ', 'নগদ', 'নগদ অ্যাপ', 'নগদ (মোবাইল)', 'রকেট', 'ব্যাংক'};

/// Default expense categories (খাত); custom ones are added on top.
const defaultExpenseCategories = [
  'কুরিয়ার খরচ',
  'যাতায়াত খরচ',
  'বাইকের তেল',
  'পরিবহন ভাড়া',
  'দোকান খরচ',
  'বাইক সার্ভিসিং',
  'ভাড়া',
  'বিদ্যুৎ',
  'কর্মচারী বেতন',
  'অন্যান্য',
];

/// Old expense-page type codes and the category each one means.
const expenseTypeCategories = {
  'rent': 'ভাড়া',
  'electricity': 'বিদ্যুৎ',
  'transport': 'পরিবহন ভাড়া',
  'salary': 'কর্মচারী বেতন',
  'misc': 'অন্যান্য',
};

/// The old type code for a category (for icons/colours and the `type` field).
String expenseTypeOf(String category) {
  for (final e in expenseTypeCategories.entries) {
    if (e.value == category) return e.key;
  }
  return 'misc';
}

/// Expenses are saved with a Bengali `category` from the daily page, and
/// with an English `type` code from the expense page. Both map to one label.
String expenseCategoryOf(Map<String, dynamic> e) {
  final c = (e['category'] ?? '').toString().trim();
  if (c.isNotEmpty) return c;
  return expenseTypeCategories[(e['type'] ?? '').toString()] ?? 'অন্যান্য';
}

double _d(dynamic v) => v is num ? v.toDouble() : 0;

DateTime? _time(dynamic v) => v is Timestamp ? v.toDate() : null;

/// When an order was delivered (falls back to creation time).
DateTime? orderDayTime(Map<String, dynamic> o) =>
    _time(o['deliveredAt']) ?? _time(o['createdAt']);

class DaySummary {
  int orderCount = 0;
  double gross = 0;
  double discount = 0;
  double deduction = 0;
  double returnAmount = 0;
  double netSales = 0;
  double purchaseCost = 0;

  /// Collected in hand (SR হাতে / হাতে) during the period.
  double srHand = 0;

  /// bKash / Nagad / Rocket / bank — reaches the business directly.
  double direct = 0;

  /// Payment entries with an unknown method.
  double adjustments = 0;

  /// Collections in the period for orders delivered on an earlier day.
  double laterCollections = 0;

  /// Due of the served shops before / after the period.
  double previousDue = 0;
  double newDue = 0;

  /// Purchase value of goods that came back (returns, replace-ins).
  double recovered = 0;

  double expenses = 0;
  double deposits = 0;
  final Map<String, double> expenseByCategory = {};

  /// Everything handed to the bank in the period (instalment + savings).
  /// Repaying a loan and saving money are not business costs, so this never
  /// touches profit — only the cash held.
  double bankPaid = 0;

  /// The instalment part, which lowers what the bank is still owed.
  double bankInstallment = 0;

  /// The savings part, which the business keeps at the bank.
  double bankSavings = 0;

  /// The part of [bankPaid] that was paid out of an SR's cash.
  double bankFromSr = 0;

  double get totalCollected => srHand + direct;
  double get srBalance => srHand - expenses - deposits - bankFromSr;
  double get grossProfit => netSales - purchaseCost + recovered;
  double get netProfit => grossProfit - expenses;
}

/// [orders]: orders delivered within [from]..[to] (their sales count).
/// [paymentOnlyOrders]: orders delivered earlier that got a payment within
/// the period; only those payments count.
///
/// Each map in [orders] is annotated with `_orderNet`, `_cashPaid`,
/// `_newDue`, `_purchaseCost` and `_recovered` for the order cards.
DaySummary computeDaySummary({
  required List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> paymentOnlyOrders = const [],
  required List<Map<String, dynamic>> expenses,
  required List<Map<String, dynamic>> deposits,
  List<Map<String, dynamic>> bankInstallments = const [],
  required Map<String, num> productCost,
  required DateTime from,
  required DateTime to,
  String? srId,
}) {
  final s = DaySummary();

  /// For one SR's account: a payment counts when that SR took it. Payments
  /// saved before the SR id was recorded belong to the order's SR.
  bool ownedBySr(Map<String, dynamic> o) {
    final by = (o['deliveredBySrId'] ?? '').toString();
    if (by.isNotEmpty) return by == srId;
    return (o['deliveryAssignedSrId'] ?? '').toString() == srId;
  }

  bool takenBySr(Map<String, dynamic> o, Map<String, dynamic> p) {
    if (srId == null) return true;
    final pSr = (p['srId'] ?? '').toString();
    return pSr.isNotEmpty ? pSr == srId : ownedBySr(o);
  }

  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
  bool inPeriod(Map<String, dynamic> p) {
    final t = _time(p['date']);
    // Payments saved before payment dates existed were taken at delivery.
    return t == null || (!t.isBefore(start) && !t.isAfter(end));
  }

  /// Adds an order's payments to the collection totals and returns the
  /// total credited by them (all methods).
  double collect(Map<String, dynamic> o, {required bool onlyDated}) {
    final payments = (o['payments'] as List?) ?? const [];
    var credited = 0.0;
    var hand = 0.0;
    var inHand = 0.0; // SR হাতে / হাতে only
    var counted = false;
    for (final raw in payments) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final amt = _d(p['amount']);
      if (amt <= 0) continue;
      counted = true;
      if (onlyDated ? _time(p['date']) == null || !inPeriod(p) : !inPeriod(p)) {
        continue;
      }
      if (!takenBySr(o, p)) continue;
      var method = (p['method'] ?? '').toString().trim();
      if (method.isEmpty) method = (o['paymentMethod'] ?? '').toString().trim();
      if (method.isEmpty) method = 'SR হাতে';
      credited += amt;
      if (srHandMethods.contains(method)) {
        s.srHand += amt;
        hand += amt;
        inHand += amt;
      } else if (directMethods.contains(method)) {
        s.direct += amt;
        hand += amt;
      } else {
        s.adjustments += amt;
      }
    }
    if (!counted && !onlyDated && (srId == null || ownedBySr(o))) {
      // Old orders without a payments list: paidAmount also holds the
      // replace/return credits, which are not cash.
      final cash = (_d(o['paidAmount']) - _d(o['deductionAmount']) - _d(o['returnAmount']))
          .clamp(0, double.infinity)
          .toDouble();
      final method = (o['paymentMethod'] ?? '').toString().trim();
      if (directMethods.contains(method)) {
        s.direct += cash;
      } else {
        s.srHand += cash;
        inHand = cash;
      }
      credited = cash;
      hand = cash;
    }
    o['_cashPaid'] = hand;
    o['_inHand'] = inHand;
    return credited;
  }

  final byShop = <String, List<Map<String, dynamic>>>{};
  for (final o in orders) {
    final total = _d(o['totalAmount']);
    final discount = _d(o['discountAmount']);
    final deduction = _d(o['deductionAmount']);
    final ret = _d(o['returnAmount']);
    s.orderCount++;
    s.gross += total;
    s.discount += discount;
    s.deduction += deduction;
    s.returnAmount += ret;
    final p = orderProfitOf(o, (id) => productCost[id] ?? 0);
    final net = p.netSales.toDouble();
    final cost = p.purchaseCost.toDouble();
    s.netSales += net;
    s.purchaseCost += cost;
    s.recovered += p.recovered.toDouble();

    final credited = collect(o, onlyDated: false);
    o['_orderNet'] = net;
    o['_purchaseCost'] = cost;
    o['_recovered'] = p.recovered.toDouble();
    o['_credited'] = credited;
    o['_newDue'] = (_d(o['previousDue']) + net - credited).clamp(0, double.infinity);

    final shop = (o['userId'] ?? '').toString().isNotEmpty
        ? o['userId'].toString()
        : (o['shopName'] ?? '').toString();
    byShop.putIfAbsent(shop, () => []).add(o);
  }

  for (final o in paymentOnlyOrders) {
    final before = s.srHand + s.direct;
    collect(o, onlyDated: true);
    s.laterCollections += s.srHand + s.direct - before;
  }

  // A shop served several times: start from the due before its first
  // delivery in the period and apply every order and payment after it.
  for (final list in byShop.values) {
    list.sort((a, b) => (orderDayTime(a) ?? start).compareTo(orderDayTime(b) ?? start));
    final opening = _d(list.first['previousDue']);
    final change = list.fold<double>(
        0, (sum, o) => sum + _d(o['_orderNet']) - _d(o['_credited']));
    s.previousDue += opening;
    s.newDue += (opening + change).clamp(0, double.infinity);
  }

  for (final e in expenses) {
    final amt = _d(e['amount']);
    s.expenses += amt;
    final cat = expenseCategoryOf(e);
    s.expenseByCategory[cat] = (s.expenseByCategory[cat] ?? 0) + amt;
  }
  s.deposits = deposits.fold(0.0, (sum, d) => sum + _d(d['amount']));

  // Bank deposits: the instalment pays down the loan and the savings part
  // stays the business's own money. Either way the cash leaves the box
  // without being a cost, so both are kept out of profit. Paid from an SR's
  // cash, they lower what that SR still holds.
  for (final b in bankInstallments) {
    final paidBySr = (b['srId'] ?? '').toString();
    if (srId != null && paidBySr != srId) continue;
    final amt = BankLoan.paidOf(b).toDouble();
    s.bankPaid += amt;
    s.bankInstallment += BankLoan.installmentOf(b).toDouble();
    s.bankSavings += BankLoan.savingsOf(b).toDouble();
    if (paidBySr.isNotEmpty) s.bankFromSr += amt;
  }
  return s;
}

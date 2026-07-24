import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/call_button.dart';

class DaySalesDetailView extends StatefulWidget {
  final DateTime date;
  const DaySalesDetailView({super.key, required this.date});

  @override
  State<DaySalesDetailView> createState() => _DaySalesDetailViewState();
}

class _DaySalesDetailViewState extends State<DaySalesDetailView> {
  final _db = FirebaseFirestore.instance;
  final _fmtInt = NumberFormat('#,##,##0');
  final _dateFmt = DateFormat('dd MMMM yyyy');
  final _timeFmt = DateFormat('h:mm a');

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _expenses = [];
  Map<String, num> _productCostById = {};
  int _orderCount = 0;
  double _srHand = 0;
  double _bkash = 0;
  double _others = 0;
  double _adjustments = 0;
  double _totalNetSales = 0;
  double _totalGross = 0;
  double _totalPurchaseCost = 0;
  double _totalSrCommission = 0;
  double _commissionPercent = 6.0;
  double _totalDeduction = 0;
  double _totalReturn = 0;
  double _totalDiscount = 0;
  double _totalPreviousDue = 0;
  double _totalNewDue = 0;
  double _totalExpenses = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final d = widget.date;
      final dayStart = DateTime(d.year, d.month, d.day);
      final dayEnd = DateTime(d.year, d.month, d.day, 23, 59, 59);

      await _loadProductCosts();
      await _loadCommissionPercent();

      final queryStart = DateTime(d.year - 1, d.month, d.day);
      final queryEnd = DateTime(d.year + 1, d.month, d.day);
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(queryEnd))
          .orderBy('createdAt', descending: true)
          .get();

      final all = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final da = data['deliveredAt'];
        final dt = da is Timestamp
            ? da.toDate()
            : (data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : null);
        if (dt == null) continue;
        if (dt.isBefore(dayStart) || dt.isAfter(dayEnd)) continue;
        data['_docId'] = doc.id;
        all.add(data);
      }

      _orders = all;
      _orderCount = all.length;
      _totalGross = 0;
      _totalNetSales = 0;
      _totalPurchaseCost = 0;
      _srHand = 0;
      _bkash = 0;
      _others = 0;
      _adjustments = 0;
      _totalDeduction = 0;
      _totalReturn = 0;
      _totalDiscount = 0;
      _totalPreviousDue = 0;
      _totalNewDue = 0;

      final Map<String, Map<String, dynamic>> lastOrderByShop = {};

      for (final o in _orders) {
        final orderTotal = (o['totalAmount'] as num?)?.toDouble() ?? 0;
        final paidAmount = (o['paidAmount'] as num?)?.toDouble() ?? 0;
        final deduction = (o['deductionAmount'] as num?)?.toDouble() ?? 0;
        final returnAmt = (o['returnAmount'] as num?)?.toDouble() ?? 0;
        final discount = (o['discountAmount'] as num?)?.toDouble() ?? 0;
        final previousDue = (o['previousDue'] as num?)?.toDouble() ?? 0;

        _totalGross += orderTotal;
        _totalDeduction += deduction;
        _totalReturn += returnAmt;
        _totalDiscount += discount;

        final net = (orderTotal - discount - deduction - returnAmt).clamp(0, double.infinity).toDouble();
        _totalNetSales += net;

        final items = (o['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        double purchaseCost = 0;
        for (final item in items) {
          final pid = (item['productId'] ?? '').toString();
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final costInOrder = (item['purchasePrice'] as num?) ?? 0;
          if (costInOrder > 0) {
            purchaseCost += costInOrder * qty;
          } else {
            purchaseCost += (_productCostById[pid] ?? 0) * qty;
          }
        }
        _totalPurchaseCost += purchaseCost;
        o['_purchaseCost'] = purchaseCost;

        double actualCash = 0;
        double cashPaid = 0;
        final payments = o['payments'];
        bool processedPayments = false;
        if (payments is List && payments.isNotEmpty) {
          for (final p in payments) {
            try {
              final pMap = Map<String, dynamic>.from(p as Map);
              final method = (pMap['method'] ?? '').toString().trim();
              final amt = (pMap['amount'] as num?)?.toDouble() ?? 0;
              if (amt <= 0) continue;
              processedPayments = true;
              cashPaid += amt;
              if (method == 'SR হাতে') {
                _srHand += amt;
                actualCash += amt;
              } else if (method == 'বিকাশ') {
                _bkash += amt;
                actualCash += amt;
              } else if (['নগদ', 'রকেট', 'ব্যাংক'].contains(method)) {
                _others += amt;
                actualCash += amt;
              } else {
                _adjustments += amt;
              }
            } catch (_) {}
          }
        }
        if (!processedPayments) {
          cashPaid = paidAmount;
          actualCash = (paidAmount - deduction - returnAmt).clamp(0, double.infinity).toDouble();
          _adjustments += (deduction + returnAmt);
          final method = (o['paymentMethod'] ?? '').toString().trim();
          if (method == 'বিকাশ') {
            _bkash += actualCash;
          } else {
            _srHand += actualCash;
          }
        }

        final newDue = (previousDue + net - cashPaid).clamp(0, double.infinity);
        _totalNewDue += newDue;

        o['_orderNet'] = net;
        o['_cashPaid'] = actualCash;
        o['_newDue'] = newDue;

        final userId = (o['userId'] ?? o['uid'] ?? '').toString();
        if (userId.isNotEmpty) {
          lastOrderByShop[userId] = o;
        }
      }

      _totalPreviousDue = 0;
      double distinctNewDue = 0;
      for (final o in lastOrderByShop.values) {
        final previousDue = (o['previousDue'] as num?)?.toDouble() ?? 0;
        final net = (o['_orderNet'] as num?)?.toDouble() ?? 0;
        final actualCash = (o['_cashPaid'] as num?)?.toDouble() ?? 0;
        _totalPreviousDue += previousDue;
        distinctNewDue += (previousDue + net - actualCash).clamp(0, double.infinity);
      }
      _totalNewDue = distinctNewDue;

      _totalSrCommission = _totalNetSales * (_commissionPercent / 100);

      final eSnap = await _db
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();

      _expenses = eSnap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{...data, 'id': d.id};
      }).toList();
      _expenses.sort((a, b) {
        final aT = a['date'] as Timestamp?;
        final bT = b['date'] as Timestamp?;
        if (aT == null || bT == null) return 0;
        return bT.compareTo(aT);
      });

      _totalExpenses = _expenses.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    } catch (e) { debugPrint('DaySalesDetailView loadData error: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _loadProductCosts() async {
    try {
      final snap = await _db.collection('products').get();
      _productCostById = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        _productCostById[doc.id] = (data['purchasePrice'] as num?) ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _loadCommissionPercent() async {
    try {
      final doc = await _db.collection('admin_settings').doc('finance').get();
      if (doc.exists) {
        final data = doc.data();
        _commissionPercent = (data?['srCommissionPercent'] as num?)?.toDouble() ?? 6.0;
      }
    } catch (_) {}
  }

  Future<void> _addExpense() async {
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final catCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন খরচ যোগ', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'টাকার পরিমাণ', prefixText: '৳ ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'খাত (যেমন: কাগজ, কলম)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'বিবরণ', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white), child: const Text('যোগ করুন')),
        ],
      ),
    );

    if (ok == true) {
      final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
      final category = catCtrl.text.trim();
      final note = noteCtrl.text.trim();
      await _db.collection('expenses').add({
        'amount': amount.toDouble(),
        'category': category.isNotEmpty ? category : 'অন্যান্য',
        'note': note.isNotEmpty ? note : 'খরচ',
        'date': Timestamp.fromDate(widget.date),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadData();
    }
    noteCtrl.dispose(); amountCtrl.dispose(); catCtrl.dispose();
  }

  Future<void> _deleteExpense(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('খরচ ডিলিট?'), content: const Text('এই খরচ এন্ট্রি মুছে ফেলা হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('ডিলিট')),
        ],
      ),
    );
    if (ok == true) { await _db.collection('expenses').doc(id).delete(); _loadData(); }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_dateFmt.format(widget.date)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense, icon: const Icon(Icons.add_rounded), label: const Text('খরচ যোগ'),
        backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                children: [
                  _summaryCards(scheme),
                  const SizedBox(height: 16),
                  if (_orders.isNotEmpty) ...[
                    _ordersDropdown(scheme),
                  ] else
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কোনো অর্ডার নেই', style: TextStyle(color: Colors.grey)))),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Text('খরচ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    Text('মোট: ৳ ${_fmtInt.format(_totalExpenses.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  ]),
                  const SizedBox(height: 8),
                  if (_expenses.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কোনো খরচ নেই', style: TextStyle(color: Colors.grey))))
                  else
                    ..._expenses.map((e) => _expenseCard(scheme, e)),
                ],
              ),
            ),
    );
  }

  Widget _summaryCards(ColorScheme scheme) {
    final totalDue = _totalPreviousDue + _totalNetSales;
    final totalCash = _srHand + _bkash + _others;
    final netProfit = _totalNetSales - _totalPurchaseCost - _totalSrCommission - _totalExpenses;
    final profitRateNoSr = _totalNetSales > 0 ? ((_totalNetSales - _totalPurchaseCost) / _totalNetSales * 100) : 0.0;
    final profitRateWithSr = _totalNetSales > 0 ? (netProfit / _totalNetSales * 100) : 0.0;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _card('মোট অর্ডার', '$_orderCount টি', Icons.receipt_long_rounded, const Color(0xFF0891B2)),
      _card('Gross বিক্রি', '৳ ${_fmtInt.format(_totalGross.toInt())}', Icons.shopping_cart_rounded, const Color(0xFF0891B2)),
      _card('পূর্বের বাকি', '৳ ${_fmtInt.format(_totalPreviousDue.toInt())}', Icons.history_rounded, const Color(0xFFD97706)),
      _card('মোট দেনা', '৳ ${_fmtInt.format(totalDue.toInt())}', Icons.account_balance_rounded, const Color(0xFF0891B2)),
      if (_totalDeduction > 0) _card('রিপ্লেস বাবদ', '৳ ${_fmtInt.format(_totalDeduction.toInt())}', Icons.swap_horiz_rounded, const Color(0xFF8B5CF6)),
      if (_totalReturn > 0) _card('ফেরত বাদ', '৳ ${_fmtInt.format(_totalReturn.toInt())}', Icons.keyboard_return_rounded, const Color(0xFF8B5CF6)),
      if (_totalDiscount > 0) _card('ডিসকাউন্ট', '৳ ${_fmtInt.format(_totalDiscount.toInt())}', Icons.discount_rounded, const Color(0xFFD97706)),
      _card('নেট বিক্রি', '৳ ${_fmtInt.format(_totalNetSales.toInt())}', Icons.trending_up_rounded, const Color(0xFF16A34A)),
      _card('জমা: SR হাতে', '৳ ${_fmtInt.format(_srHand.toInt())}', Icons.person_pin_rounded, const Color(0xFF7C3AED)),
      _card('বিকাশ/অন্যান্য', '৳ ${_fmtInt.format((_bkash + _others).toInt())}', Icons.account_balance_wallet_rounded, const Color(0xFFD97706)),
      _card('মোট জমা', '৳ ${_fmtInt.format(totalCash.toInt())}', Icons.payments_rounded, const Color(0xFF16A34A)),
      if (_adjustments > 0) _card('অ্যাডজাস্টমেন্ট', '৳ ${_fmtInt.format(_adjustments.toInt())}', Icons.tune_rounded, const Color(0xFF8B5CF6)),
      _card('নতুন বাকি', '৳ ${_fmtInt.format(_totalNewDue.toInt())}', Icons.hourglass_bottom_rounded, _totalNewDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
      _card('ক্রয় মূল্য', '৳ ${_fmtInt.format(_totalPurchaseCost.toInt())}', Icons.shopping_bag_rounded, const Color(0xFFD97706)),
      _card('SR কমিশন (${_commissionPercent.toStringAsFixed(0)}%)', '৳ ${_fmtInt.format(_totalSrCommission.toInt())}', Icons.person_pin_rounded, const Color(0xFF8B5CF6)),
      _card('নিট লাভ', '৳ ${_fmtInt.format(netProfit.toInt())}', Icons.savings_rounded, netProfit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
      _card('লাভের হার (SR বাদে)', '${profitRateNoSr.toStringAsFixed(2)}%', Icons.percent_rounded, const Color(0xFF10B981)),
      _card('লাভের হার (SR সহ)', '${profitRateWithSr.toStringAsFixed(2)}%', Icons.percent_rounded, const Color(0xFF8B5CF6)),
      _card('খরচ', '৳ ${_fmtInt.format(_totalExpenses.toInt())}', Icons.money_off_rounded, const Color(0xFFDC2626)),
    ]);
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: Card(
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 18), const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2), Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _ordersDropdown(ColorScheme scheme) {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: const Border(), collapsedShape: const Border(),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF0891B2)),
          const SizedBox(width: 8),
          Text('অর্ডার সমূহ (${_orders.length}টি)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('৳ ${_fmtInt.format(_totalNetSales.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0891B2))),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: _orders.map((o) => _orderCard(scheme, o)).toList(),
      ),
    );
  }

  Widget _orderCard(ColorScheme scheme, Map<String, dynamic> o) {
    final items = (o['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final payments = (o['payments'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final da = o['deliveredAt'];
    final deliveredAt = da is Timestamp ? da.toDate() : null;
    final ts = o['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final dt = deliveredAt ?? createdAt;
    final memo = (o['localMemo'] ?? '').toString();
    final dispatchMemo = (o['memoNumber'] ?? '').toString();
    final deduction = (o['deductionAmount'] as num?)?.toDouble() ?? 0;
    final returnAmt = (o['returnAmount'] as num?)?.toDouble() ?? 0;
    final discount = (o['discountAmount'] as num?)?.toDouble() ?? 0;
    final newDue = (o['_newDue'] as num?)?.toDouble() ?? 0;
    final cashPaid = (o['_cashPaid'] as num?)?.toDouble() ?? 0;
    final orderNet = (o['_orderNet'] as num?)?.toDouble() ?? 0;
    final purchaseCost = (o['_purchaseCost'] as num?)?.toDouble() ?? 0;
    final commission = orderNet * (_commissionPercent / 100);
    final profit = orderNet - purchaseCost - commission;

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: scheme.surfaceContainerHighest.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((o['shopName'] ?? 'Unknown').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                if ((o['shopPhone'] ?? '').toString().isNotEmpty)
                  Text((o['shopPhone'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            CallButton(phone: (o['shopPhone'] ?? '').toString()),
            const SizedBox(width: 6),
            Text('৳ ${_fmtInt.format((o['totalAmount'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0891B2))),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: scheme.outlineVariant.withAlpha(40)),
            const SizedBox(height: 6),
            ...items.take(3).map((item) => Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  (item['image'] ?? '').toString(),
                  width: 36, height: 36, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 36, height: 36, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_rounded, size: 16, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${item['productName'] ?? ''}: ${item['quantity'] ?? 0} × ৳${_fmtInt.format((item['pricePerUnit'] ?? 0).toInt())}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(180)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ])),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${items.length - 3}টি প্রডাক্ট', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
              ),
          ],
          if (cashPaid > 0) ...[
            const SizedBox(height: 4),
            Divider(height: 1, color: scheme.outlineVariant.withAlpha(40)),
            const SizedBox(height: 4),
            if (payments.isNotEmpty)
              Text(payments.map((p) => '${p['method']}: ৳${_fmtInt.format((p['amount'] as num?)?.toInt() ?? 0)}').join('  •  '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600))
            else
              Text('${o['paymentMethod'] ?? ''}: ৳${_fmtInt.format(cashPaid.toInt())}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED))),
          ],
          if (deduction > 0 || returnAmt > 0 || discount > 0) ...[
            const SizedBox(height: 2),
            Row(children: [
              if (deduction > 0) _tag('রিপ্লেস বাদ: ৳${_fmtInt.format(deduction.toInt())}', const Color(0xFFDC2626)),
              if (returnAmt > 0) _tag('ফেরত বাদ: ৳${_fmtInt.format(returnAmt.toInt())}', const Color(0xFF8B5CF6)),
              if (discount > 0) _tag('ডিসকাউন্ট: ৳${_fmtInt.format(discount.toInt())}', const Color(0xFFD97706)),
            ]),
          ],
          if (newDue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _tag('নতুন বাকি: ৳${_fmtInt.format(newDue.toInt())}', const Color(0xFFDC2626)),
            ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: profit >= 0 ? const Color(0xFF16A34A).withAlpha(10) : const Color(0xFFDC2626).withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Text('নেট: ৳${_fmtInt.format(orderNet.toInt())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
              const SizedBox(width: 8),
              Text('ক্রয়: ৳${_fmtInt.format(purchaseCost.toInt())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
              const SizedBox(width: 8),
              Text('লাভ: ৳${_fmtInt.format(profit.toInt())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
            ]),
          ),
          if (memo.isNotEmpty || dispatchMemo.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              if (memo.isNotEmpty) _tag('#$memo', const Color(0xFF0891B2)),
              if (dispatchMemo.isNotEmpty) _tag(dispatchMemo, const Color(0xFFD97706)),
            ]),
          ],
          const SizedBox(height: 3),
          Text('${(o['_docId'] ?? '').toString().substring(0, (o['_docId'] ?? '').toString().length.clamp(0, 8))}... • ${_timeFmt.format(dt)}',
              style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
        ]),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _expenseCard(ColorScheme scheme, Map<String, dynamic> e) {
    final ts = e['date'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text((e['note'] ?? e['category'] ?? 'খরচ').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${e['category'] ?? ''}${dt != null ? ' • ${_timeFmt.format(dt)}' : ''}', style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(100))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('৳ ${_fmtInt.format((e['amount'] as num?)?.toInt() ?? 0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), color: Colors.red.shade300, visualDensity: VisualDensity.compact, onPressed: () => _deleteExpense(e['id'] as String)),
        ]),
      ),
    );
  }
}

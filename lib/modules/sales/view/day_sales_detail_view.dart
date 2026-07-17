import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  double _srHand = 0;
  double _bkash = 0;
  double _others = 0;
  double _totalRevenue = 0;
  double _totalDeduction = 0;
  double _totalReturn = 0;
  double _totalDiscount = 0;
  double _totalDueCollected = 0;
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
      final start = DateTime(d.year, d.month, d.day);
      final end = DateTime(d.year, d.month, d.day, 23, 59, 59);

      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      final all = snap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            final da = data['deliveredAt'];
            final dt = da is Timestamp ? da.toDate() : (data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null);
            if (dt == null) return null;
            if (dt.isBefore(start) || dt.isAfter(end)) return null;
            data['_docId'] = doc.id;
            return data;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      _orders = all;
      _totalRevenue = 0;
      _srHand = 0;
      _bkash = 0;
      _others = 0;
      _totalDeduction = 0;
      _totalReturn = 0;
      _totalDiscount = 0;
      _totalDueCollected = 0;
      _totalNewDue = 0;

      for (final o in _orders) {
        final orderTotal = (o['totalAmount'] as num?)?.toDouble() ?? 0;
        _totalRevenue += orderTotal;
        final deduction = (o['deductionAmount'] as num?)?.toDouble() ?? 0;
        final returnAmt = (o['returnAmount'] as num?)?.toDouble() ?? 0;
        final discount = (o['discountAmount'] as num?)?.toDouble() ?? 0;
        _totalDeduction += deduction;
        _totalReturn += returnAmt;
        _totalDiscount += discount;

        final orderNet = (orderTotal - discount - deduction - returnAmt).clamp(0, double.infinity).toDouble();
        double cashPaid = 0;

        final payments = o['payments'];
        if (payments is List && payments.isNotEmpty) {
          for (final p in payments) {
            if (p is! Map) continue;
            final method = (p['method'] ?? '').toString();
            final amt = (p['amount'] as num?)?.toDouble() ?? 0;
            cashPaid += amt;
            if (method == 'SR হাতে') {
              _srHand += amt;
            } else if (method == 'বিকাশ') {
              _bkash += amt;
            } else {
              _others += amt;
            }
          }
        } else {
          final method = (o['paymentMethod'] ?? 'SR হাতে').toString();
          cashPaid = orderNet;
          if (method == 'SR হাতে') {
            _srHand += orderNet;
          } else if (method == 'বিকাশ') {
            _bkash += orderNet;
          } else {
            _others += orderNet;
          }
        }

        final dueCollected = (cashPaid - orderNet).clamp(0, double.infinity);
        _totalDueCollected += dueCollected;
        final previousDue = (o['previousDue'] as num?)?.toDouble() ?? 0;
        final newDue = (previousDue + orderNet - cashPaid).clamp(0, double.infinity);
        _totalNewDue += newDue;

        o['_orderNet'] = orderNet;
        o['_cashPaid'] = cashPaid;
        o['_dueCollected'] = dueCollected;
        o['_newDue'] = newDue;
      }

      final eSnap = await _db
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      _expenses = eSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return <String, dynamic>{...data, 'id': d.id};
      }).whereType<Map<String, dynamic>>().toList();
      _expenses.sort((a, b) {
        final aT = a['date'] as Timestamp?;
        final bT = b['date'] as Timestamp?;
        if (aT == null || bT == null) return 0;
        return bT.compareTo(aT);
      });

      _totalExpenses = _expenses.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    } catch (_) {}
    setState(() => _loading = false);
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
    final net = _totalRevenue - _totalExpenses;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _card('মোট বিক্রি', '৳ ${_fmtInt.format(_totalRevenue.toInt())}', Icons.trending_up_rounded, const Color(0xFF0891B2)),
      _card('SR হাতে', '৳ ${_fmtInt.format(_srHand.toInt())}', Icons.person_pin_rounded, const Color(0xFF7C3AED)),
      _card('বিকাশ/অন্যান্য', '৳ ${_fmtInt.format((_bkash + _others).toInt())}', Icons.account_balance_wallet_rounded, const Color(0xFFD97706)),
      _card('খরচ', '৳ ${_fmtInt.format(_totalExpenses.toInt())}', Icons.money_off_rounded, const Color(0xFFDC2626)),
      _card('বাকি কালেকশন', '৳ ${_fmtInt.format(_totalDueCollected.toInt())}', Icons.payments_rounded, const Color(0xFF10B981)),
      _card('রিপ্লেস/ফেরত বাদ', '৳ ${_fmtInt.format((_totalDeduction + _totalReturn).toInt())}', Icons.swap_horiz_rounded, const Color(0xFF8B5CF6)),
      _card('আজ বাকি পড়েছে', '৳ ${_fmtInt.format(_totalNewDue.toInt())}', Icons.hourglass_bottom_rounded, _totalNewDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
      _card('নিট', '৳ ${_fmtInt.format(net.toInt())}', Icons.savings_rounded, net >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
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
          Text('৳ ${_fmtInt.format(_totalRevenue.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0891B2))),
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
    final dueCollected = (o['_dueCollected'] as num?)?.toDouble() ?? 0;
    final newDue = (o['_newDue'] as num?)?.toDouble() ?? 0;
    final cashPaid = (o['_cashPaid'] as num?)?.toDouble() ?? 0;

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
              Text('${o['paymentMethod'] ?? 'SR হাতে'}: ৳${_fmtInt.format(cashPaid.toInt())}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED))),
            if (dueCollected > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _tag('বাকি কালেকশন: +৳${_fmtInt.format(dueCollected.toInt())}', const Color(0xFF10B981)),
              ),
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

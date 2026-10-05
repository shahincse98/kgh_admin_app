import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../localization/domain_labels.dart';
import '../../../widgets/responsive.dart';
import '../../order/controller/order_controller.dart';
import '../../sales/model/bank_loan.dart';
import '../../sales/model/day_summary.dart';
import '../../sales/view/money_entry_dialogs.dart';
import '../controller/sr_panel_controller.dart';
import '../../sales/controller/sales_controller.dart';
import '../../sales/view/sales_view.dart';
import '../../sales/view/day_sales_detail_view.dart';

/// The SR's own daily account (আমার হিসাব):
///   হাতে আদায় − খরচ − জমা = আমার কাছে আছে
/// The SR adds expenses and deposits here. Only this SR's entries count.
class SrAccountView extends StatefulWidget {
  const SrAccountView({super.key});

  @override
  State<SrAccountView> createState() => _SrAccountViewState();
}

class _SrAccountViewState extends State<SrAccountView> {
  final _db = FirebaseFirestore.instance;
  final _fmt = NumberFormat('#,##,##0');
  late final SrPanelController _sr;

  DateTime _day = DateTime.now();
  bool _loading = true;
  String _error = '';
  DaySummary _sum = DaySummary();
  List<Map<String, dynamic>> _collections = []; // orders with my collections
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _deposits = [];
  List<Map<String, dynamic>> _bank = []; // bank loan instalments I paid

  String get _srId => _sr.srDocId;
  String get _srName => _sr.srProfile.value?.name ?? '';

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    _sr = Get.find<SrPanelController>();
    _day = DateTime(_day.year, _day.month, _day.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final start = DateTime(_day.year, _day.month, _day.day);
      final end = DateTime(_day.year, _day.month, _day.day, 23, 59, 59);
      bool onDay(Map<String, dynamic> o) {
        final t = orderDayTime(o);
        return t != null && !t.isBefore(start) && !t.isAfter(end);
      }

      // Orders this SR delivered, or that were assigned to them (older
      // deliveries did not record who delivered).
      final results = await Future.wait([
        _db.collection('orders').where('deliveredBySrId', isEqualTo: _srId).get(),
        _db.collection('orders').where('deliveryAssignedSrId', isEqualTo: _srId).get(),
        _db
            .collection('orders')
            .where('paymentDays', arrayContains: OrderController.paymentDayKey(start))
            .get(),
        _db
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get(),
        _db
            .collection('sr_deposits')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get(),
        // Bank loan instalments paid out of this SR's cash.
        _db
            .collection(BankLoan.collection)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get(),
      ]);

      final delivered = <String, Map<String, dynamic>>{};
      for (final snap in results.take(2)) {
        for (final d in snap.docs) {
          final data = d.data();
          if ((data['status'] ?? '') != 'delivered' || !onDay(data)) continue;
          delivered[d.id] = {...data, '_docId': d.id};
        }
      }
      final later = <Map<String, dynamic>>[];
      for (final d in results[2].docs) {
        if (delivered.containsKey(d.id)) continue;
        final data = d.data();
        if ((data['status'] ?? '') != 'delivered') continue;
        later.add({...data, '_docId': d.id});
      }
      bool mine(Map<String, dynamic> e) => (e['srId'] ?? '').toString() == _srId;
      final expenses = results[3].docs.map((d) => {...d.data(), 'id': d.id}).where(mine).toList();
      final deposits = results[4].docs.map((d) => {...d.data(), 'id': d.id}).where(mine).toList();
      final bank = results[5].docs.map((d) => {...d.data(), 'id': d.id}).where(mine).toList();

      final orders = delivered.values.toList();
      final sum = computeDaySummary(
        orders: orders,
        paymentOnlyOrders: later,
        expenses: expenses,
        deposits: deposits,
        bankInstallments: bank,
        productCost: const {},
        from: start,
        to: end,
        srId: _srId,
      );
      // Show only orders where this SR actually collected something.
      final collections = [
        ...orders,
        ...later,
      ].where((o) => ((o['_inHand'] as num?) ?? 0) > 0).toList()
        ..sort((a, b) => (orderDayTime(b) ?? start).compareTo(orderDayTime(a) ?? start));

      if (!mounted) return;
      setState(() {
        _sum = sum;
        _collections = collections;
        _expenses = expenses;
        _deposits = deposits;
        _bank = bank;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shiftDay(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
    _load();
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d == null) return;
    setState(() => _day = DateTime(d.year, d.month, d.day));
    _load();
  }

  Future<void> _addExpense() async {
    if (await showAddExpenseDialog(context, date: _day, srId: _srId, srName: _srName)) _load();
  }

  Future<void> _addDeposit() async {
    final balance = _sum.srBalance;
    if (await showAddDepositDialog(context, date: _day, srId: _srId, srName: _srName, suggestedAmount: balance > 0 ? balance : null)) {
      _load();
    }
  }

  /// The SR paid a bank loan instalment out of their own cash.
  Future<void> _addBankInstallment() async {
    if (await showAddBankInstallmentDialog(context, date: _day, srId: _srId, srName: _srName)) {
      _load();
    }
  }

  /// An SR may remove their own entry for today only (to fix a mistake).
  Future<void> _delete(String collection, Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('এন্ট্রি মুছবেন?'.tr),
        content: Text('৳ ${_fmt.format(((e['amount'] as num?) ?? 0).round())} ${'এর এন্ট্রিটি মুছে ফেলা হবে।'.tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('না'.tr)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('মুছুন'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.collection(collection).doc(e['id'] as String).delete();
      _load();
    } catch (err) {
      Get.snackbar('মোছা যায়নি'.tr, '$err', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('আমার হিসাব'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'রিফ্রেশ'.tr, onPressed: _load)],
      ),
      body: ResponsiveWrapper(
        child: RefreshIndicator(
          onRefresh: _load,
          child: LayoutBuilder(builder: (ctx, c) {
            final wide = Rsp.isWide(c.maxWidth);
            final summary = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _dayBar(scheme),
              const SizedBox(height: 12),
              if (_error.isNotEmpty) _errorCard(),
              _balanceCard(scheme),
              const SizedBox(height: 12),
              _actions(),
              const SizedBox(height: 12),
              _navButtons(),
            ]);
            final lists = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _section(scheme, 'আদায়'.tr, Icons.payments_rounded, const Color(0xFF7C3AED), _sum.srHand,
                  _collections.map((o) => _collectionTile(scheme, o)).toList(), 'এই দিনে কোনো আদায় নেই'.tr),
              _section(scheme, 'খরচ'.tr, Icons.money_off_rounded, const Color(0xFFDC2626), _sum.expenses,
                  _expenses.map((e) => _entryTile(scheme, e, 'expenses', DomainLabels.expenseCategory(expenseCategoryOf(e)), const Color(0xFFDC2626))).toList(),
                  'কোনো খরচ নেই'.tr),
              _section(scheme, 'জমা'.tr, Icons.account_balance_wallet_rounded, const Color(0xFF0891B2), _sum.deposits,
                  _deposits.map((d) => _entryTile(scheme, d, 'sr_deposits', DomainLabels.paymentMethod((d['method'] ?? '').toString()), const Color(0xFF0891B2))).toList(),
                  'কোনো জমা নেই'.tr),
              if (_bank.isNotEmpty || _sum.bankFromSr > 0)
                _section(scheme, 'ব্যাংক জমা'.tr, Icons.account_balance_rounded, const Color(0xFF6366F1), _sum.bankFromSr,
                    _bank.map((b) => _entryTile(scheme, b, BankLoan.collection, _bankLabel(b), const Color(0xFF6366F1))).toList(),
                    'ব্যাংকে কোনো জমা নেই'.tr),
            ]);
            return ListView(
              padding: EdgeInsets.fromLTRB(Rsp.horizontalPad(c.maxWidth), 12, Rsp.horizontalPad(c.maxWidth), 24),
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: summary),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: lists),
                  ])
                else ...[
                  summary,
                  const SizedBox(height: 16),
                  lists,
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _dayBar(ColorScheme scheme) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), tooltip: 'আগের দিন'.tr, onPressed: () => _shiftDay(-1)),
          Expanded(
            child: InkWell(
              onTap: _pickDay,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(children: [
                  Text(_isToday ? 'আজ'.tr : DateFormat('EEEE').format(_day), style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                  Text(DateFormat('dd MMMM yyyy').format(_day), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), tooltip: 'পরের দিন'.tr, onPressed: _isToday ? null : () => _shiftDay(1)),
        ]),
      );

  Widget _errorCard() => Card(
        elevation: 0,
        color: Colors.red.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${'হিসাব লোড হয়নি — রিফ্রেশ করুন।'.tr}\n$_error', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _balanceCard(ColorScheme scheme) {
    final s = _sum;
    final balance = s.srBalance;
    final settled = balance.round() == 0;
    final owes = balance > 0;
    final color = settled ? const Color(0xFF16A34A) : (owes ? const Color(0xFF7C3AED) : const Color(0xFFDC2626));

    Widget line(String label, double amount, Color c, {String sign = ''}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface.withAlpha(200)))),
            Text('$sign৳ ${_fmt.format(amount.round())}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
          ]),
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withAlpha(60))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          line('হাতে আদায়'.tr, s.srHand, const Color(0xFF7C3AED)),
          line('খরচ'.tr, s.expenses, const Color(0xFFDC2626), sign: '− '),
          line('জমা দিয়েছি'.tr, s.deposits, const Color(0xFF0891B2), sign: '− '),
          if (s.bankFromSr > 0)
            line('ব্যাংক জমা'.tr, s.bankFromSr, const Color(0xFF6366F1), sign: '− '),
          const Divider(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(settled ? Icons.check_circle_rounded : (owes ? Icons.account_balance_wallet_rounded : Icons.reply_rounded), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  settled ? 'হিসাব মিলে গেছে'.tr : (owes ? 'আমার কাছে আছে (জমা দিতে হবে)'.tr : 'আমি পাব'.tr),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              Text('৳ ${_fmt.format(balance.abs().round())}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            ]),
          ),
          if (s.direct > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${'বিকাশ/ব্যাংকে সরাসরি আদায়'.tr} ৳${_fmt.format(s.direct.round())} — ${'এটা আপনার হাতে নেই'.tr}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
            ),
        ]),
      ),
    );
  }

  /// Day-wise account for this SR (orders, collections, expenses; no sales
  /// totals, purchase price or profit).
  void _openDayWise() {
    if (Get.isRegistered<SalesController>(tag: _srId)) {
      Get.find<SalesController>(tag: _srId).loadData();
    } else {
      Get.put(SalesController(srId: _srId), tag: _srId);
    }
    Get.to(() => SalesView(srId: _srId, srName: _srName));
  }

  /// Full detail of the selected day: orders, collections, expenses, deposits.
  Future<void> _openDayDetail() async {
    await Get.to(() => DaySalesDetailView(date: _day, srId: _srId, srName: _srName));
    _load();
  }

  Widget _navButtons() => Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
          onPressed: _openDayDetail,
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text('এই দিনের পুরো বিবরণ (অর্ডারসমূহ)'.tr),
        ),
        OutlinedButton.icon(
          onPressed: _openDayWise,
          icon: const Icon(Icons.calendar_view_day_rounded),
          label: Text('দিনওয়ারি হিসাব'.tr),
        ),
      ]);

  Widget _actions() => Row(children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.money_off_rounded),
              label: Text('খরচ যোগ'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _addDeposit,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text('টাকা জমা দিন'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0891B2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _addBankInstallment,
              icon: const Icon(Icons.account_balance_rounded),
              label: Text('ব্যাংক জমা'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
      ]);

  Widget _section(ColorScheme scheme, String title, IconData icon, Color color, double total, List<Widget> tiles, String empty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          Text('৳ ${_fmt.format(total.round())}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 6),
        if (tiles.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(empty, style: const TextStyle(color: Colors.grey))))
        else
          ...tiles,
      ]),
    );
  }

  Widget _collectionTile(ColorScheme scheme, Map<String, dynamic> o) {
    final memo = (o['localMemo'] ?? '').toString();
    final isDue = o['isDueCollection'] == true;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        title: Text((o['shopName'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (isDue) 'বাকি আদায়'.tr else '${'অর্ডার'.tr} ৳${_fmt.format(((o['totalAmount'] as num?) ?? 0).round())}',
          if (memo.isNotEmpty) '${'মেমো'.tr} #$memo',
        ].join(' • ')),
        trailing: Text('৳ ${_fmt.format(((o['_inHand'] as num?) ?? 0).round())}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
      ),
    );
  }

  /// One bank deposit reads as its two parts: কিস্তি ৮০০ + সঞ্চয় ১০০.
  String _bankLabel(Map<String, dynamic> b) {
    final savings = BankLoan.savingsOf(b);
    final inst = BankLoan.installmentOf(b);
    if (savings <= 0) return '${'কিস্তি'.tr} ৳ ${_fmt.format(inst.round())}';
    if (inst <= 0) return '${'সঞ্চয়'.tr} ৳ ${_fmt.format(savings.round())}';
    return '${'কিস্তি'.tr} ${_fmt.format(inst.round())} + ${'সঞ্চয়'.tr} ${_fmt.format(savings.round())}';
  }

  Widget _entryTile(ColorScheme scheme, Map<String, dynamic> e, String collection, String label, Color color) {
    final note = (e['note'] ?? '').toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        subtitle: note.isNotEmpty ? Text(note, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('৳ ${_fmt.format(((e['amount'] as num?) ?? 0).round())}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          if (_isToday)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: Colors.red.shade300,
              tooltip: 'মুছুন'.tr,
              onPressed: () => _delete(collection, e),
            ),
        ]),
      ),
    );
  }
}

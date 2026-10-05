import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/call_button.dart';
import '../../../widgets/responsive.dart';
import 'package:get/get.dart';
import '../../../localization/domain_labels.dart';
import '../../expense/expense_categories.dart';
import '../../order/controller/order_controller.dart';
import '../model/bank_loan.dart';
import '../model/day_summary.dart';
import 'money_entry_dialogs.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';

class DaySalesDetailView extends StatefulWidget {
  final DateTime date;

  /// Set when opened from the SR panel: only this SR's orders, collections,
  /// expenses and deposits, and no purchase price / profit.
  final String? srId;
  final String srName;
  const DaySalesDetailView({super.key, required this.date, this.srId, this.srName = ''});

  @override
  State<DaySalesDetailView> createState() => _DaySalesDetailViewState();
}

class _DaySalesDetailViewState extends State<DaySalesDetailView> {
  final _db = FirebaseFirestore.instance;
  final _fmtInt = NumberFormat('#,##,##0');
  final _timeFmt = DateFormat('h:mm a');


  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _allSrDeposits = [];
  List<Map<String, dynamic>> _bankInstallments = [];
  DaySummary _sum = DaySummary();

  /// Bank loan: total taken, instalments paid, what is still owed, and the
  /// savings built up beside it.
  ({num total, num paid, num outstanding, num savings}) _loan =
      (total: 0, paid: 0, outstanding: 0, savings: 0);

  /// Current purchase price per product, for items saved without one.
  Map<String, num> _productCostById = {};
  List<String> _categories = [...defaultExpenseCategories];
  bool _loading = true;
  String _loadError = '';

  /// Later collections are looked up day by day; beyond 30 days they are
  /// not included (Firestore allows at most 30 values per lookup).
  bool _laterPaymentsSkipped = false;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _selectedExpenseCategory = 'সব';
  String _selectedDepositMethod = 'সব';

  final _depositMethods = const ['সব', 'ব্যাংক', 'বিকাশ', 'হাতে'];

  bool get _isSr => widget.srId != null;

  bool _ownedBySr(Map<String, dynamic> o) {
    final by = (o['deliveredBySrId'] ?? '').toString();
    return by.isNotEmpty ? by == widget.srId : (o['deliveryAssignedSrId'] ?? '').toString() == widget.srId;
  }

  bool _mine(Map<String, dynamic> e) => !_isSr || (e['srId'] ?? '').toString() == widget.srId;

  bool get _isToday {
    final n = DateTime.now();
    return _fromDate.year == n.year && _fromDate.month == n.month && _fromDate.day == n.day;
  }

  bool get _singleDay =>
      _fromDate.year == _toDate.year && _fromDate.month == _toDate.month && _fromDate.day == _toDate.day;

  /// Filter options: every known category plus any found in the loaded data.
  List<String> get _expenseFilterOptions =>
      ['সব', ...{..._categories, ..._allExpenses.map(expenseCategoryOf)}];

  List<Map<String, dynamic>> get _filteredExpenses {
    if (_selectedExpenseCategory == 'সব') return _allExpenses;
    return _allExpenses.where((e) => expenseCategoryOf(e) == _selectedExpenseCategory).toList();
  }

  List<Map<String, dynamic>> get _filteredDeposits {
    if (_selectedDepositMethod == 'সব') return _allSrDeposits;
    return _allSrDeposits.where((d) {
      final method = (d['method'] ?? '').toString().trim();
      return method == _selectedDepositMethod;
    }).toList();
  }

  double get _filteredExpensesTotal =>
      _filteredExpenses.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

  double get _filteredDepositsTotal =>
      _filteredDeposits.fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

  @override
  void initState() {
    super.initState();
    final d = widget.date;
    _fromDate = DateTime(d.year, d.month, d.day);
    _toDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final dayStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final dayEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

      final costs = await _loadProductCosts();
      final cats = await ExpenseCategories.load();

      // Orders delivered in the period (queried widely by createdAt, then
      // filtered by delivery time).
      final queryStart = DateTime(_fromDate.year - 1, _fromDate.month, _fromDate.day);
      final queryEnd = DateTime(_toDate.year + 1, _toDate.month, _toDate.day);
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(queryEnd))
          .orderBy('createdAt', descending: true)
          .get();

      final orders = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final dt = orderDayTime(data);
        if (dt == null || dt.isBefore(dayStart) || dt.isAfter(dayEnd)) continue;
        if (_isSr && !_ownedBySr(data)) continue;
        data['_docId'] = doc.id;
        orders.add(data);
      }
      final orderIds = orders.map((o) => o['_docId']).toSet();

      // Orders delivered earlier that received money in this period.
      final dayKeys = <String>[
        for (var d = dayStart; !d.isAfter(dayEnd); d = DateTime(d.year, d.month, d.day + 1))
          OrderController.paymentDayKey(d),
      ];
      final paymentOnly = <Map<String, dynamic>>[];
      _laterPaymentsSkipped = dayKeys.length > 30;
      if (!_laterPaymentsSkipped) {
        final pSnap = await _db.collection('orders').where('paymentDays', arrayContainsAny: dayKeys).get();
        for (final doc in pSnap.docs) {
          if (orderIds.contains(doc.id)) continue;
          final data = doc.data();
          if ((data['status'] ?? '').toString() != 'delivered') continue;
          paymentOnly.add(data);
        }
      }

      final eSnap = await _db
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();
      final expenses = eSnap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).where(_mine).toList()
        ..sort(_byDateDesc);

      final dSnap = await _db
          .collection('sr_deposits')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();
      final deposits = dSnap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).where(_mine).toList()
        ..sort(_byDateDesc);

      // Bank loan instalments of the day, plus the loan's overall status.
      final bSnap = await _db
          .collection(BankLoan.collection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();
      final installments = bSnap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).where(_mine).toList()
        ..sort(_byDateDesc);
      final loan = _isSr
          ? (total: 0 as num, paid: 0 as num, outstanding: 0 as num, savings: 0 as num)
          : await BankLoan.status();

      final sum = computeDaySummary(
        orders: orders,
        paymentOnlyOrders: paymentOnly,
        expenses: expenses,
        deposits: deposits,
        bankInstallments: installments,
        productCost: costs,
        from: dayStart,
        to: dayEnd,
        srId: widget.srId,
      );

      if (!mounted) return;
      setState(() {
        _productCostById = costs;
        _orders = orders;
        _allExpenses = expenses;
        _allSrDeposits = deposits;
        _bankInstallments = installments;
        _loan = loan;
        _sum = sum;
        _categories = cats.items;
        if (!_expenseFilterOptions.contains(_selectedExpenseCategory)) _selectedExpenseCategory = 'সব';
      });
    } catch (e) {
      debugPrint('DaySalesDetailView loadData error: $e');
      // Never show zeros as if they were the real figures.
      if (mounted) setState(() => _loadError = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  static int _byDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aT = a['date'] as Timestamp?;
    final bT = b['date'] as Timestamp?;
    if (aT == null || bT == null) return 0;
    return bT.compareTo(aT);
  }

  Future<Map<String, num>> _loadProductCosts() async {
    final costs = <String, num>{};
    try {
      final snap = await _db.collection('products').get();
      for (final doc in snap.docs) {
        costs[doc.id] = (doc.data()['purchasePrice'] as num?) ?? 0;
      }
    } catch (_) {}
    return costs;
  }

  Future<void> _addExpense() async {
    final saved = await showAddExpenseDialog(context, date: _toDate, srId: widget.srId ?? '', srName: widget.srName);
    if (saved) _loadData();
  }

  void _showError(String title, Object e) {
    Get.snackbar(title, '$e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
  }

  Future<void> _deleteExpense(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('খরচ ডিলিট?'.tr), content: Text('এই খরচ এন্ট্রি মুছে ফেলা হবে।'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('না'.tr)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('ডিলিট'.tr)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _db.collection('expenses').doc(id).delete();
        _loadData();
      } catch (e) {
        _showError('ডিলিট হয়নি'.tr, e);
      }
    }
  }

  Future<void> _addDeposit() async {
    final saved = await showAddDepositDialog(context, date: _toDate, srId: widget.srId ?? '', srName: widget.srName);
    if (saved) _loadData();
  }

  Future<void> _addBankInstallment() async {
    final saved = await showAddBankInstallmentDialog(context,
        date: _toDate, srId: widget.srId ?? '', srName: widget.srName);
    if (saved) _loadData();
  }

  Future<void> _editLoanTotal() async {
    if (await showEditLoanTotalDialog(context, _loan.total)) _loadData();
  }

  Future<void> _deleteBankInstallment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ব্যাংক জমা ডিলিট?'.tr),
        content: Text('এই ব্যাংক জমার এন্ট্রি মুছে ফেলা হবে।'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('না'.tr)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('ডিলিট'.tr)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _db.collection(BankLoan.collection).doc(id).delete();
        _loadData();
      } catch (e) {
        _showError('ডিলিট হয়নি'.tr, e);
      }
    }
  }

  Future<void> _deleteDeposit(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('জমা ডিলিট?'.tr), content: Text('এই জমা এন্ট্রি মুছে ফেলা হবে।'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('না'.tr)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('ডিলিট'.tr)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _db.collection('sr_deposits').doc(id).delete();
        _loadData();
      } catch (e) {
        _showError('ডিলিট হয়নি'.tr, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('দিনের হিসাব'.tr, style: TextStyle(fontSize: 17)),
            Text(
              '${DateFormat('dd MMM').format(_fromDate)} → ${DateFormat('dd MMM').format(_toDate)}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(160)),
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'day_add_deposit',
            onPressed: _addDeposit,
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: Text('জমা যোগ'.tr),
            backgroundColor: const Color(0xFF0891B2),
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'day_add_expense',
            onPressed: _addExpense,
            icon: const Icon(Icons.money_off_rounded),
            label: Text('খরচ যোগ'.tr),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'day_add_bank',
            onPressed: _addBankInstallment,
            icon: const Icon(Icons.account_balance_rounded),
            label: Text('ব্যাংক জমা'.tr),
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 140),
                children: [
                  _dateRangeFilter(scheme),
                  const SizedBox(height: 16),
                  if (_loadError.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      color: Colors.red.withAlpha(20),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${'হিসাব লোড হয়নি — নিচের সংখ্যাগুলো সঠিক নাও হতে পারে। রিফ্রেশ করুন।'.tr}\n$_loadError', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _simpleAccountCard(scheme),
                  const SizedBox(height: 16),
                  _summaryCards(scheme),
                  const SizedBox(height: 16),
                  if (_orders.isNotEmpty) ...[
                    _ordersDropdown(scheme),
                  ] else
                    Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কোনো অর্ডার নেই'.tr, style: TextStyle(color: Colors.grey)))),
                  const SizedBox(height: 20),
                  _expenseFilterSection(scheme),
                  const SizedBox(height: 8),
                  if (_filteredExpenses.isEmpty)
                    Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কোনো খরচ নেই'.tr, style: TextStyle(color: Colors.grey))))
                  else
                    ..._filteredExpenses.map((e) => _expenseCard(scheme, e)),
                  const SizedBox(height: 20),
                  _depositFilterSection(scheme),
                  const SizedBox(height: 8),
                  if (_filteredDeposits.isEmpty)
                    Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কোনো জমা নেই'.tr, style: TextStyle(color: Colors.grey))))
                  else
                    ..._filteredDeposits.map((d) => _depositCard(scheme, d)),
                  const SizedBox(height: 20),
                  _bankSection(scheme),
                ],
              ),
            )),
    );
  }

  Widget _dateRangeFilter(ColorScheme scheme) {
    final df = DateFormat('dd MMM yyyy');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF0891B2)),
                const SizedBox(width: 8),
                Text('তারিখ রেঞ্জ'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(df.format(_fromDate), style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _fromDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        setState(() {
                          _fromDate = DateTime(d.year, d.month, d.day);
                          if (_fromDate.isAfter(_toDate)) {
                            _toDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
                          }
                        });
                        _loadData();
                      }
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(df.format(_toDate), style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _toDate,
                        firstDate: _fromDate,
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        setState(() => _toDate = DateTime(d.year, d.month, d.day, 23, 59, 59));
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseFilterSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('খরচ'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            Text(
              '${'মোট'.tr}: ৳ ${_fmtInt.format(_filteredExpensesTotal.toInt())}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedExpenseCategory,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFDC2626)),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                dropdownColor: scheme.surface,
                items: _expenseFilterOptions.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(DomainLabels.filterOption(cat), style: TextStyle(color: cat == 'সব' ? Colors.grey.shade700 : const Color(0xFFDC2626))),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedExpenseCategory = v ?? 'সব'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _depositFilterSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('SR জমা'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            Text(
              '${'মোট'.tr}: ৳ ${_fmtInt.format(_filteredDepositsTotal.toInt())}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0891B2)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDepositMethod,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0891B2)),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0891B2)),
                dropdownColor: scheme.surface,
                items: _depositMethods.map((method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(DomainLabels.filterOption(method), style: TextStyle(color: method == 'সব' ? Colors.grey.shade700 : const Color(0xFF0891B2))),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedDepositMethod = v ?? 'সব'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCards(ColorScheme scheme) {
    final s = _sum;
    final totalDue = s.previousDue + s.netSales;
    final profitRate = s.netSales > 0 ? (s.grossProfit / s.netSales * 100) : 0.0;
    String tk(double v) => '৳ ${_fmtInt.format(v.round())}';
    if (_isSr) {
      // SR: their orders, collections, expenses and customer dues only.
      return Wrap(spacing: 10, runSpacing: 10, children: [
        _card('মোট অর্ডার'.tr, '${s.orderCount} ${'টি'.tr}', Icons.receipt_long_rounded, const Color(0xFF0891B2)),
        _card('অর্ডারের টাকা'.tr, tk(s.gross), Icons.shopping_cart_rounded, const Color(0xFF0891B2)),
        _card('জমা: হাতে'.tr, tk(s.srHand), Icons.person_pin_rounded, const Color(0xFF7C3AED)),
        _card('বিকাশ/অন্যান্য'.tr, tk(s.direct), Icons.account_balance_wallet_rounded, const Color(0xFFD97706)),
        _card('খরচ'.tr, tk(s.expenses), Icons.money_off_rounded, const Color(0xFFDC2626)),
        _card('SR জমা'.tr, tk(s.deposits), Icons.account_balance_rounded, const Color(0xFF0891B2)),
        _card('নতুন বাকি'.tr, tk(s.newDue), Icons.hourglass_bottom_rounded, s.newDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
      ]);
    }
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _card('মোট অর্ডার'.tr, '${s.orderCount} ${'টি'.tr}', Icons.receipt_long_rounded, const Color(0xFF0891B2)),
      _card('Gross বিক্রি'.tr, tk(s.gross), Icons.shopping_cart_rounded, const Color(0xFF0891B2)),
      _card('পূর্বের বাকি'.tr, tk(s.previousDue), Icons.history_rounded, const Color(0xFFD97706)),
      _card('মোট দেনা'.tr, tk(totalDue), Icons.account_balance_rounded, const Color(0xFF0891B2)),
      if (s.deduction > 0) _card('রিপ্লেস বাবদ'.tr, tk(s.deduction), Icons.swap_horiz_rounded, const Color(0xFF8B5CF6)),
      if (s.returnAmount > 0) _card('ফেরত বাদ'.tr, tk(s.returnAmount), Icons.keyboard_return_rounded, const Color(0xFF8B5CF6)),
      if (s.discount > 0) _card('ডিসকাউন্ট'.tr, tk(s.discount), Icons.discount_rounded, const Color(0xFFD97706)),
      _card('নেট বিক্রি'.tr, tk(s.netSales), Icons.trending_up_rounded, const Color(0xFF16A34A)),
      _card('জমা: SR হাতে'.tr, tk(s.srHand), Icons.person_pin_rounded, const Color(0xFF7C3AED)),
      _card('বিকাশ/অন্যান্য'.tr, tk(s.direct), Icons.account_balance_wallet_rounded, const Color(0xFFD97706)),
      _card('মোট জমা'.tr, tk(s.totalCollected), Icons.payments_rounded, const Color(0xFF16A34A)),
      if (s.adjustments > 0) _card('অ্যাডজাস্টমেন্ট'.tr, tk(s.adjustments), Icons.tune_rounded, const Color(0xFF8B5CF6)),
      _card('নতুন বাকি'.tr, tk(s.newDue), Icons.hourglass_bottom_rounded, s.newDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
      if (!_isSr) _card('ক্রয় মূল্য'.tr, tk(s.purchaseCost), Icons.shopping_bag_rounded, const Color(0xFFD97706)),
      // Value of returned / replaced goods that came back, so that
      // নেট বিক্রি − ক্রয় মূল্য + ফেরত মাল = মোট লাভ adds up on screen.
      if (!_isSr && s.recovered > 0) _card('ফেরত মাল'.tr, '+ ${tk(s.recovered)}', Icons.assignment_return_rounded, const Color(0xFF8B5CF6)),
      if (!_isSr) _card('মোট লাভ'.tr, tk(s.grossProfit), Icons.account_balance_wallet_rounded, const Color(0xFF0D9488)),
      _card('খরচ'.tr, tk(s.expenses), Icons.money_off_rounded, const Color(0xFFDC2626)),
      if (!_isSr) _card('নিট লাভ'.tr, tk(s.netProfit), Icons.savings_rounded, s.netProfit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
      if (!_isSr) _card('লাভের হার'.tr, '${profitRate.toStringAsFixed(2)}%', Icons.percent_rounded, const Color(0xFF10B981)),
    ]);
  }

  /// Summary tile; 2 per row on phones, 3 on tablets, 4 on laptops.
  Widget _card(String title, String value, IconData icon, Color color) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= Rsp.tabletMax ? 4 : (w >= Rsp.mobileMax ? 3 : 2);
    final content = w >= Rsp.mobileMax ? Rsp.contentMax(w).clamp(0.0, w) : w;
    return SizedBox(
      width: (content - 28 - 10 * (cols - 1)) / cols - 1,
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
    final totalCredited = _orders.fold<double>(0, (s, o) => s + ((o['_credited'] as num?)?.toDouble() ?? 0));
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: const Border(), collapsedShape: const Border(),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF0891B2)),
          const SizedBox(width: 8),
          Expanded(child: Text('${'অর্ডার সমূহ'.tr} (${_orders.length}${'টি'.tr})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_isSr ? '${'অর্ডার'.tr} ৳ ${_fmtInt.format(_sum.gross.round())}' : '${'বিক্রি'.tr} ৳ ${_fmtInt.format(_sum.netSales.round())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0891B2))),
            Text('${'জমা'.tr} ৳ ${_fmtInt.format(totalCredited.round())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
          ]),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: _orders.map((o) => _orderCard(scheme, o)).toList(),
      ),
    );
  }

  /// Opens the order's page to edit it (products, payments, replace, return)
  /// and recalculates the day afterwards.
  Future<void> _openOrder(Map<String, dynamic> o) async {
    final id = (o['_docId'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final snap = await _db.collection('orders').doc(id).get();
      if (!snap.exists) {
        _showError('অর্ডার পাওয়া যায়নি'.tr, id);
        return;
      }
      await Get.to(() => OrderDetailsView(order: OrderModel.fromFirestore(snap), srDocId: widget.srId));
      if (mounted) _loadData();
    } catch (e) {
      _showError('অর্ডার খোলা যায়নি'.tr, e);
    }
  }

  /// One money box of the order card (মোট / জমা / বাকি).
  Widget _moneyBox(String label, double amount, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: color.withAlpha(16), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            Text('৳ ${_fmtInt.format(amount.round())}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _orderCard(ColorScheme scheme, Map<String, dynamic> o) {
    final items = (o['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final payments = (o['payments'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final dt = orderDayTime(o) ?? DateTime.now();
    final memo = (o['localMemo'] ?? '').toString();
    final dispatchMemo = (o['memoNumber'] ?? '').toString();
    final isDueCollection = o['isDueCollection'] == true;
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final replaceItems = maps(o['replaceItems']);
    final returnItems = maps(o['returnItems']);
    final total = (o['totalAmount'] as num?)?.toDouble() ?? 0;
    final deduction = (o['deductionAmount'] as num?)?.toDouble() ?? 0;
    final returnAmt = (o['returnAmount'] as num?)?.toDouble() ?? 0;
    final discount = (o['discountAmount'] as num?)?.toDouble() ?? 0;
    final newDue = (o['_newDue'] as num?)?.toDouble() ?? 0;
    final credited = (o['_credited'] as num?)?.toDouble() ?? 0;
    final orderNet = (o['_orderNet'] as num?)?.toDouble() ?? 0;
    final purchaseCost = (o['_purchaseCost'] as num?)?.toDouble() ?? 0;
    final recovered = (o['_recovered'] as num?)?.toDouble() ?? 0;
    final profit = orderNet - purchaseCost + recovered;
    // With a replace credit or a return, a line's own margin is not what the
    // order earned (memo: item ৳40, but the replace gave it back), so only
    // the order's profit is shown.
    final showItemProfit = deduction <= 0 && returnAmt <= 0;

    // How the জমা was paid. A payment taken on another day is shown with its
    // date and is not part of this period's জমা.
    final payLines = <String>[];
    for (final p in payments) {
      final amt = (p['amount'] as num?)?.toDouble() ?? 0;
      if (amt <= 0) continue;
      var method = (p['method'] ?? '').toString();
      if (method.isEmpty) method = (o['paymentMethod'] ?? '').toString();
      final label = method.isEmpty ? 'জমা'.tr : DomainLabels.paymentMethod(method);
      final pd = p['date'] is Timestamp ? (p['date'] as Timestamp).toDate() : null;
      final otherDay = pd != null &&
          (pd.isBefore(DateTime(_fromDate.year, _fromDate.month, _fromDate.day)) ||
              pd.isAfter(DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59)));
      payLines.add('$label ৳${_fmtInt.format(amt.round())}${otherDay ? ' (${DateFormat('dd MMM').format(pd)})' : ''}');
    }
    if (payLines.isEmpty && credited > 0) {
      final method = (o['paymentMethod'] ?? '').toString();
      payLines.add('${method.isNotEmpty ? DomainLabels.paymentMethod(method) : 'জমা'.tr} ৳${_fmtInt.format(credited.round())}');
    }

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: scheme.surfaceContainerHighest.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Memo number first, so an order is easy to match with its paper memo.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: memo.isNotEmpty ? const Color(0xFF0891B2) : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                memo.isNotEmpty ? '${'মেমো'.tr} #$memo' : 'মেমো নেই'.tr,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: memo.isNotEmpty ? Colors.white : Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((o['shopName'] ?? 'Unknown'.tr).toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((o['shopPhone'] ?? '').toString().isNotEmpty)
                  Text((o['shopPhone'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            if (isDueCollection) _tag('বাকি আদায়'.tr, const Color(0xFF16A34A)),
            CallButton(phone: (o['shopPhone'] ?? '').toString()),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              tooltip: 'অর্ডার এডিট'.tr,
              color: const Color(0xFF0891B2),
              visualDensity: VisualDensity.compact,
              onPressed: () => _openOrder(o),
            ),
          ]),
          // Older orders stored only the amounts, not the replace list.
          if (replaceItems.isNotEmpty || deduction > 0 || returnItems.isNotEmpty || returnAmt > 0) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (replaceItems.isNotEmpty || deduction > 0) _tag('🔄 ${'রিপ্লেস আছে'.tr}${replaceItems.isNotEmpty ? ' (${replaceItems.length})' : ''}', const Color(0xFF7C3AED)),
              if (returnItems.isNotEmpty || returnAmt > 0) _tag('↩ ${'ফেরত আছে'.tr}${returnItems.isNotEmpty ? ' (${returnItems.length})' : ''}', const Color(0xFF8B5CF6)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            _moneyBox(isDueCollection ? 'অর্ডার'.tr : 'মোট'.tr, total, const Color(0xFF0891B2)),
            const SizedBox(width: 6),
            _moneyBox('জমা'.tr, credited, const Color(0xFF16A34A)),
            const SizedBox(width: 6),
            _moneyBox('বাকি'.tr, newDue, newDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF7C3AED)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                payLines.isEmpty ? 'কোনো জমা নেই'.tr : payLines.join(' • '),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: payLines.isEmpty ? Colors.grey : const Color(0xFF7C3AED)),
              ),
            ),
          ]),
          if (deduction > 0 || returnAmt > 0 || discount > 0) ...[
            const SizedBox(height: 4),
            Wrap(runSpacing: 4, children: [
              if (deduction > 0) _tag('রিপ্লেস বাদ: ৳${_fmtInt.format(deduction.toInt())}', const Color(0xFFDC2626)),
              if (returnAmt > 0) _tag('${'ফেরত বাদ'.tr}: ৳${_fmtInt.format(returnAmt.toInt())}', const Color(0xFF8B5CF6)),
              if (discount > 0) _tag('${'ডিসকাউন্ট'.tr}: ৳${_fmtInt.format(discount.toInt())}', const Color(0xFFD97706)),
            ]),
          ],
          if (replaceItems.isNotEmpty || returnItems.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(10), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final r in replaceItems)
                  Text(
                    '🔄 ${r['productName'] ?? ''} × ${r['quantity'] ?? 0} — ${_replaceLabel(r)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                  ),
                for (final r in returnItems)
                  Text(
                    '↩ ${r['productName'] ?? ''} × ${r['quantity'] ?? 0} — ${'ফেরত'.tr} ৳${_fmtInt.format(((r['totalPrice'] as num?) ?? 0).round())}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                  ),
              ]),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: scheme.outlineVariant.withAlpha(40)),
            const SizedBox(height: 6),
            // Every product the customer took, with its line total.
            ...items.map((item) {
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              final price = (item['pricePerUnit'] as num?)?.toDouble() ?? 0;
              final lineTotal = (item['totalPrice'] as num?)?.toDouble() ?? qty * price;
              // Per-product profit (admin only): sale price − purchase price.
              final inOrder = (item['purchasePrice'] as num?)?.toDouble() ?? 0;
              final cost = inOrder > 0 ? inOrder : (_productCostById[(item['productId'] ?? '').toString()] ?? 0).toDouble();
              final itemProfit = lineTotal - cost * qty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      (item['image'] ?? '').toString(),
                      width: 32, height: 32, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 32, height: 32, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_rounded, size: 16, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((item['productName'] ?? '').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Text('$qty × ৳${_fmtInt.format(price.round())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                        if (!_isSr && cost > 0) ...[
                          const SizedBox(width: 6),
                          Text('${'ক্রয়'.tr}: ৳${_fmtInt.format(cost.round())}', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                          if (showItemProfit) ...[
                            const SizedBox(width: 6),
                            Text('${'লাভ'.tr}: ৳${_fmtInt.format(itemProfit.round())}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: itemProfit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                          ],
                        ],
                      ]),
                    ]),
                  ),
                  Text('৳ ${_fmtInt.format(lineTotal.round())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0891B2))),
                ]),
              );
            }),
            Divider(height: 8, color: scheme.outlineVariant.withAlpha(40)),
            Row(children: [
              Expanded(child: Text('${items.length}${'টি প্রডাক্ট'.tr} • ${items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0))} ${'পিস'.tr}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150)))),
              Text('${'মোট'.tr} ৳ ${_fmtInt.format(total.round())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0891B2))),
            ]),
          ],
          if (!isDueCollection && !_isSr)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: profit >= 0 ? const Color(0xFF16A34A).withAlpha(10) : const Color(0xFFDC2626).withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${'নেট'.tr}: ৳${_fmtInt.format(orderNet.round())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                Text('ক্রয়: ৳${_fmtInt.format(purchaseCost.round())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                if (recovered > 0)
                  Text('${'ফেরত মাল'.tr}: +৳${_fmtInt.format(recovered.round())}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                Text('লাভ: ৳${_fmtInt.format(profit.round())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
              ]),
            ),
          const SizedBox(height: 4),
          Row(children: [
            if (dispatchMemo.isNotEmpty) _tag('${'চালান'.tr} $dispatchMemo', const Color(0xFFD97706)),
            Expanded(
              child: Text('${(o['_docId'] ?? '').toString().substring(0, (o['_docId'] ?? '').toString().length.clamp(0, 8))}... • ${_timeFmt.format(dt)}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
            ),
          ]),
        ]),
      ),
    );
  }

  String _replaceLabel(Map<String, dynamic> r) {
    switch ((r['resolutionType'] ?? '').toString()) {
      case 'money_deduct':
        return '${'টাকা কাটা'.tr} ৳${_fmtInt.format(((r['deductionAmount'] as num?) ?? 0).round())}';
      case 'replace_given':
        return 'রিপ্লেস দেওয়া হল'.tr;
      default:
        return 'রিপ্লেস নেওয়া হল'.tr;
    }
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
    final cat = DomainLabels.expenseCategory(expenseCategoryOf(e));
    final note = (e['note'] ?? '').toString();
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.isNotEmpty ? '$cat ৳ ${_fmtInt.format((e['amount'] as num?)?.toInt() ?? 0)}' : '৳ ${_fmtInt.format((e['amount'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
              ],
              if ((e['srName'] ?? '').toString().isNotEmpty)
                Text('SR: ${e['srName']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
              if (dt != null)
                Text(_timeFmt.format(dt), style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(100))),
            ]),
          ),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), color: Colors.red.shade300, visualDensity: VisualDensity.compact, onPressed: () => _deleteExpense(e['id'] as String)),
        ]),
      ),
    );
  }

  /// The day's simple account, e.g.
  ///   SR হাতে আদায় 12,000 − খরচ 500 − SR জমা 11,000 = SR-এর কাছে 500
  Widget _simpleAccountCard(ColorScheme scheme) {
    final s = _sum;
    final balance = s.srBalance;
    final settled = balance.round() == 0;
    final srOwes = balance > 0;
    final resultColor = settled ? const Color(0xFF16A34A) : (srOwes ? const Color(0xFF7C3AED) : const Color(0xFFDC2626));
    final cats = s.expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Widget line(String label, double amount, Color color, {String sign = '', bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: scheme.onSurface.withAlpha(200)))),
            Text('$sign৳ ${_fmtInt.format(amount.round())}', style: TextStyle(fontSize: bold ? 17 : 15, fontWeight: FontWeight.w800, color: color)),
          ]),
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF7C3AED).withAlpha(40))),
      color: const Color(0xFF7C3AED).withAlpha(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calculate_rounded, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_singleDay ? '${_isToday ? 'আজকের' : DateFormat('dd MMM').format(_fromDate)} ${'সহজ হিসাব'.tr}' : 'নির্বাচিত সময়ের সহজ হিসাব'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)))),
          ]),
          const SizedBox(height: 10),
          line('SR হাতে আদায়'.tr, s.srHand, const Color(0xFF7C3AED)),
          line('খরচ'.tr, s.expenses, const Color(0xFFDC2626), sign: '− '),
          if (cats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(cats.map((e) => '${DomainLabels.expenseCategory(e.key)} ৳${_fmtInt.format(e.value.round())}').join(' • '),
                  style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(140))),
            ),
          line('SR জমা'.tr, s.deposits, const Color(0xFF0891B2), sign: '− '),
          // Loan instalments paid out of an SR's cash also leave their hand.
          if (s.bankFromSr > 0)
            line('ব্যাংক জমা (SR থেকে)'.tr, s.bankFromSr, const Color(0xFF6366F1), sign: '− '),
          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: resultColor.withAlpha(18), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(settled ? Icons.check_circle_rounded : (srOwes ? Icons.person_pin_rounded : Icons.reply_rounded), color: resultColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settled ? 'হিসাব মিলে গেছে'.tr : (srOwes ? 'SR-এর কাছে আছে (SR দিবে)'.tr : 'SR পাবে'.tr),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: resultColor),
                ),
              ),
              Text('৳ ${_fmtInt.format(balance.abs().round())}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: resultColor)),
            ]),
          ),
          const SizedBox(height: 10),
          // Context: money that never passed through the SR's hand.
          Text(
            [
              if (!_isSr) '${'নেট বিক্রি'.tr} ৳${_fmtInt.format(s.netSales.round())}',
              if (s.direct > 0) '${'বিকাশ/ব্যাংকে সরাসরি'.tr} ৳${_fmtInt.format(s.direct.round())}',
              '${'বাজারে বাকি'.tr} ৳${_fmtInt.format(s.newDue.round())}',
            ].join(' • '),
            style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150)),
          ),
          if (s.laterCollections > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${'আদায়ের মধ্যে আগের দিনের অর্ডারের টাকা'.tr} ৳${_fmtInt.format(s.laterCollections.round())}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
            ),
          if (_laterPaymentsSkipped)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('৩০ দিনের বেশি সময়ে আগের অর্ডারের পরে নেওয়া টাকা এই হিসাবে ধরা হয়নি'.tr,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
            ),
        ]),
      ),
    );
  }

  /// Bank loan: what is still owed, and the instalments paid on this day.
  /// These amounts are repayment, so they stay out of profit and loss.
  Widget _bankSection(ColorScheme scheme) {
    const color = Color(0xFF6366F1);
    const savingsColor = Color(0xFF0891B2);
    final dayTotal = _bankInstallments.fold<num>(0, (s, b) => s + BankLoan.paidOf(b));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text('ব্যাংক জমা'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        Text('${'মোট'.tr}: ৳ ${_fmtInt.format(dayTotal.round())}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
      if (_sum.bankSavings > 0 || _sum.bankInstallment > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${'কিস্তি'.tr} ৳ ${_fmtInt.format(_sum.bankInstallment.round())}  ·  '
            '${'সঞ্চয়'.tr} ৳ ${_fmtInt.format(_sum.bankSavings.round())}',
            style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150)),
          ),
        ),
      const SizedBox(height: 8),
      // The outstanding balance is a business-wide figure, so the SR view
      // does not show it.
      if (!_isSr)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withAlpha(50)),
          ),
          color: color.withAlpha(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ব্যাংক এখনো পাবে'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('৳ ${_fmtInt.format(_loan.outstanding.round())}',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _loan.outstanding > 0 ? color : const Color(0xFF16A34A))),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  tooltip: 'মোট লোন সম্পাদন'.tr,
                  onPressed: _editLoanTotal,
                ),
              ]),
              const Divider(height: 14),
              Row(children: [
                Expanded(child: Text('${'মোট লোন'.tr}: ৳ ${_fmtInt.format(_loan.total.round())}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(170)))),
                Text('${'কিস্তি পরিশোধ'.tr}: ৳ ${_fmtInt.format(_loan.paid.round())}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ]),
              const SizedBox(height: 6),
              // Savings are the business's own money at the bank, never a
              // repayment, so they are shown apart from the loan.
              Row(children: [
                const Icon(Icons.savings_rounded, size: 14, color: savingsColor),
                const SizedBox(width: 6),
                Expanded(child: Text('ব্যাংকে জমা সঞ্চয়'.tr,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(170)))),
                Text('৳ ${_fmtInt.format(_loan.savings.round())}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: savingsColor)),
              ]),
              if (_loan.total <= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('মোট লোনের পরিমাণ দিলে বাকি কত তা দেখা যাবে'.tr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      if (_bankInstallments.isEmpty)
        Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('এই দিনে ব্যাংকে কোনো জমা নেই'.tr, style: const TextStyle(color: Colors.grey))))
      else
        ..._bankInstallments.map((b) => _bankInstallmentCard(scheme, b)),
    ]);
  }

  Widget _bankInstallmentCard(ColorScheme scheme, Map<String, dynamic> b) {
    const color = Color(0xFF6366F1);
    final ts = b['date'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final srName = (b['srName'] ?? '').toString();
    final method = (b['method'] ?? '').toString();
    final note = (b['note'] ?? '').toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('৳ ${_fmtInt.format(BankLoan.paidOf(b).round())}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'কিস্তি'.tr} ${_fmtInt.format(BankLoan.installmentOf(b).round())}'
                    '${BankLoan.savingsOf(b) > 0 ? ' + ${'সঞ্চয়'.tr} ${_fmtInt.format(BankLoan.savingsOf(b).round())}' : ''}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150)),
                  ),
                ),
              ]),
              Text(
                srName.isNotEmpty ? '${'উৎস'.tr}: $srName (${'SR হাতে'.tr})' : '${'উৎস'.tr}: $method',
                style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150)),
              ),
              if (note.isNotEmpty)
                Text(note, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
              if (dt != null)
                Text(_timeFmt.format(dt), style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(100))),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: Colors.red.shade300,
            onPressed: () => _deleteBankInstallment((b['id'] ?? '').toString()),
          ),
        ]),
      ),
    );
  }

  Widget _depositCard(ColorScheme scheme, Map<String, dynamic> d) {
    final ts = d['date'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final method = (d['method'] ?? '').toString();
    final note = (d['note'] ?? '').toString();
    final methodColor = method == 'ব্যাংক' ? const Color(0xFF0891B2) : (method == 'বিকাশ' ? const Color(0xFFD97706) : const Color(0xFF7C3AED));
    final methodIcon = method == 'ব্যাংক' ? Icons.account_balance_rounded :
        method == 'বিকাশ' ? Icons.phone_android_rounded : Icons.person_pin_rounded;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: methodColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(methodIcon, color: methodColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$method ৳ ${_fmtInt.format((d['amount'] as num?)?.toInt() ?? 0)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: methodColor)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
              ],
              if ((d['srName'] ?? '').toString().isNotEmpty)
                Text('SR: ${d['srName']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
              if (dt != null)
                Text(_timeFmt.format(dt), style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(100))),
            ]),
          ),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), color: Colors.red.shade300, visualDensity: VisualDensity.compact, onPressed: () => _deleteDeposit(d['id'] as String)),
        ]),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../localization/domain_labels.dart';
import '../../expense/expense_categories.dart';
import '../model/bank_loan.dart';

/// Add-expense and SR-deposit dialogs, shared by the admin daily page and
/// the SR panel. When [srId] is given the entry belongs to that SR and
/// counts in the SR's own daily account.

const _newCategoryKey = '__new__';
const _noSrKey = '__none__';

/// Active SRs, for the admin's "which SR" picker.
Future<List<({String id, String name})>> _loadSrs() async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('sr_staff')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => (id: d.id, name: (d.data()['name'] ?? '').toString()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  } catch (_) {
    return [];
  }
}

/// Dropdown that lets the admin attach an entry to an SR, so it also shows
/// in that SR's own daily account. Hidden when an SR adds it themselves.
Widget _srPicker(
  List<({String id, String name})> srs,
  String selected,
  ValueChanged<String> onChanged,
) {
  if (srs.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'কোন SR'.tr, border: const OutlineInputBorder()),
      items: [
        DropdownMenuItem(value: _noSrKey, child: Text('অফিস / কোনো SR নয়'.tr)),
        ...srs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
      ],
      onChanged: (v) => onChanged(v ?? _noSrKey),
    ),
  );
}
final _dateFmt = DateFormat('dd MMMM yyyy');

Widget _datePickerRow(BuildContext ctx, DateTime date, ValueChanged<DateTime> onPicked) {
  return InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () async {
      final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
      if (d != null) onPicked(DateTime(d.year, d.month, d.day));
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: 'তারিখ'.tr, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18)),
      child: Text(_dateFmt.format(date)),
    ),
  );
}

Widget _errorText(String error) => error.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
      );

void _showSaveError(String title, Object e) {
  Get.snackbar(title, '$e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
}

/// Width that fits a phone and stays readable on a laptop.
double _dialogWidth(BuildContext context) =>
    (MediaQuery.of(context).size.width - 48).clamp(260.0, 420.0);

/// A trip to the bank: the instalment that pays down the loan plus the
/// savings deposit kept alongside it (e.g. কিস্তি ৮০০ + সঞ্চয় ১০০). The money
/// can come out of an SR's cash (then it lowers what that SR holds) or
/// straight from bKash/bank/office. It is saved apart from expenses:
/// neither a repayment nor savings is a business cost, so it must never
/// reach the profit figures.
/// Returns true when a deposit was saved.
Future<bool> showAddBankInstallmentDialog(
  BuildContext context, {
  required DateTime date,
  String srId = '',
  String srName = '',
}) async {
  final srs = srId.isEmpty ? await _loadSrs() : const <({String id, String name})>[];
  if (!context.mounted) return false;
  const otherSources = ['বিকাশ', 'নগদ', 'রকেট', 'ব্যাংক', 'অফিস হাতে'];
  // An SR paying from their own panel: the source is themselves.
  var source = srId.isNotEmpty ? srId : (srs.isNotEmpty ? srs.first.id : otherSources.first);
  final amountCtrl = TextEditingController();
  final savingsCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime day = DateTime(date.year, date.month, date.day);
  String error = '';

  num parse(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.account_balance_rounded, color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('ব্যাংক জমা'.tr, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(labelText: 'কিস্তি'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: savingsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(labelText: 'সঞ্চয়'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${'মোট জমা'.tr}: ৳ ${(parse(amountCtrl) + parse(savingsCtrl)).round()}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(height: 8),
              if (srId.isEmpty)
                DropdownButtonFormField<String>(
                  initialValue: source,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'টাকার উৎস'.tr, border: const OutlineInputBorder()),
                  items: [
                    ...srs.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} ${'(SR হাতে)'.tr}'),
                        )),
                    ...otherSources.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (v) => setD(() => source = v ?? source),
                )
              else
                InputDecorator(
                  decoration: InputDecoration(labelText: 'টাকার উৎস'.tr, border: const OutlineInputBorder()),
                  child: Text('${srName.isNotEmpty ? srName : 'আমি'.tr} ${'(SR হাতে)'.tr}'),
                ),
              const SizedBox(height: 12),
              _datePickerRow(ctx, day, (d) => setD(() => day = d)),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'.tr, border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              Text('এই টাকা লাভ-ক্ষতির হিসাবে ধরা হবে না'.tr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              _errorText(error),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () {
              final inst = parse(amountCtrl);
              final sav = parse(savingsCtrl);
              if (inst < 0 || sav < 0 || inst + sav <= 0) {
                setD(() => error = 'কিস্তি বা সঞ্চয়ে সঠিক পরিমাণ লিখুন'.tr);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            child: Text('জমা দিন'.tr),
          ),
        ],
      ),
    ),
  );

  var saved = false;
  if (ok == true) {
    final installment = parse(amountCtrl);
    final savings = parse(savingsCtrl);
    final note = noteCtrl.text.trim();
    // An SR id as the source means the cash came out of that SR's hand.
    final fromSr = srId.isNotEmpty
        ? (id: srId, name: srName)
        : (srs.where((s) => s.id == source).isEmpty
            ? null
            : (id: source, name: srs.firstWhere((s) => s.id == source).name));
    try {
      await FirebaseFirestore.instance.collection(BankLoan.collection).add({
        // `amount` is the whole cash handed over, so the SR's balance and
        // the day's cash use one field; the parts are kept beside it.
        'amount': (installment + savings).toDouble(),
        'installment': installment.toDouble(),
        'savings': savings.toDouble(),
        'method': fromSr != null ? 'SR হাতে' : source,
        'note': note,
        'date': Timestamp.fromDate(day),
        if (fromSr != null) 'srId': fromSr.id,
        if (fromSr != null && fromSr.name.isNotEmpty) 'srName': fromSr.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      saved = true;
    } catch (e) {
      _showSaveError('ব্যাংক জমা সেভ হয়নি'.tr, e);
    }
  }
  amountCtrl.dispose();
  savingsCtrl.dispose();
  noteCtrl.dispose();
  return saved;
}

/// Lets the admin record how much the bank loan is in total, so the page can
/// show what is still owed.
Future<bool> showEditLoanTotalDialog(BuildContext context, num current) async {
  final ctrl = TextEditingController(text: current > 0 ? current.round().toString() : '');
  String error = '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('মোট ব্যাংক লোন'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'লোনের মোট পরিমাণ'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text('এখান থেকে জমা দেওয়া কিস্তি বাদ দিয়ে বাকি দেখানো হবে'.tr,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            _errorText(error),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () {
              if ((num.tryParse(ctrl.text.trim()) ?? -1) < 0) {
                setD(() => error = 'সঠিক সংখ্যা লিখুন'.tr);
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text('সেভ'.tr),
          ),
        ],
      ),
    ),
  );
  var saved = false;
  if (ok == true) {
    try {
      await BankLoan.saveTotalAmount(num.tryParse(ctrl.text.trim()) ?? 0);
      saved = true;
    } catch (e) {
      _showSaveError('সেভ হয়নি'.tr, e);
    }
  }
  ctrl.dispose();
  return saved;
}

/// Returns true when an expense was saved.
Future<bool> showAddExpenseDialog(
  BuildContext context, {
  required DateTime date,
  String srId = '',
  String srName = '',
}) async {
  final cats = await ExpenseCategories.load();
  // Admin can say whose expense it is; an SR's own entry is already theirs.
  final srs = srId.isEmpty ? await _loadSrs() : const <({String id, String name})>[];
  var pickedSr = _noSrKey;
  if (!context.mounted) return false;
  final noteCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final newCatCtrl = TextEditingController();
  String selected = cats.lastUsed;
  DateTime day = DateTime(date.year, date.month, date.day);
  String error = '';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('নতুন খরচ যোগ'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(labelText: 'টাকার পরিমাণ'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'খাত'.tr, border: const OutlineInputBorder()),
                items: [
                  ...cats.items.map((c) => DropdownMenuItem(value: c, child: Text(DomainLabels.expenseCategory(c)))),
                  DropdownMenuItem(
                    value: _newCategoryKey,
                    child: Row(children: [
                      const Icon(Icons.add_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text('নতুন খাত যোগ করুন'.tr, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
                onChanged: (v) => setD(() => selected = v ?? selected),
              ),
              if (selected == _newCategoryKey) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: newCatCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'নতুন খাতের নাম'.tr, hintText: 'যেমন: কুরিয়ার খরচ'.tr, helperText: 'পরের বার থেকে তালিকায় থাকবে'.tr, border: const OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 12),
              _datePickerRow(ctx, day, (d) => setD(() => day = d)),
              _srPicker(srs, pickedSr, (v) => setD(() => pickedSr = v)),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'.tr, border: const OutlineInputBorder())),
              _errorText(error),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () {
              if ((num.tryParse(amountCtrl.text.trim()) ?? 0) <= 0) {
                setD(() => error = 'সঠিক টাকার পরিমাণ লিখুন'.tr);
                return;
              }
              if (selected == _newCategoryKey && newCatCtrl.text.trim().isEmpty) {
                setD(() => error = 'নতুন খাতের নাম লিখুন'.tr);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            child: Text('যোগ করুন'.tr),
          ),
        ],
      ),
    ),
  );

  var saved = false;
  if (ok == true) {
    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    final category = selected == _newCategoryKey ? newCatCtrl.text.trim() : selected;
    try {
      final forSr = srId.isNotEmpty
          ? (id: srId, name: srName)
          : (pickedSr == _noSrKey
              ? null
              : (id: pickedSr, name: srs.firstWhere((e) => e.id == pickedSr).name));
      await FirebaseFirestore.instance.collection('expenses').add({
        'amount': amount.toDouble(),
        'category': category,
        'note': noteCtrl.text.trim(),
        'date': Timestamp.fromDate(day),
        if (forSr != null) 'srId': forSr.id,
        if (forSr != null && forSr.name.isNotEmpty) 'srName': forSr.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await ExpenseCategories.remember(category);
      saved = true;
    } catch (e) {
      _showSaveError('খরচ সেভ হয়নি'.tr, e);
    }
  }
  noteCtrl.dispose();
  amountCtrl.dispose();
  newCatCtrl.dispose();
  return saved;
}

/// Returns true when a deposit was saved.
Future<bool> showAddDepositDialog(
  BuildContext context, {
  required DateTime date,
  String srId = '',
  String srName = '',
  double? suggestedAmount,
}) async {
  final srs = srId.isEmpty ? await _loadSrs() : const <({String id, String name})>[];
  var pickedSr = _noSrKey;
  if (!context.mounted) return false;
  final noteCtrl = TextEditingController();
  final amountCtrl = TextEditingController(
      text: suggestedAmount != null && suggestedAmount > 0 ? suggestedAmount.round().toString() : '');
  String method = 'ব্যাংক';
  DateTime day = DateTime(date.year, date.month, date.day);
  String error = '';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0891B2), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(srId.isNotEmpty ? 'টাকা জমা দিন'.tr : 'SR জমা যোগ'.tr, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(labelText: 'টাকার পরিমাণ'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: InputDecoration(labelText: 'জমার মাধ্যম'.tr, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'ব্যাংক', child: Text(DomainLabels.paymentMethod('ব্যাংক'))),
                  DropdownMenuItem(value: 'বিকাশ', child: Text(DomainLabels.paymentMethod('বিকাশ'))),
                  DropdownMenuItem(value: 'হাতে', child: Text(DomainLabels.paymentMethod('হাতে'))),
                ],
                onChanged: (v) => setD(() => method = v ?? method),
              ),
              const SizedBox(height: 12),
              _datePickerRow(ctx, day, (d) => setD(() => day = d)),
              _srPicker(srs, pickedSr, (v) => setD(() => pickedSr = v)),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'বিবরণ'.tr, border: const OutlineInputBorder())),
              _errorText(error),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () {
              if ((num.tryParse(amountCtrl.text.trim()) ?? 0) <= 0) {
                setD(() => error = 'সঠিক টাকার পরিমাণ লিখুন'.tr);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0891B2), foregroundColor: Colors.white),
            child: Text('যোগ করুন'.tr),
          ),
        ],
      ),
    ),
  );

  var saved = false;
  if (ok == true) {
    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    final note = noteCtrl.text.trim();
    try {
      final forSr = srId.isNotEmpty
          ? (id: srId, name: srName)
          : (pickedSr == _noSrKey
              ? null
              : (id: pickedSr, name: srs.firstWhere((e) => e.id == pickedSr).name));
      await FirebaseFirestore.instance.collection('sr_deposits').add({
        'amount': amount.toDouble(),
        'method': method,
        'note': note.isNotEmpty ? note : 'SR জমা',
        'date': Timestamp.fromDate(day),
        if (forSr != null) 'srId': forSr.id,
        if (forSr != null && forSr.name.isNotEmpty) 'srName': forSr.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      saved = true;
    } catch (e) {
      _showSaveError('জমা সেভ হয়নি'.tr, e);
    }
  }
  noteCtrl.dispose();
  amountCtrl.dispose();
  return saved;
}

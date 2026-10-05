import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../../widgets/responsive.dart';
import '../../order/controller/order_controller.dart';

class SrDueView extends StatefulWidget {
  const SrDueView({super.key});

  @override
  State<SrDueView> createState() => _SrDueViewState();
}

class _SrDueViewState extends State<SrDueView> {
  static final _fmt = NumberFormat('#,##,##0');
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// false: customers with due only; true: every customer (to enter a due
  /// for someone who has none yet).
  bool _showAll = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SrPanelController>();
    final userCtrl = Get.find<UserController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('কাস্টমার বাকি'.tr,
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ'.tr,
            onPressed: () {
              userCtrl.fetchUsers(force: true);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ResponsiveWrapper(child: Obx(() {
        if (userCtrl.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // All users with dues
        final allWithDue = userCtrl.users
            .where((u) =>
                (_showAll || u.totalDue > 0) &&
                (_query.isEmpty ||
                    u.shopName.toLowerCase().contains(_query) ||
                    u.proprietorName.toLowerCase().contains(_query) ||
                    u.phone.contains(_query)))
            .toList();

        allWithDue.sort((a, b) => b.totalDue.compareTo(a.totalDue));

        final totalDue =
            userCtrl.users.fold<num>(0, (s, u) => s + u.totalDue);

        return Column(
          children: [
            // ── Summary header ──────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryTile(
                      'মোট বাকি'.tr,
                      '৳ ${_fmt.format(totalDue)}',
                      scheme.onPrimaryContainer),
                  _summaryTile(
                      'গ্রাহক সংখ্যা'.tr,
                      '${allWithDue.length} ${'জন'.tr}',
                      scheme.onPrimaryContainer),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'নাম / ফোন দিয়ে খুঁজুন…'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          })
                      : null,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(children: [
                ChoiceChip(
                  label: Text('বাকি আছে'.tr),
                  selected: !_showAll,
                  onSelected: (_) => setState(() => _showAll = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('সব কাস্টমার'.tr),
                  selected: _showAll,
                  onSelected: (_) => setState(() => _showAll = true),
                ),
              ]),
            ),

            // ── Customer list ────────────────────────────────
            Expanded(
              child: allWithDue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 56,
                              color: scheme.onSurface.withAlpha(60)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'কোনো বাকি নেই'.tr
                                : 'কোনো ফলাফল পাওয়া যায়নি'.tr,
                            style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurface.withAlpha(120)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: allWithDue.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = allWithDue[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          color: scheme.surfaceContainerHigh,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(Icons.store_rounded,
                                  color: scheme.onSecondaryContainer),
                            ),
                            title: Text(
                              u.shopName.isNotEmpty
                                  ? u.shopName
                                  : u.proprietorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${u.proprietorName}  •  ${u.phone}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '৳ ${_fmt.format(u.totalDue)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: scheme.primary),
                                ),
                                const SizedBox(height: 2),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (u.totalDue > 0)
                                    SizedBox(
                                      height: 28,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => _collect(u),
                                        icon: const Icon(Icons.payments_rounded,
                                            size: 14),
                                        label: Text('জমা নিন'.tr,
                                            style: const TextStyle(fontSize: 11)),
                                        style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            visualDensity: VisualDensity.compact),
                                      ),
                                    ),
                                  SizedBox(
                                    width: 32,
                                    height: 28,
                                    child: IconButton(
                                      onPressed: () => _editDue(u),
                                      icon: const Icon(Icons.edit_rounded, size: 16),
                                      tooltip: 'বাকি সম্পাদন'.tr,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      })),
    );
  }

  /// SR collects (part of) a customer's due. Saved as a due collection that
  /// lowers the customer's due and counts in the SR's own account.
  Future<void> _collect(UserModel u) async {
    final sr = Get.find<SrPanelController>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    const methods = ['SR হাতে', 'বিকাশ', 'নগদ', 'রকেট', 'ব্যাংক'];
    String method = methods.first;
    DateTime date = DateTime.now();
    String error = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
          return AlertDialog(
            title: Text('বাকি আদায়'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: (MediaQuery.of(ctx).size.width - 48).clamp(260.0, 420.0),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(u.shopName.isNotEmpty ? u.shopName : u.proprietorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${'বর্তমান বাকি'.tr}: ৳${_fmt.format(u.totalDue)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(
                      labelText: 'জমার পরিমাণ'.tr,
                      prefixText: '৳ ',
                      border: const OutlineInputBorder(),
                      suffixIcon: TextButton(
                        onPressed: () => setD(() => amountCtrl.text = u.totalDue.toString()),
                        child: Text('পুরো বাকি'.tr),
                      ),
                    ),
                  ),
                  if (amount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${'জমার পরে বাকি'.tr}: ৳${_fmt.format((u.totalDue - amount).clamp(0, 9999999).round())}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: InputDecoration(labelText: 'মাধ্যম'.tr, border: const OutlineInputBorder()),
                    items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setD(() => method = v ?? method),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) setD(() => date = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'তারিখ'.tr, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18)),
                      child: Text(DateFormat('dd MMMM yyyy').format(date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: noteCtrl, decoration: InputDecoration(labelText: 'মেমো নাম্বার (ঐচ্ছিক)'.tr, border: const OutlineInputBorder())),
                  if (error.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
              ElevatedButton(
                onPressed: () {
                  if (amount <= 0) {
                    setD(() => error = 'সঠিক টাকার পরিমাণ লিখুন'.tr);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                child: Text('জমা নিন'.tr),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
      try {
        final newDue = await Get.find<OrderController>().collectDue(
          customer: u,
          amount: amount,
          method: method,
          date: DateTime(date.year, date.month, date.day, DateTime.now().hour, DateTime.now().minute),
          note: noteCtrl.text.trim(),
          srDocId: sr.srDocId,
        );
        Get.snackbar('সফল'.tr, '৳${_fmt.format(amount.round())} ${'জমা নেওয়া হয়েছে'.tr} • ${'নতুন বাকি'.tr} ৳${_fmt.format(newDue)}',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
      } catch (e) {
        Get.snackbar('জমা সেভ হয়নি'.tr, '$e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  /// Direct due entry, like the admin's "বাকি পাওনা সম্পাদনা" — e.g. an old
  /// due from the paper book. The change and its reason are kept in the
  /// customer's due history.
  Future<void> _editDue(UserModel u) async {
    final sr = Get.find<SrPanelController>();
    final amountCtrl = TextEditingController(text: u.totalDue.toString());
    final noteCtrl = TextEditingController();
    String error = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final v = int.tryParse(amountCtrl.text.trim());
          return AlertDialog(
            title: Text('বাকি সম্পাদন'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: (MediaQuery.of(ctx).size.width - 48).clamp(260.0, 420.0),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(u.shopName.isNotEmpty ? u.shopName : u.proprietorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${'বর্তমান বাকি'.tr}: ৳${_fmt.format(u.totalDue)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(labelText: 'নতুন মোট বাকি'.tr, prefixText: '৳ ', border: const OutlineInputBorder()),
                  ),
                  if (v != null && v != u.totalDue)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        v > u.totalDue
                            ? '${'বাকি বাড়বে'.tr} ৳${_fmt.format(v - u.totalDue)}'
                            : '${'বাকি কমবে'.tr} ৳${_fmt.format(u.totalDue - v)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: v > u.totalDue ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: 'কারণ'.tr, hintText: 'যেমন: পুরনো খাতার বাকি'.tr, border: const OutlineInputBorder()),
                  ),
                  if (error.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল'.tr)),
              ElevatedButton(
                onPressed: () {
                  if (v == null || v < 0) {
                    setD(() => error = 'সঠিক সংখ্যা লিখুন'.tr);
                    return;
                  }
                  if (noteCtrl.text.trim().isEmpty) {
                    setD(() => error = 'কারণ লিখুন'.tr);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text('সংরক্ষণ'.tr),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final v = int.parse(amountCtrl.text.trim());
      try {
        await Get.find<UserController>().updateTotalDue(u.id, v,
            changedBy: sr.srDocId, changedByName: sr.srProfile.value?.name ?? 'SR', note: noteCtrl.text.trim());
        Get.snackbar('সফল'.tr, '${'নতুন বাকি'.tr} ৳${_fmt.format(v)}',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
      } catch (e) {
        Get.snackbar('সেভ হয়নি'.tr, '$e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

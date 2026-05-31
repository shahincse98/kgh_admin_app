import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/supplier_controller.dart';
import '../model/supplier_model.dart';
import '../../purchase/model/purchase_entry_model.dart';
import 'supplier_list_view.dart';

class SupplierDetailView extends StatefulWidget {
  const SupplierDetailView({super.key});

  @override
  State<SupplierDetailView> createState() => _SupplierDetailViewState();
}

class _SupplierDetailViewState extends State<SupplierDetailView> {
  static final _fmt = NumberFormat('#,##,##0');
  static final _dateFmt = NumberFormat.decimalPattern();

  late SupplierModel _supplier;
  List<PurchaseEntryModel> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _supplier = Get.arguments as SupplierModel;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctrl = Get.find<SupplierController>();
      final data = await ctrl.getSupplierPurchases(_supplier);
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEdit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierForm(
        existing: _supplier,
        onSaved: (updated) => setState(() => _supplier = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalAmount =
        _history.fold(0.0, (s, e) => s + e.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(_supplier.shopName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'সম্পাদনা',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  children: [
                    // ── Info card ──
                    _infoCard(cs),
                    const SizedBox(height: 12),
                    // ── Stats row ──
                    if (!_loading) _statsRow(cs, totalAmount),
                    const SizedBox(height: 14),
                    if (_history.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              'ক্রয় ইতিহাস',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: cs.error),
                      const SizedBox(height: 8),
                      const Text('লোড করতে সমস্যা হয়েছে'),
                      TextButton(
                          onPressed: _loadHistory,
                          child: const Text('আবার চেষ্টা করুন')),
                    ],
                  ),
                ),
              )
            else if (_history.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 56, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      Text('এই সাপ্লাইয়ারের কোনো ক্রয় নেই',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                      _buildGroupedHistory(context, cs)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _supplier.shopName.isNotEmpty
                          ? _supplier.shopName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supplier.shopName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      if (_supplier.ownerName.isNotEmpty)
                        Text(_supplier.ownerName,
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (_supplier.phone.isNotEmpty || _supplier.address.isNotEmpty)
              const SizedBox(height: 12),
            if (_supplier.phone.isNotEmpty)
              _infoRow(Icons.phone_outlined, _supplier.phone, cs),
            if (_supplier.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              _infoRow(
                  Icons.location_on_outlined, _supplier.address, cs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _statsRow(ColorScheme cs, double total) {
    return Row(
      children: [
        Expanded(
            child: _statCard(
          '${_history.length}',
          'মোট ক্রয়',
          Icons.receipt_long_rounded,
          cs.primary,
          cs,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
          '৳ ${_fmt.format(total.toInt())}',
          'মোট পরিমাণ',
          Icons.payments_rounded,
          const Color(0xFF16A34A),
          cs,
        )),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color,
      ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedHistory(
      BuildContext context, ColorScheme cs) {
    // Group by month
    final months = <String, List<PurchaseEntryModel>>{};
    for (final e in _history) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => []).add(e);
    }
    final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));

    return keys.map((monthKey) {
      final list = months[monthKey]!;
      final monthTotal = list.fold(0.0, (s, e) => s + e.totalAmount);
      final year = int.parse(monthKey.split('-')[0]);
      final month = int.parse(monthKey.split('-')[1]);
      final label = DateFormat('MMMM yyyy').format(DateTime(year, month));

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data:
              Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${list.length}টি entry',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade700)),
                ),
                const SizedBox(width: 8),
                Text(
                  '৳ ${_fmt.format(monthTotal.toInt())}',
                  style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
            children: [
              const Divider(height: 1),
              ...list.map((e) => _historyTile(e, cs)),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _historyTile(PurchaseEntryModel e, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: cs.outlineVariant.withAlpha(60))),
      ),
      child: Row(
        children: [
          // Date box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(e.date),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cs.primary),
                ),
                Text(
                  DateFormat('MMM').format(e.date).toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      color: cs.primary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${e.quantity}টি × ৳ ${_fmt.format(e.unitPrice.toInt())} = ৳ ${_fmt.format(e.totalAmount.toInt())}',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                if (e.note.isNotEmpty)
                  Text(e.note,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '৳ ${_fmt.format(e.totalAmount.toInt())}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Inline edit form for detail page ────────────────────────────────────────

class _SupplierForm extends StatefulWidget {
  final SupplierModel existing;
  final void Function(SupplierModel updated) onSaved;
  const _SupplierForm({required this.existing, required this.onSaved});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  late final _shopCtrl = TextEditingController(text: widget.existing.shopName);
  late final _ownerCtrl =
      TextEditingController(text: widget.existing.ownerName);
  late final _phoneCtrl =
      TextEditingController(text: widget.existing.phone);
  late final _addressCtrl =
      TextEditingController(text: widget.existing.address);
  bool _saving = false;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shopName = _shopCtrl.text.trim();
    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('দোকানের নাম আবশ্যিক')));
      return;
    }
    setState(() => _saving = true);
    try {
      final ctrl = Get.find<SupplierController>();
      await ctrl.updateSupplier(
        widget.existing,
        shopName: shopName,
        ownerName: _ownerCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      final updated = widget.existing.copyWith(
        shopName: shopName,
        ownerName: _ownerCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      widget.onSaved(updated);
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('আপডেট হয়েছে', '"$shopName" সফলভাবে আপডেট হয়েছে',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Icon(Icons.edit_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('সাপ্লাইয়ার সম্পাদনা',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _tf(_shopCtrl, 'দোকানের নাম *', Icons.storefront_rounded),
                  const SizedBox(height: 12),
                  _tf(_ownerCtrl, 'মালিকের নাম', Icons.person_rounded),
                  const SizedBox(height: 12),
                  _tf(_phoneCtrl, 'ফোন নম্বর', Icons.phone_rounded,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _tf(_addressCtrl, 'ঠিকানা', Icons.location_on_rounded,
                      maxLines: 2),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('আপডেট করুন'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

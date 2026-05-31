import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sales_plan_controller.dart';
import '../model/sales_plan_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';

class SalesPlanFormView extends StatefulWidget {
  const SalesPlanFormView({super.key});

  @override
  State<SalesPlanFormView> createState() => _SalesPlanFormViewState();
}

class _SalesPlanFormViewState extends State<SalesPlanFormView> {
  late final SalesPlanController _ctrl;
  late final ProductController _prodCtrl;

  // ── Form state ──────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  String _type = 'monthly'; // 'monthly' | 'weekly'

  // Monthly period
  DateTime _selectedMonth = DateTime(
      DateTime.now().year, DateTime.now().month);

  // Weekly period
  late DateTime _weekStart;

  // SR assignment
  String _assignedTo = 'all';
  String _srName = '';

  // Plan items
  final _items = <SalesPlanItem>[].obs;

  // Product search
  final _prodSearch = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  ProductModel? _selectedProduct;

  final _saving = false.obs;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<SalesPlanController>();
    _prodCtrl = Get.find<ProductController>();
    _weekStart = _mondayOf(DateTime.now());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _prodSearch.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime get _periodStart =>
      _type == 'monthly' ? _selectedMonth : _weekStart;

  DateTime get _periodEnd => _type == 'monthly'
      ? DateTime(_selectedMonth.year, _selectedMonth.month + 1)
      : _weekStart.add(const Duration(days: 7));

  String get _periodLabel {
    if (_type == 'weekly') {
      final end = _weekStart.add(const Duration(days: 6));
      return '${_d(_weekStart)} – ${_d(end)}';
    }
    const months = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _autoPeriodKey() {
    if (_type == 'monthly') {
      return '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    }
    // ISO week number for weekly
    final day = _weekStart;
    final jan4 = DateTime(day.year, 1, 4);
    final weekNo =
        ((day.difference(jan4).inDays + jan4.weekday) / 7).ceil();
    return '${day.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('নতুন পরিকল্পনা'),
        actions: [
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  icon: _saving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('সেভ'),
                  onPressed: _saving.value ? null : _save,
                ),
              )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('মৌলিক তথ্য', cs),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'পরিকল্পনার শিরোনাম',
                hintText: 'যেমন: মে মাসের লক্ষ্যমাত্রা',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Type selector
            _section('ধরন', cs),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'monthly',
                    label: Text('মাসিক'),
                    icon: Icon(Icons.calendar_month_rounded, size: 16)),
                ButtonSegment(
                    value: 'weekly',
                    label: Text('সাপ্তাহিক'),
                    icon: Icon(Icons.calendar_view_week_rounded,
                        size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (v) =>
                  setState(() => _type = v.first),
            ),
            const SizedBox(height: 12),

            // Period picker
            _section('সময়কাল', cs),
            if (_type == 'monthly') _monthPicker(cs),
            if (_type == 'weekly') _weekPicker(cs),

            // SR assignment
            _section('দায়িত্বপ্রাপ্ত SR', cs),
            _srPicker(cs),

            // Products
            _section('প্রডাক্ট ও লক্ষ্যমাত্রা', cs),
            _productAddRow(cs),
            const SizedBox(height: 10),
            Obx(() => _items.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('কোনো প্রডাক্ট যোগ করা হয়নি',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                : Column(
                    children: _items
                        .asMap()
                        .entries
                        .map((e) =>
                            _itemRow(e.key, e.value, cs))
                        .toList(),
                  )),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _section(String title, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 18, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cs.primary)),
    );
  }

  // ── Month picker ──────────────────────────────────────────────────────────

  Widget _monthPicker(ColorScheme cs) {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      return DateTime(now.year, now.month - i);
    });
    final monthNames = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: months.map((m) {
        final selected = _selectedMonth.year == m.year &&
            _selectedMonth.month == m.month;
        return ChoiceChip(
          label: Text(
              '${monthNames[m.month - 1]} ${m.year == now.year ? '' : m.year}'),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) =>
              setState(() => _selectedMonth = m),
        );
      }).toList(),
    );
  }

  // ── Week picker ───────────────────────────────────────────────────────────

  Widget _weekPicker(ColorScheme cs) {
    final end = _weekStart.add(const Duration(days: 6));
    final nowWeek = _mondayOf(DateTime.now());

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => setState(() =>
              _weekStart =
                  _weekStart.subtract(const Duration(days: 7))),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_d(_weekStart)} – ${_d(end)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded,
              color: _weekStart.isAtSameMomentAs(nowWeek) ||
                      _weekStart.isAfter(nowWeek)
                  ? Colors.grey
                  : null),
          onPressed:
              _weekStart.isAtSameMomentAs(nowWeek) ||
                      _weekStart.isAfter(nowWeek)
                  ? null
                  : () => setState(() =>
                      _weekStart =
                          _weekStart.add(const Duration(days: 7))),
        ),
      ],
    );
  }

  // ── SR picker ─────────────────────────────────────────────────────────────

  Widget _srPicker(ColorScheme cs) {
    return Obx(() {
      if (_ctrl.srLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return DropdownButtonFormField<String>(
        value: _assignedTo,
        decoration: InputDecoration(
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: const Icon(Icons.person_pin_circle_rounded),
        ),
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Text('সকল SR (সামগ্রিক)'),
          ),
          ..._ctrl.srList.map((sr) => DropdownMenuItem(
                value: sr.id,
                child: Text(sr.name),
              )),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _assignedTo = v;
            _srName = v == 'all'
                ? ''
                : _ctrl.srList
                    .firstWhere((s) => s.id == v,
                        orElse: () =>
                            const SrEntry(id: '', name: ''))
                    .name;
          });
        },
      );
    });
  }

  // ── Product add row ───────────────────────────────────────────────────────

  Widget _productAddRow(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product search autocomplete
        Autocomplete<ProductModel>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return [];
            final query =
                textEditingValue.text.toLowerCase();
            return _prodCtrl.products
                .where((p) =>
                    !p.isInternal &&
                    p.name.toLowerCase().contains(query))
                .take(8);
          },
          displayStringForOption: (p) => p.name,
          onSelected: (p) {
            setState(() => _selectedProduct = p);
            _prodSearch.text = p.name;
          },
          fieldViewBuilder:
              (context, textController, focusNode, onSubmitted) {
            _prodSearch.text = textController.text;
            return TextField(
              controller: textController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'প্রডাক্ট খুঁজুন...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    shrinkWrap: true,
                    children: options
                        .map((p) => ListTile(
                              dense: true,
                              title: Text(p.name),
                              subtitle: Text(p.productCategory,
                                  style: const TextStyle(
                                      fontSize: 11)),
                              onTap: () => onSelected(p),
                            ))
                        .toList(),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'লক্ষ্যমাত্রা (টি)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('প্রডাক্ট যোগ করুন'),
                onPressed: _addItem,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addItem() {
    final prod = _selectedProduct;
    if (prod == null) {
      Get.snackbar('ত্রুটি', 'প্রথমে একটি প্রডাক্ট সিলেক্ট করুন',
          backgroundColor: Colors.orange,
          colorText: Colors.white);
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) {
      Get.snackbar('ত্রুটি', 'লক্ষ্যমাত্রা ০-এর বেশি হতে হবে',
          backgroundColor: Colors.orange,
          colorText: Colors.white);
      return;
    }
    // Check for duplicate
    final existing = _items.indexWhere((i) => i.productId == prod.id);
    if (existing >= 0) {
      _items[existing] = _items[existing].copyWith(targetQty: qty);
    } else {
      _items.add(SalesPlanItem(
        productId: prod.id,
        productName: prod.name,
        targetQty: qty,
      ));
    }
    setState(() {
      _selectedProduct = null;
      _qtyCtrl.text = '1';
      _prodSearch.clear();
    });
  }

  Widget _itemRow(int index, SalesPlanItem item, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(item.productName,
                  style: const TextStyle(fontSize: 13))),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${item.targetQty} টি',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: cs.primary)),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: Colors.red.shade400, size: 18),
            onPressed: () => _items.removeAt(index),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_items.isEmpty) {
      Get.snackbar('ত্রুটি', 'অন্তত একটি প্রডাক্ট যোগ করুন',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : '${_assignedTo == 'all' ? 'সামগ্রিক' : _srName} – $_periodLabel';

    _saving.value = true;
    try {
      final plan = SalesPlanModel(
        id: '',
        title: title,
        type: _type,
        period: _autoPeriodKey(),
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        assignedTo: _assignedTo,
        srName: _srName,
        items: List.from(_items),
      );
      await _ctrl.savePlan(plan);
      Get.back();
      Get.snackbar('সফল', '"$title" পরিকল্পনা সেভ হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } finally {
      _saving.value = false;
    }
  }
}

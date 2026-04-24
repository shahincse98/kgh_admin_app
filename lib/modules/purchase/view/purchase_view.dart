import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/purchase_controller.dart';
import '../model/purchase_entry_model.dart';
import '../../product/model/product_model.dart';

class PurchaseView extends GetView<PurchaseController> {
  const PurchaseView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Purchase Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadEntries,
          ),
        ],
      ),
      body: Obx(() {
        return Column(
          children: [
            _monthNav(context, scheme),
            if (controller.loading.value)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadEntries,
                  child: controller.entries.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      size: 56, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text('এই মাসে কোনো purchase নেই',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 90),
                          children: [
                            _summaryCard(context, scheme),
                            const SizedBox(height: 14),
                            ..._groupedEntries(context, scheme),
                          ],
                        ),
                ),
              ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Purchase যোগ করুন'),
      ),
    );
  }

  Widget _monthNav(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: controller.prevMonth,
          ),
          Obx(() => Text(
                DateFormat('MMMM yyyy')
                    .format(controller.selectedMonth.value),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              )),
          Obx(() {
            final m = controller.selectedMonth.value;
            final now = DateTime.now();
            final isCurrent =
                m.year == now.year && m.month == now.month;
            return IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isCurrent ? Colors.grey : null),
              onPressed: isCurrent ? null : controller.nextMonth,
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.shopping_cart_rounded,
                color: Color(0xFF0891B2), size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('মাসের মোট কেনা',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '৳ ${_fmt.format(controller.monthTotal.toInt())}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0891B2),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${controller.entries.length} entry',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedEntries(
      BuildContext context, ColorScheme scheme) {
    final map = <String, List<PurchaseEntryModel>>{};
    for (final e in controller.entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final todayKey =
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return keys.map((key) {
      final list = map[key]!;
      final dayTotal =
          list.fold(0.0, (s, e) => s + e.totalAmount);
      final date = DateTime.parse(key);
      final isToday = key == todayKey;

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isToday,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF0891B2),
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF0891B2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              DateFormat('EEEE, dd MMMM').format(date),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${list.length}টি item',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '৳ ${_fmt.format(dayTotal.toInt())}',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1, thickness: 1),
              ...list.map((e) => _entryTile(e, scheme)),
              InkWell(
                onTap: () => _showAddSheet(context, initialDate: date),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withAlpha(12),
                    border: Border(top: BorderSide(
                        color: const Color(0xFF0891B2).withAlpha(40))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded,
                          color: Color(0xFF0891B2), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd MMM').format(date)} তারিখে আরও যোগ করুন',
                        style: const TextStyle(
                          color: Color(0xFF0891B2),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _entryTile(PurchaseEntryModel e, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: scheme.outlineVariant.withAlpha(60))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withAlpha(15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Color(0xFF0891B2), size: 18),
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
                  '${e.quantity}টি × ৳${_fmt.format(e.unitPrice.toInt())}'
                  '${e.supplier.isNotEmpty ? ' | ${e.supplier}' : ''}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
                if (e.note.isNotEmpty)
                  Text(e.note,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '৳ ${_fmt.format(e.totalAmount.toInt())}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(e),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PurchaseEntryModel e) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Purchase entry মুছবেন?'),
      content: Text(
          '${e.productName} — ${e.quantity}টি × ৳${e.unitPrice.toInt()}'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('না')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('হ্যাঁ',
                style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) await controller.deleteEntry(e);
  }

  void _showAddSheet(BuildContext context, {DateTime? initialDate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PurchaseAddSheet(
          controller: controller, initialDate: initialDate),
    );
  }
}

// ─── Cart Item model ─────────────────────────────────────────────────

class _CartItem {
  final ProductModel? product;
  final String productName;
  final String productId;
  int qty;
  double price;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _CartItem({
    this.product,
    required this.productName,
    required this.productId,
    required this.qty,
    required this.price,
  })  : qtyCtrl = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: price.toInt().toString());

  double get total => qty * price;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ─── Add Purchase Bottom Sheet ──────────────────────────────────────

class _PurchaseAddSheet extends StatefulWidget {
  final PurchaseController controller;
  final DateTime? initialDate;
  const _PurchaseAddSheet({required this.controller, this.initialDate});

  @override
  State<_PurchaseAddSheet> createState() => _PurchaseAddSheetState();
}

class _PurchaseAddSheetState extends State<_PurchaseAddSheet> {
  static final _fmt = NumberFormat('#,##,##0');

  final _searchCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  late DateTime _date;
  List<ProductModel> _suggestions = [];
  final List<_CartItem> _cart = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _supplierCtrl.dispose();
    for (final item in _cart) {
      item.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _suggestions = widget.controller.allProducts
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.productCode.toLowerCase().contains(q) ||
              p.brandName.toLowerCase().contains(q))
          .take(8)
          .toList();
    });
  }

  void _addToCart(ProductModel p) {
    // If already in cart, increment qty
    final existing =
        _cart.where((c) => c.productId == p.id).firstOrNull;
    if (existing != null) {
      setState(() {
        existing.qty += 1;
        existing.qtyCtrl.text = existing.qty.toString();
      });
    } else {
      setState(() {
        _cart.add(_CartItem(
          product: p,
          productName: p.name,
          productId: p.id,
          qty: 1,
          price: p.purchasePrice.toDouble(),
        ));
      });
    }
    _searchCtrl.clear();
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
  }

  void _removeFromCart(int idx) {
    setState(() {
      _cart[idx].dispose();
      _cart.removeAt(idx);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double get _grandTotal =>
      _cart.fold(0.0, (s, c) => s + c.total);

  Future<void> _save() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('কমপক্ষে একটি প্রডাক্ট যোগ করুন')));
      return;
    }
    // sync text fields into qty/price
    for (final item in _cart) {
      item.qty = int.tryParse(item.qtyCtrl.text) ?? item.qty;
      item.price =
          double.tryParse(item.priceCtrl.text) ?? item.price;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.addMultipleEntries(
        items: _cart
            .map((c) => {
                  'productName': c.productName,
                  'productId': c.productId,
                  'quantity': c.qty,
                  'unitPrice': c.price,
                  'note': '',
                })
            .toList(),
        supplier: _supplierCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.add_shopping_cart_rounded,
                    color: Color(0xFF0891B2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase যোগ করুন',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_cart.length}টি প্রডাক্ট | মোট: ৳ ${_fmt.format(_grandTotal.toInt())}',
                        style: TextStyle(
                            fontSize: 12,
                            color: _cart.isEmpty
                                ? Colors.grey
                                : const Color(0xFF0891B2),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date + Supplier row ──
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Color(0xFF0891B2),
                                    size: 18),
                                const SizedBox(width: 6),
                                Text(
                                    DateFormat('dd MMM, yyyy')
                                        .format(_date),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _supplierCtrl,
                          decoration: InputDecoration(
                            labelText: 'Supplier',
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Search ──
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'প্রডাক্ট সার্চ করুন...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _suggestions = []);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // ── Suggestions ──
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: scheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children:
                            _suggestions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final p = entry.value;
                          final inCart = _cart
                              .any((c) => c.productId == p.id);
                          return Column(
                            children: [
                              if (idx > 0)
                                Divider(
                                    height: 1,
                                    color: scheme.outlineVariant
                                        .withAlpha(80)),
                              InkWell(
                                onTap: () => _addToCart(p),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(p.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 13)),
                                            if (p.brandName
                                                    .isNotEmpty ||
                                                p.productCode
                                                    .isNotEmpty)
                                              Text(
                                                [
                                                  p.brandName,
                                                  p.productCode
                                                ]
                                                    .where((s) =>
                                                        s.isNotEmpty)
                                                    .join(' • '),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors
                                                        .grey.shade600),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '৳ ${_fmt.format(p.purchasePrice)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: Color(
                                                    0xFF0891B2)),
                                          ),
                                          Text(
                                            inCart
                                                ? '✓ কার্টে আছে'
                                                : 'স্টক: ${p.stock}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: inCart
                                                    ? Colors.green
                                                    : Colors
                                                        .grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // ── Cart ──
                  if (_cart.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: scheme.outlineVariant
                                .withAlpha(80)),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'উপরে সার্চ করে প্রডাক্ট যোগ করুন',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'যোগ করা প্রডাক্টসমূহ',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _cart.length,
                      (idx) => _cartItemTile(idx, scheme),
                    ),
                    const SizedBox(height: 8),
                    // Grand total bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'মোট (${_cart.length}টি)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                          Text(
                            '৳ ${_fmt.format(_grandTotal.toInt())}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Color(0xFF0891B2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── Save button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: (_saving || _cart.isEmpty)
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving
                          ? 'সেভ হচ্ছে...'
                          : 'সব Purchase সংরক্ষণ করুন (${_cart.length}টি)'),
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

  Widget _cartItemTile(int idx, ColorScheme scheme) {
    final item = _cart[idx];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Product name row
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0891B2),
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeFromCart(idx),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Qty + Price + Total
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                // Qty stepper
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (item.qty > 1) {
                            setState(() {
                              item.qty--;
                              item.qtyCtrl.text =
                                  item.qty.toString();
                            });
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.remove, size: 16),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: TextField(
                          controller: item.qtyCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) {
                              setState(() => item.qty = n);
                            }
                          },
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            item.qty++;
                            item.qtyCtrl.text =
                                item.qty.toString();
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Price field
                Expanded(
                  child: TextField(
                    controller: item.priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '৳ মূল্য',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      if (d != null) {
                        setState(() => item.price = d);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('মোট',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey)),
                    Text(
                      '৳${_fmt.format(item.total.toInt())}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0891B2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

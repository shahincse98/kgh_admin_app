import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import '../model/stock_in_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';

class StockInDetailView extends StatefulWidget {
  final StockInGroup group;

  const StockInDetailView({super.key, required this.group});

  @override
  State<StockInDetailView> createState() => _StockInDetailViewState();
}

class _StockInDetailViewState extends State<StockInDetailView> {
  final controller = Get.find<StockInController>();
  final pc = Get.find<ProductController>();
  static final _fmt = NumberFormat('#,##,##0');

  // Mutable copy of the group's entries so UI reflects add/edit/delete
  late List<StockInModel> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<StockInModel>.from(widget.group.entries);
  }

  void _refreshEntries() {
    final key =
        '${widget.group.date.toIso8601String().substring(0, 10)}|${widget.group.source}';
    final updated = controller.filteredGroups
        .firstWhereOrNull((g) =>
            '${g.date.toIso8601String().substring(0, 10)}|${g.source}' == key);
    if (updated != null) {
      setState(() {
        _entries = List<StockInModel>.from(updated.entries);
      });
    } else {
      // Group became empty — pop back
      if (mounted) Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMMM yyyy');
    final totalQty = _entries.fold(0, (s, e) => s + e.quantity);
    final totalValue = _entries.fold<num>(0, (s, e) => s + e.totalPrice);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dateFmt.format(widget.group.date),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (widget.group.source.isNotEmpty)
              Text(widget.group.source,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140))),
          ],
        ),
      ),
      body: ResponsiveWrapper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
          children: [
            _summaryCard(scheme, _entries.length, totalQty, totalValue),
            const SizedBox(height: 14),
            _sectionTitle('প্রডাক্টসমূহ', scheme),
            const SizedBox(height: 8),
            ..._entries.map((e) => _entryCard(e, scheme)),
            const SizedBox(height: 12),
            _addProductButton(scheme),
            if (widget.group.note.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('নোট', scheme),
              const SizedBox(height: 6),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(widget.group.note,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(180))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(ColorScheme scheme, int count, int qty, num value) {
    return Card(
      elevation: 0,
      color: const Color(0xFF16A34A).withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFF16A34A).withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: Color(0xFF16A34A), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count টি প্রডাক্ট | $qty pcs',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF166534))),
                  const SizedBox(height: 4),
                  Text(
                    '৳ ${_fmt.format(value.toInt())}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme scheme) {
    return Text(title,
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurface.withAlpha(200)));
  }

  Widget _entryCard(StockInModel entry, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (entry.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(entry.image,
                    width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, e1, e2) => Container(
                        width: 48, height: 48,
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_rounded, size: 20))),
              )
            else
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withAlpha(15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF16A34A), size: 22),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withAlpha(20),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('+${entry.quantity}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A))),
                      ),
                      const SizedBox(width: 8),
                      if (entry.unitPrice > 0)
                        Text('৳${_fmt.format(entry.unitPrice.toInt())}/pc',
                            style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (entry.totalPrice > 0)
                  Text('৳${_fmt.format(entry.totalPrice.toInt())}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'এডিট',
                      onPressed: () => _showEditDialog(entry, scheme),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: Colors.red.shade400,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'ডিলিট',
                      onPressed: () => _confirmDelete(entry),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addProductButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAddProductSheet(scheme),
        icon: const Icon(Icons.add_rounded),
        label: const Text('প্রডাক্ট যোগ করুন'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: const Color(0xFF16A34A).withAlpha(60)),
        ),
      ),
    );
  }

  // ── Edit dialog ────────────────────────────────────────────────

  Future<void> _showEditDialog(StockInModel entry, ColorScheme scheme) async {
    final qtyCtrl = TextEditingController(text: entry.quantity.toString());
    final priceCtrl = TextEditingController(text: entry.unitPrice.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: entry.note);

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.productName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Text('পরিমাণ:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ),
              const SizedBox(width: 16),
              const Text('দাম:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      prefixText: '৳',
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'মোট: ৳${_fmt.format(((num.tryParse(priceCtrl.text) ?? 0) * (int.tryParse(qtyCtrl.text) ?? 0)).toInt())}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('নোট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) {
                Get.snackbar('ত্রুটি', 'পরিমাণ ১+ হতে হবে',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              Get.back(result: true);
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('সেভ'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.updateEntry(
        id: entry.id,
        productId: entry.productId,
        productName: entry.productName,
        quantity: int.tryParse(qtyCtrl.text.trim()) ?? entry.quantity,
        unitPrice: num.tryParse(priceCtrl.text.trim()) ?? entry.unitPrice,
        source: entry.source,
        note: noteCtrl.text.trim(),
        date: entry.date,
      );
      if (mounted) {
        Get.snackbar('আপডেট হয়েছে', 'স্টক এডজাস্ট হয়েছে',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF2563EB), colorText: Colors.white);
        _refreshEntries();
      }
    }
    qtyCtrl.dispose();
    priceCtrl.dispose();
    noteCtrl.dispose();
  }

  // ── Delete confirm ─────────────────────────────────────────────

  Future<void> _confirmDelete(StockInModel entry) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('ডিলিট করবেন?'),
        content: Text('"${entry.productName}" +${entry.quantity} ডিলিট করবেন?\nসতর্কতা: স্টক কমে যাবে।'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('না')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('হ্যাঁ, ডিলিট'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteEntry(entry.id);
      if (mounted) {
        Get.snackbar('ডিলিট হয়েছে', 'স্টক এডজাস্ট হয়েছে',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
        _refreshEntries();
      }
    }
  }

  // ── Add product sheet ──────────────────────────────────────────

  void _showAddProductSheet(ColorScheme scheme) {
    String query = '';
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displayed = query.isEmpty
              ? all
              : all.where((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.brandName.toLowerCase().contains(query) ||
                  p.productCode.toLowerCase().contains(query)).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      const Icon(Icons.add_circle_rounded, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('প্রডাক্ট যোগ করুন',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                      Text(DateFormat('dd MMM').format(widget.group.date),
                          style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(120))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'প্রডাক্ট খুঁজুন…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: displayed.isEmpty
                        ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি',
                            style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = displayed[i];
                              final already = _entries.any((e) => e.productId == p.id);
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.images.isNotEmpty
                                      ? Image.network(p.images.first,
                                          width: 42, height: 42, fit: BoxFit.cover,
                                          errorBuilder: (_, e1, e2) => Container(
                                              width: 42, height: 42,
                                              color: scheme.surfaceContainerHighest,
                                              child: const Icon(Icons.image_not_supported_rounded, size: 16)))
                                      : Container(
                                          width: 42, height: 42,
                                          color: scheme.surfaceContainerHighest,
                                          child: const Icon(Icons.image_not_supported_rounded, size: 16)),
                                ),
                                title: Text(p.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                subtitle: Text('স্টক: ${p.stock} | ৳${_fmt.format(p.purchasePrice)}',
                                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                                trailing: already
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                    : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                                onTap: () async {
                                  Get.back();
                                  if (already) {
                                    final existing = _entries.firstWhere(
                                        (e) => e.productId == p.id);
                                    await controller.updateEntry(
                                      id: existing.id,
                                      productId: existing.productId,
                                      productName: existing.productName,
                                      quantity: existing.quantity + 1,
                                      unitPrice: existing.unitPrice,
                                      source: existing.source,
                                      note: existing.note,
                                      date: existing.date,
                                    );
                                  } else {
                                    await controller.addStockIn(
                                      productId: p.id,
                                      productName: p.name,
                                      quantity: 1,
                                      unitPrice: p.purchasePrice,
                                      image: p.images.isNotEmpty ? p.images.first : '',
                                      source: widget.group.source,
                                      note: widget.group.note,
                                      date: widget.group.date,
                                    );
                                  }
                                  if (mounted) {
                                    _refreshEntries();
                                    Get.snackbar('যোগ হয়েছে', '${p.name} যোগ হয়েছে',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: const Color(0xFF16A34A),
                                        colorText: Colors.white);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

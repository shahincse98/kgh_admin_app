import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/manual_stock_out_controller.dart';
import '../model/manual_stock_out_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';

class ManualStockOutHistoryView extends GetView<ManualStockOutController> {
  const ManualStockOutHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##,##0');
    final dateFmt = DateFormat('dd MMM yyyy, h:mm a');

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ম্যানুয়াল স্টক আউট ইতিহাস', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${controller.filteredEntries.length} টি এন্ট্রি',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
              ],
            )),
      ),
      body: ResponsiveWrapper(child: Column(
        children: [
          _searchBar(scheme),
          Expanded(child: Obx(() {
            final list = controller.filteredEntries;
            if (list.isEmpty && controller.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 56, color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('কোনো এন্ট্রি পাওয়া যায়নি', style: TextStyle(color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => controller.fetchEntries(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _entryCard(list[i], scheme, fmt, dateFmt),
              ),
            );
          })),
        ],
      )),
    );
  }

  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: InputDecoration(
          hintText: 'কাস্টমার নাম, মেমো বা প্রডাক্ট নাম দিয়ে খুঁজুন…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _entryCard(ManualStockOutModel entry, ColorScheme scheme, NumberFormat fmt, DateFormat dateFmt) {
    final totalQty = entry.items.fold(0, (s, i) => s + i.quantity);
    final stockOutDate = DateFormat('dd MMM yyyy').format(entry.stockOutDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: const Color(0xFFD97706)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.customerName.isEmpty ? 'Unknown' : entry.customerName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              if (entry.customerPhone.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(entry.customerPhone,
                                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
                              ],
                              if (entry.customerAddress.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(entry.customerAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Manual Out',
                                  style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700, fontSize: 11)),
                            ),
                            const SizedBox(height: 4),
                            Text(stockOutDate, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(Icons.tag_rounded, '#${entry.id}', scheme),
                        if (entry.memoNumber.isNotEmpty)
                          _chip(Icons.receipt_long_rounded, 'মেমো: ${entry.memoNumber}', scheme, labelColor: const Color(0xFFD97706)),
                        _chip(Icons.shopping_bag_outlined, '$totalQty pcs', scheme),
                        _chip(Icons.access_time_rounded, dateFmt.format(entry.createdAt), scheme),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...entry.items.map((item) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              if (item.image.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(item.image, width: 20, height: 20, fit: BoxFit.cover,
                                      errorBuilder: (_, e1, e2) => const Icon(Icons.circle, size: 5, color: Color(0xFFD97706))),
                                )
                              else
                                const Icon(Icons.circle, size: 5, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('${item.productName} × ${item.quantity}',
                                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
                              ),
                            ],
                          ),
                        )),
                    // Replace actions
                    if (entry.replaceActions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      Text('রিপ্লেস:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface.withAlpha(140))),
                      ...entry.replaceActions.map((ra) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  ra.resolutionType == 'product_replace' ? Icons.inventory_2_rounded : Icons.money_off_rounded,
                                  size: 14,
                                  color: const Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ra.resolutionType == 'product_replace'
                                        ? '${ra.defectiveProductName} → ${ra.replaceProductName} ×${ra.replaceQty}'
                                        : '${ra.defectiveProductName} → ৳${ra.deductionAmount} বাদ',
                                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(160)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showEditDialog(entry, scheme),
                          icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('এডিট', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(entry),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          label: const Text('ডিলিট', style: TextStyle(fontSize: 11, color: Colors.red)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme scheme, {Color? labelColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: labelColor != null ? labelColor.withAlpha(18) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: labelColor != null ? Border.all(color: labelColor.withAlpha(80), width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: labelColor ?? scheme.onSurface.withAlpha(160)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: labelColor != null ? FontWeight.w700 : FontWeight.normal,
              color: labelColor ?? scheme.onSurface.withAlpha(180))),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ManualStockOutModel entry) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('ডিলিট করবেন?'),
        content: Text('"${entry.customerName}" এর স্টক আউট এন্ট্রি ডিলিট করবেন?\n\nসতর্কতা: স্টক পুনরায় যোগ হবে (restore)।'),
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
      Get.snackbar('ডিলিট হয়েছে', 'এন্ট্রি ডিলিট এবং স্টক রিস্টোর হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
    }
  }

  // ─── Edit Dialog ──────────────────────────────────────────────

  Future<void> _showEditDialog(ManualStockOutModel entry, ColorScheme scheme) async {
    final pc = Get.find<ProductController>();
    final fmt = NumberFormat('#,##,##0');

    final editItems = <_EditItem>[
      for (final item in entry.items)
        _EditItem(id: item.productId, name: item.productName, quantity: item.quantity, stock: 0),
    ].obs;

    final dateCtrl = TextEditingController(text: DateFormat('dd MMM yyyy').format(entry.stockOutDate));
    final customerCtrl = TextEditingController(text: entry.customerName);
    final phoneCtrl = TextEditingController(text: entry.customerPhone);
    final memoCtrl = TextEditingController(text: entry.memoNumber);
    DateTime editDate = entry.stockOutDate;

    int totalQty() => editItems.fold(0, (s, i) => s + i.quantity);

    final confirmed = await Get.dialog<bool>(
      barrierDismissible: false,
      AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('স্টক আউট এডিট', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDlgState) => SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  const Text('তারিখ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: editDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setDlgState(() {
                          editDate = picked;
                          dateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
                        });
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Customer name
                  const Text('কাস্টমার নাম *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: customerCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_rounded, size: 20),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Phone + Memo
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ফোন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                                filled: true,
                                fillColor: scheme.surfaceContainerHigh,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('মেমো', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: memoCtrl,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                                filled: true,
                                fillColor: scheme.surfaceContainerHigh,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Products
                  Row(
                    children: [
                      const Text('প্রডাক্ট', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const Spacer(),
                      Obx(() => Text('${editItems.length} টি | ${totalQty()} pcs',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Obx(() => Column(
                        children: editItems.asMap().entries.map((e) {
                          final idx = e.key;
                          final item = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh.withAlpha(120),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                _qtyBtn(Icons.remove_rounded, () {
                                  if (item.quantity > 1) {
                                    item.quantity--;
                                    editItems.refresh();
                                  } else {
                                    editItems.removeAt(idx);
                                  }
                                }),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                ),
                                _qtyBtn(Icons.add_rounded, () {
                                  item.quantity++;
                                  editItems.refresh();
                                }),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  color: Colors.red.shade400,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => editItems.removeAt(idx),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )),
                  const SizedBox(height: 6),
                  // Add product button
                  OutlinedButton.icon(
                    onPressed: () {
                      String query = '';
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx2) => StatefulBuilder(
                          builder: (ctx2, setSheetState) {
                            final all = List<ProductModel>.from(pc.products);
                            final displayed = query.isEmpty
                                ? all
                                : all.where((p) => p.name.toLowerCase().contains(query) || p.brandName.toLowerCase().contains(query)).toList();
                            displayed.sort((a, b) => a.name.compareTo(b.name));

                            return DraggableScrollableSheet(
                              initialChildSize: 0.7,
                              builder: (_, scrollCtrl) => Container(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: TextField(
                                        onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()),
                                        decoration: InputDecoration(
                                          hintText: 'প্রডাক্ট খুঁজুন…',
                                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                          filled: true,
                                          fillColor: scheme.surfaceContainerHigh,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ListView.separated(
                                        controller: scrollCtrl,
                                        itemCount: displayed.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (_, i) {
                                          final p = displayed[i];
                                          final already = editItems.any((e) => e.id == p.id);
                                          return ListTile(
                                            dense: true,
                                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                            subtitle: Text('স্টক: ${p.stock} | ৳${fmt.format(p.wholesalePrice)}', style: const TextStyle(fontSize: 11)),
                                            trailing: already
                                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                                : Icon(Icons.add_circle_outline_rounded, color: const Color(0xFFD97706).withAlpha(200), size: 20),
                                            onTap: already
                                                ? () {
                                                    final existing = editItems.firstWhere((e) => e.id == p.id);
                                                    existing.quantity++;
                                                    editItems.refresh();
                                                    Get.back();
                                                  }
                                                : () {
                                                    editItems.add(_EditItem(id: p.id, name: p.name, quantity: 1, stock: p.stock));
                                                    Get.back();
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
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('প্রডাক্ট যোগ'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () {
              if (customerCtrl.text.trim().isEmpty) {
                Get.snackbar('ত্রুটি', 'কাস্টমার নাম দিতে হবে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              if (editItems.isEmpty) {
                Get.snackbar('ত্রুটি', 'প্রডাক্ট থাকতে হবে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              Get.back(result: true);
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('সেভ'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.updateEntry(
        id: entry.id,
        stockOutDate: editDate,
        customerName: customerCtrl.text.trim(),
        customerPhone: phoneCtrl.text.trim(),
        memoNumber: memoCtrl.text.trim(),
        newItems: editItems.map((e) => {'productId': e.id, 'productName': e.name, 'quantity': e.quantity}).toList(),
      );
      Get.snackbar('আপডেট হয়েছে', 'স্টক আউট এন্ট্রি আপডেট এবং স্টক এডজাস্ট হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF2563EB), colorText: Colors.white);
      dateCtrl.dispose();
      customerCtrl.dispose();
      phoneCtrl.dispose();
      memoCtrl.dispose();
    }
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD97706).withAlpha(80)),
          color: const Color(0xFFD97706).withAlpha(14),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFFD97706)),
      ),
    );
  }
}

class _EditItem {
  final String id;
  final String name;
  int quantity;
  final int stock;

  _EditItem({required this.id, required this.name, required this.quantity, this.stock = 0});
}

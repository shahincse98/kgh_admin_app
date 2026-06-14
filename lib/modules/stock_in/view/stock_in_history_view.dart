import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import '../model/stock_in_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';

class StockInHistoryView extends GetView<StockInController> {
  const StockInHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy, h:mm a');

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('স্টক ইন ইতিহাস', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${controller.filteredGroups.length} টি গ্রুপ',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
              ],
            )),
      ),
      body: ResponsiveWrapper(child: Column(
        children: [
          _searchBar(scheme),
          Expanded(child: Obx(() {
            final groups = controller.filteredGroups;
            if (groups.isEmpty && controller.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (groups.isEmpty) {
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
                itemCount: groups.length,
                itemBuilder: (_, i) => _groupCard(groups[i], scheme, dateFmt),
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
          hintText: 'প্রডাক্ট নাম, সোর্স বা নোট দিয়ে খুঁজুন…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _groupCard(StockInGroup group, ColorScheme scheme, DateFormat dateFmt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: const Color(0xFF16A34A)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Date + Source
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy').format(group.date),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (group.source.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0891B2).withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0891B2)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(group.source,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0891B2)),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text('${group.entries.length} টি | ${group.totalQty} pcs',
                            style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(120))),
                      ],
                    ),
                    if (group.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(group.note, style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140))),
                    ],
                    // Divider
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    // Product list
                    ...group.entries.map((entry) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: scheme.outlineVariant.withAlpha(40)))),
                          child: Row(
                            children: [
                              if (entry.image.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(entry.image, width: 28, height: 28, fit: BoxFit.cover,
                                      errorBuilder: (_, e1, e2) => const Icon(Icons.circle, size: 5, color: Color(0xFF16A34A))),
                                )
                              else
                                const Icon(Icons.circle, size: 5, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontSize: 13, color: scheme.onSurface),
                                    children: [
                                      TextSpan(text: entry.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      TextSpan(text: '  +${entry.quantity}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => _showEditDialog(entry, scheme),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.edit_rounded, size: 16, color: const Color(0xFF2563EB).withAlpha(200)),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => _confirmDelete(entry),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    // Add product to this group
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showAddToGroupDialog(group, scheme),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: const Text('প্রডাক্ট যোগ', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
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
  }

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
      Get.snackbar('ডিলিট হয়েছে', 'স্টক এডজাস্ট হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
    }
  }

  Future<void> _showEditDialog(StockInModel entry, ColorScheme scheme) async {
    final qtyCtrl = TextEditingController(text: entry.quantity.toString());
    final noteCtrl = TextEditingController(text: entry.note);

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Row(children: [
          const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                    filled: true, fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const Text('নোট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                filled: true, fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) {
                Get.snackbar('ত্রুটি', 'পরিমাণ ১+ হতে হবে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
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
        productId: entry.productId,
        productName: entry.productName,
        quantity: int.tryParse(qtyCtrl.text.trim()) ?? entry.quantity,
        source: entry.source,
        note: noteCtrl.text.trim(),
        date: entry.date,
      );
      Get.snackbar('আপডেট হয়েছে', 'স্টক এডজাস্ট হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF2563EB), colorText: Colors.white);
    }
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  void _showAddToGroupDialog(StockInGroup group, ColorScheme scheme) {
    final pc = Get.find<ProductController>();
    final fmt = NumberFormat('#,##,##0');
    String query = '';
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: Get.context!,
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
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(child: Text('প্রডাক্ট যোগ করুন',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                      Text('${group.source} | ${DateFormat('dd MMM').format(group.date)}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(120))),
                    ]),
                  ),
                  const SizedBox(height: 10),
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
                    child: displayed.isEmpty
                        ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = displayed[i];
                              final alreadyInGroup = group.entries.any((e) => e.productId == p.id);
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.images.isNotEmpty
                                      ? Image.network(p.images.first, width: 42, height: 42, fit: BoxFit.cover,
                                          errorBuilder: (_, e1, e2) => Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16)))
                                      : Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16)),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                subtitle: Text('স্টক: ${p.stock} | ৳${fmt.format(p.wholesalePrice)}',
                                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                                trailing: alreadyInGroup
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                    : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                                onTap: () async {
                                  Get.back();
                                  if (alreadyInGroup) {
                                    // Increment existing
                                    final existing = group.entries.firstWhere((e) => e.productId == p.id);
                                    await controller.updateEntry(
                                      id: existing.id,
                                      productId: existing.productId,
                                      productName: existing.productName,
                                      quantity: existing.quantity + 1,
                                      source: existing.source,
                                      note: existing.note,
                                      date: existing.date,
                                    );
                                  } else {
                                    // Add new to this group
                                    await controller.addStockIn(
                                      productId: p.id,
                                      productName: p.name,
                                      quantity: 1,
                                      source: group.source,
                                      note: group.note,
                                      date: group.date,
                                    );
                                  }
                                  Get.snackbar('যোগ হয়েছে', '${p.name} গ্রুপে যোগ হয়েছে',
                                      snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
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

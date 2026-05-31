import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_snapshot_controller.dart';
import '../controller/product_controller.dart';
import '../model/stock_snapshot_model.dart';
import '../../replace/controller/admin_replace_controller.dart';

class StockSnapshotView extends StatefulWidget {
  const StockSnapshotView({super.key});

  @override
  State<StockSnapshotView> createState() => _StockSnapshotViewState();
}

class _StockSnapshotViewState extends State<StockSnapshotView> {
  late final StockSnapshotController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(StockSnapshotController());
  }

  @override
  void dispose() {
    Get.delete<StockSnapshotController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক স্ন্যাপশট ইতিহাস'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: ctrl.fetchSnapshots,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('নতুন স্ন্যাপশট'),
        onPressed: () => _saveDialog(context),
      ),
      body: Obx(() {
        if (ctrl.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.snapshots.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_outlined,
                    size: 64, color: cs.onSurface.withAlpha(60)),
                const SizedBox(height: 12),
                Text(
                  'কোনো স্ন্যাপশট নেই\nনিচের বাটনে চেপে স্টক সেভ করুন',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withAlpha(100)),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: ctrl.snapshots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _SnapshotCard(
            snapshot: ctrl.snapshots[i],
            ctrl: ctrl,
            scheme: cs,
          ),
        );
      }),
    );
  }

  void _saveDialog(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    AdminReplaceController? arc;
    try { arc = Get.find<AdminReplaceController>(); } catch (_) {}

    final now = DateTime.now();
    final weekStart =
        now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final defaultLabel =
        'সপ্তাহ ${DateFormat('dd MMM').format(weekStart)}–${DateFormat('dd MMM yyyy').format(weekEnd)}';
    final labelCtrl = TextEditingController(text: defaultLabel);

    // Build replace map from at-shop entries
    final atShopEntries = arc?.atShop ?? [];
    final replaceMap = <String, int>{};
    for (final e in atShopEntries) {
      replaceMap[e.productName] =
          (replaceMap[e.productName] ?? 0) + e.quantity;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('স্ন্যাপশট সেভ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'লেবেল / নাম',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final total = productCtrl.products.length;
              return Text(
                'মোট $total টি পণ্য + ${replaceMap.length}টি রিপ্লেস পণ্যের বর্তমান স্টক সেভ হবে',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('বাতিল')),
          Obx(() => ElevatedButton(
                onPressed: ctrl.saving.value
                    ? null
                    : () async {
                        if (labelCtrl.text.trim().isEmpty) return;
                        await ctrl.saveSnapshot(
                            labelCtrl.text,
                            productCtrl.products.toList(),
                            replaceMap: replaceMap.isEmpty ? null : replaceMap);
                        Get.back();
                        Get.snackbar(
                          'সেভ হয়েছে!',
                          '"${labelCtrl.text.trim()}" স্ন্যাপশট সংরক্ষিত',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                child: ctrl.saving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('সেভ করুন'),
              )),
        ],
      ),
    );
  }
}

// ─── Snapshot Card ────────────────────────────────────────────────────────────

class _SnapshotCard extends StatelessWidget {
  final StockSnapshotModel snapshot;
  final StockSnapshotController ctrl;
  final ColorScheme scheme;

  const _SnapshotCard({
    required this.snapshot,
    required this.ctrl,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final regular = snapshot.items.where((i) => !i.isInternal).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final internal = snapshot.items.where((i) => i.isInternal).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final replaceItems = snapshot.replaceItems.toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));

    // Build copy text (same format as AppBar copy button)
    final buf = StringBuffer();
    if (regular.isNotEmpty) {
      buf.writeln('── সকল পণ্য ──');
      for (final p in regular) buf.writeln('${p.name}: ${p.stock}');
    }
    if (internal.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('── ইন্টার্নাল পণ্য ──');
      for (final p in internal) buf.writeln('${p.name}: ${p.stock}');
    }
    if (replaceItems.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('── রিপ্লেস পণ্য ──');
      for (final r in replaceItems) buf.writeln('${r.productName}: ${r.quantity}');
    }
    final copyText = buf.toString().trimRight();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded,
                color: scheme.onPrimaryContainer, size: 22),
          ),
          title: Text(
            snapshot.label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          subtitle: Text(
            '${DateFormat('dd MMM yyyy, hh:mm a').format(snapshot.savedAt)}  •  ${snapshot.totalProducts} পণ্য',
            style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurface.withAlpha(120)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip('${snapshot.regularTotal}', Colors.blue.shade700),
              if (snapshot.internalTotal > 0) ...[
                const SizedBox(width: 4),
                _chip('ই: ${snapshot.internalTotal}',
                    Colors.purple.shade700),
              ],
              if (snapshot.replaceTotal > 0) ...[
                const SizedBox(width: 4),
                _chip('রি: ${snapshot.replaceTotal}',
                    Colors.orange.shade700),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.copy_rounded,
                    color: scheme.primary, size: 20),
                tooltip: 'কপি করুন',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copyText));
                  Get.snackbar(
                    'কপি হয়েছে!',
                    '"${snapshot.label}" স্ন্যাপশট কপি হয়েছে',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                tooltip: 'ডিলেট',
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 1),
            if (regular.isNotEmpty) ...[
              _sectionBar('সকল পণ্য (${regular.length})', scheme),
              ...regular.map((item) => _itemRow(item, scheme)),
            ],
            if (internal.isNotEmpty) ...[
              _sectionBar('ইন্টার্নাল পণ্য (${internal.length})',
                  scheme),
              ...internal.map((item) => _itemRow(item, scheme)),
            ],
            if (replaceItems.isNotEmpty) ...[
              _sectionBar('রিপ্লেস পণ্য (${replaceItems.length})', scheme),
              ...replaceItems.map((r) => _replaceItemRow(r, scheme)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _sectionBar(String title, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: scheme.surfaceContainerHighest.withAlpha(70),
      child: Text(
        '── $title ──',
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withAlpha(130)),
      ),
    );
  }

  Widget _itemRow(StockSnapshotItem item, ColorScheme scheme) {
    final color = item.stock < 0
        ? Colors.red
        : item.stock == 0
            ? Colors.orange
            : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: scheme.outlineVariant.withAlpha(40))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (item.category.isNotEmpty)
                  Text(item.category,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withAlpha(120))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Text(
              '${item.stock}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replaceItemRow(StockSnapshotReplaceItem item, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: scheme.outlineVariant.withAlpha(40))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(item.productName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withAlpha(70)),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('স্ন্যাপশট ডিলেট করবেন?'),
        content: Text('"${snapshot.label}" স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await ctrl.deleteSnapshot(snapshot.id);
            },
            child: const Text('ডিলেট',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

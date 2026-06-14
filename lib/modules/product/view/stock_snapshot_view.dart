import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_snapshot_controller.dart';
import '../controller/product_controller.dart';
import '../model/stock_snapshot_model.dart';
import '../../replace/controller/admin_replace_controller.dart';

enum _SnapshotAction { restore, copy, delete }

class StockSnapshotView extends StatefulWidget {
  const StockSnapshotView({super.key});

  @override
  State<StockSnapshotView> createState() => _StockSnapshotViewState();
}

class _StockSnapshotViewState extends State<StockSnapshotView> {
  late final StockSnapshotController ctrl;
  late final AdminReplaceController arc;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(StockSnapshotController());
    arc = Get.isRegistered<AdminReplaceController>()
        ? Get.find<AdminReplaceController>()
        : Get.put(AdminReplaceController());
  }

  @override
  void dispose() {
    Get.delete<StockSnapshotController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 600;

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
      floatingActionButton: isCompact
          ? FloatingActionButton(
              tooltip: 'নতুন স্ন্যাপশট',
              onPressed: () => _saveDialog(context),
              child: const Icon(Icons.camera_alt_rounded),
            )
          : FloatingActionButton.extended(
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: ctrl.snapshots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SnapshotCard(
                snapshot: ctrl.snapshots[i],
                ctrl: ctrl,
                scheme: cs,
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _saveDialog(BuildContext context) async {
    final productCtrl = Get.find<ProductController>();
    await arc.fetchEntries(force: true);

    final now = DateTime.now();
    final weekStart =
        now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final defaultLabel =
        'সপ্তাহ ${DateFormat('dd MMM').format(weekStart)}–${DateFormat('dd MMM yyyy').format(weekEnd)}';
    final labelCtrl = TextEditingController(text: defaultLabel);

    // Build replace map from at-shop entries (only positive qty)
    final atShopEntries = arc.atShop;
    final replaceMap = <String, int>{};
    for (final e in atShopEntries) {
      if (e.quantity >= 1) {
        replaceMap[e.productName] =
            (replaceMap[e.productName] ?? 0) + e.quantity;
      }
    }

    final snapshotProducts = productCtrl.products
        .where((p) => p.stock >= 1)
        .toList();

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
            Text(
              'মোট ${snapshotProducts.length} টি পণ্য + ${replaceMap.length}টি রিপ্লেস পণ্যের বর্তমান স্টক সেভ হবে',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (labelCtrl.text.trim().isEmpty) return;
              await ctrl.saveSnapshot(labelCtrl.text, snapshotProducts,
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
            child: const Text('সেভ করুন'),
          ),
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
    final isCompact = MediaQuery.sizeOf(context).width < 680;
    final regular = snapshot.items
        .where((i) => !i.isInternal && i.stock >= 1)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final internal = snapshot.items
        .where((i) => i.isInternal && i.stock >= 1)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final replaceItems = snapshot.replaceItems
        .where((i) => i.quantity >= 1)
        .toList()
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('dd MMM yyyy, hh:mm a').format(snapshot.savedAt)}  •  ${snapshot.totalProducts} পণ্য',
                style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withAlpha(120)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _chip('${snapshot.regularTotal}', Colors.blue.shade700),
                  if (snapshot.internalTotal > 0)
                    _chip('ই: ${snapshot.internalTotal}',
                        Colors.purple.shade700),
                  if (snapshot.replaceTotal > 0)
                    _chip('রি: ${snapshot.replaceTotal}',
                        Colors.orange.shade700),
                ],
              ),
            ],
          ),
          trailing: isCompact
              ? PopupMenuButton<_SnapshotAction>(
                  tooltip: 'Actions',
                  onSelected: (value) {
                    if (value == _SnapshotAction.restore) {
                      _confirmRestore(context);
                    } else if (value == _SnapshotAction.copy) {
                      Clipboard.setData(ClipboardData(text: copyText));
                      Get.snackbar(
                        'কপি হয়েছে!',
                        '"${snapshot.label}" স্ন্যাপশট কপি হয়েছে',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    } else {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _SnapshotAction.restore,
                      child: Text('এই স্ন্যাপশটে ফিরুন'),
                    ),
                    PopupMenuItem(
                      value: _SnapshotAction.copy,
                      child: Text('কপি করুন'),
                    ),
                    PopupMenuItem(
                      value: _SnapshotAction.delete,
                      child: Text('ডিলেট'),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.restore_rounded,
                          color: Colors.indigo.shade400, size: 20),
                      tooltip: 'এই স্ন্যাপশটে ফিরুন',
                      onPressed: () => _confirmRestore(context),
                    ),
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

  void _confirmRestore(BuildContext context) {
    Get.dialog(
          AlertDialog(
        title: const Text('এই স্ন্যাপশটে ফিরবেন?'),
        content: Text(
          '"${snapshot.label}" অনুযায়ী সকল পণ্য, ইন্টার্নাল পণ্য এবং দোকানের রিপ্লেস স্টক রিস্টোর হবে। বর্তমান স্টক অবস্থা ওভাররাইট হবে।\n\nস্ন্যাপশটের পরবর্তী সকল ম্যানুয়াল স্টক আউট ও ডিসপ্যাচ রিভার্ট হবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('বাতিল'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              Get.back();
              final result = await ctrl.restoreFromSnapshot(snapshot);
              final msg = StringBuffer();
              msg.writeln('পণ্য ${result['products']}টি রিস্টোর হয়েছে');
              if (((result['replace'] as int?) ?? 0) > 0) {
                msg.writeln('রিপ্লেস ${result['replace']}টি রিস্টোর হয়েছে');
              }
              if (((result['deletedStockOuts'] as int?) ?? 0) > 0) {
                msg.writeln('ম্যানুয়াল স্টক আউট ${result['deletedStockOuts']}টি রিমুভ হয়েছে');
              }
              if (((result['revertedOrders'] as int?) ?? 0) > 0) {
                msg.writeln('ডিসপ্যাচ ${result['revertedOrders']}টি রিভার্ট হয়েছে');
              }
              if (((result['deletedStockIns'] as int?) ?? 0) > 0) {
                msg.writeln('স্টক ইন ${result['deletedStockIns']}টি রিমুভ হয়েছে');
              }
              Get.snackbar(
                'রিস্টোর সম্পন্ন',
                msg.toString(),
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.indigo,
                colorText: Colors.white,
                duration: const Duration(seconds: 4),
              );
            },
            icon: const Icon(Icons.restore_rounded, color: Colors.white),
            label: const Text('রিস্টোর করুন',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

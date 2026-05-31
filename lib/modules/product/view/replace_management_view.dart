import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/replace_controller.dart';
import '../controller/product_controller.dart';
import '../model/global_replace_model.dart';
import '../model/delivered_replace_model.dart';
import '../model/product_model.dart';
import '../../../widgets/responsive.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';

class ReplaceManagementView extends StatefulWidget {
  const ReplaceManagementView({super.key});

  @override
  State<ReplaceManagementView> createState() => _ReplaceManagementViewState();
}

class _ReplaceManagementViewState extends State<ReplaceManagementView>
    with SingleTickerProviderStateMixin {
  final rc = Get.find<ReplaceController>();
  late TabController _tabs;
  final _pendingSearch = ''.obs;
  final _deliveredSearch = ''.obs;
  final _currentTab = 0.obs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => _currentTab.value = _tabs.index);
    rc.fetchAllReplaces();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _fmtDateKey(String key) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(key));
    } catch (_) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Replace Management'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 18), text: 'পেন্ডিং'),
            Tab(icon: Icon(Icons.check_circle_outline_rounded, size: 18), text: 'ডেলিভারি হয়েছে'),
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'প্রডাক্ট'),
          ],
        ),
        actions: [
          Obx(() => rc.loading.value
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'রিফ্রেশ',
                  onPressed: rc.fetchAllReplaces,
                )),
        ],
      ),
      body: ResponsiveWrapper(child: TabBarView(
        controller: _tabs,
        children: [
          _pendingTab(),
          _deliveredTab(),
          _productSummaryTab(),
        ],
      )),
      floatingActionButton: Obx(() => _currentTab.value == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddReplaceDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Replace যোগ করুন'),
            )
          : const SizedBox.shrink()),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1 — PENDING REPLACES
  // ══════════════════════════════════════════════
  Widget _pendingTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => _pendingSearch.value = v.toLowerCase(),
            decoration: const InputDecoration(
              hintText: 'শপ বা প্রডাক্ট নাম দিয়ে খুঁজুন...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Obx(() {
          final total = rc.allReplaces.fold<int>(0, (s, r) => s + r.quantity);
          if (rc.allReplaces.isEmpty) return const SizedBox.shrink();
          return _summaryStrip(
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
            label: 'পেন্ডিং ${rc.allReplaces.length}টি এন্ট্রি',
            right: 'পরিমাণ: ${total}টি',
          );
        }),
        Expanded(
          child: Obx(() {
            if (rc.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final q = _pendingSearch.value;
            final filtered = rc.allReplaces.where((r) {
              if (q.isEmpty) return true;
              return r.shopName.toLowerCase().contains(q) ||
                  r.productName.toLowerCase().contains(q);
            }).toList();

            if (filtered.isEmpty) {
              return _emptyState(Icons.pending_actions_rounded, 'কোনো পেন্ডিং replace নেই');
            }

            final grouped = _groupByDate(filtered);
            final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: _countPendingItems(sortedKeys, grouped),
              itemBuilder: (context, index) =>
                  _buildPendingItem(index, sortedKeys, grouped),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPendingItem(
    int index,
    List<String> keys,
    Map<String, List<GlobalReplaceModel>> grouped,
  ) {
    int cursor = 0;
    for (final key in keys) {
      if (index == cursor) return _dateHeader(key, grouped[key]!.length);
      cursor++;
      final items = grouped[key]!;
      if (index < cursor + items.length) return _pendingCard(items[index - cursor]);
      cursor += items.length;
    }
    return const SizedBox.shrink();
  }

  Widget _pendingCard(GlobalReplaceModel r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.storefront_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(r.shopName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  if (r.note.isNotEmpty)
                    Text(r.note, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${r.quantity}টি',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.orange, fontSize: 14)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Deliver button
                    GestureDetector(
                      onTap: () => _showDeliverDialog(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withAlpha(80)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green),
                            SizedBox(width: 3),
                            Text('দিয়েছি',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Cancel button
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'বাতিল করুন',
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      onPressed: () => _confirmCancel(r),
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

  // ══════════════════════════════════════════════
  // TAB 2 — DELIVERED HISTORY
  // ══════════════════════════════════════════════
  Widget _deliveredTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => _deliveredSearch.value = v.toLowerCase(),
            decoration: const InputDecoration(
              hintText: 'শপ বা প্রডাক্ট নাম দিয়ে খুঁজুন...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Obx(() {
          final total = rc.allDelivered.fold<int>(0, (s, r) => s + r.quantity);
          if (rc.allDelivered.isEmpty) return const SizedBox.shrink();
          return _summaryStrip(
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            label: 'মোট ${rc.allDelivered.length}টি ডেলিভারি',
            right: 'পরিমাণ: ${total}টি',
          );
        }),
        Expanded(
          child: Obx(() {
            if (rc.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final q = _deliveredSearch.value;
            final filtered = rc.allDelivered.where((r) {
              if (q.isEmpty) return true;
              return r.shopName.toLowerCase().contains(q) ||
                  r.productName.toLowerCase().contains(q);
            }).toList();

            if (filtered.isEmpty) {
              return _emptyState(Icons.check_circle_outline_rounded, 'কোনো ডেলিভারি রেকর্ড নেই');
            }

            final grouped = <String, List<DeliveredReplaceModel>>{};
            for (final r in filtered) {
              final key =
                  '${r.deliveredAt.year.toString().padLeft(4, '0')}-${r.deliveredAt.month.toString().padLeft(2, '0')}-${r.deliveredAt.day.toString().padLeft(2, '0')}';
              grouped.putIfAbsent(key, () => []).add(r);
            }
            final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: _countDeliveredItems(sortedKeys, grouped),
              itemBuilder: (context, index) =>
                  _buildDeliveredItem(index, sortedKeys, grouped),
            );
          }),
        ),
      ],
    );
  }

  int _countDeliveredItems(
    List<String> keys,
    Map<String, List<DeliveredReplaceModel>> grouped,
  ) =>
      keys.fold(0, (sum, k) => sum + 1 + (grouped[k]?.length ?? 0));

  Widget _buildDeliveredItem(
    int index,
    List<String> keys,
    Map<String, List<DeliveredReplaceModel>> grouped,
  ) {
    int cursor = 0;
    for (final key in keys) {
      if (index == cursor) return _dateHeader(key, grouped[key]!.length);
      cursor++;
      final items = grouped[key]!;
      if (index < cursor + items.length) return _deliveredCard(items[index - cursor]);
      cursor += items.length;
    }
    return const SizedBox.shrink();
  }

  Widget _deliveredCard(DeliveredReplaceModel r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.storefront_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(r.shopName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('দেওয়া হয়েছে: ${_fmt(r.deliveredAt)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  if (r.note.isNotEmpty)
                    Text(r.note, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${r.quantity}টি',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.green, fontSize: 14)),
                ),
                const SizedBox(height: 6),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'রেকর্ড মুছুন',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                  onPressed: () => _confirmDeleteDelivered(r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 3 — PRODUCT SUMMARY
  // ══════════════════════════════════════════════
  Widget _productSummaryTab() {
    return Obx(() {
      if (rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = rc.replaceProductSummary;
      if (list.isEmpty) {
        return _emptyState(Icons.inventory_2_rounded, 'কোনো replace product নেই');
      }
      final totalPcs = list.fold<int>(0, (s, p) => s + p.replaceCount);

      return Column(
        children: [
          _summaryStrip(
            icon: Icons.inventory_2_rounded,
            color: Colors.deepOrange,
            label: '${list.length} প্রডাক্ট',
            right: 'পেন্ডিং: ${totalPcs}টি',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _productSummaryCard(list[i]),
            ),
          ),
        ],
      );
    });
  }

  Widget _productSummaryCard(ProductModel p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: p.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(p.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_rounded, color: Colors.deepOrange)),
                    )
                  : const Icon(Icons.inventory_2_rounded, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(p.productCategory,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${p.replaceCount}টি পেন্ডিং',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.deepOrange, fontSize: 14)),
                ),
                const SizedBox(height: 2),
                Text('স্টক: ${p.stock}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════

  void _showAddReplaceDialog() {
    Get.dialog(
      _AddReplaceDialog(rc: rc),
      barrierDismissible: false,
    );
  }

  Future<void> _showDeliverDialog(GlobalReplaceModel r) async {
    final dateObs = DateTime.now().obs;
    final noteCtrl = TextEditingController(text: r.note);

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('ডেলিভারি নিশ্চিত করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.productName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('শপ: ${r.shopName}'),
            Text('পরিমাণ: ${r.quantity}টি'),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'মন্তব্য (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 10),
            Obx(() => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: Text(_fmt(dateObs.value)),
                  subtitle: const Text('ডেলিভারির তারিখ'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateObs.value,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) dateObs.value = picked;
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('ডেলিভারি দিয়েছি'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await rc.deliverReplace(
      replaceId: r.id,
      userId: r.userId,
      shopName: r.shopName,
      productId: r.productId,
      productName: r.productName,
      quantity: r.quantity,
      note: noteCtrl.text.trim(),
      deliveredAt: dateObs.value,
    );

    Get.snackbar(
      '✓ ডেলিভারি সম্পন্ন',
      '${r.productName} (${r.quantity}টি) — ${r.shopName}\nস্টক থেকে মাইনাস হয়েছে',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _confirmCancel(GlobalReplaceModel r) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Replace বাতিল করবেন?'),
        content: Text(
          '${r.productName} — ${r.quantity}টি\nশপ: ${r.shopName}\n\n⚠ স্টক অপরিবর্তিত থাকবে',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('না')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('বাতিল করুন'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await rc.cancelReplace(
      replaceId: r.id,
      userId: r.userId,
      productId: r.productId,
      quantity: r.quantity,
    );
    Get.snackbar('বাতিল হয়েছে', 'Replace অনুরোধ বাতিল করা হয়েছে',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _confirmDeleteDelivered(DeliveredReplaceModel r) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('ডেলিভারি রেকর্ড মুছবেন?'),
        content: Text('${r.productName}\nশপ: ${r.shopName}',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('না')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await rc.deleteDeliveredRecord(deliveredId: r.id, userId: r.userId);
  }

  // ══════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════
  Widget _summaryStrip({
    required IconData icon,
    required Color color,
    required String label,
    required String right,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(right,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _dateHeader(String key, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_fmtDateKey(key),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Text('$count টি', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(child: Divider(indent: 8, color: Colors.grey.shade200)),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Map<String, List<GlobalReplaceModel>> _groupByDate(List<GlobalReplaceModel> list) {
    final map = <String, List<GlobalReplaceModel>>{};
    for (final r in list) {
      final key =
          '${r.date.year.toString().padLeft(4, '0')}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  int _countPendingItems(
          List<String> keys, Map<String, List<GlobalReplaceModel>> grouped) =>
      keys.fold(0, (sum, k) => sum + 1 + (grouped[k]?.length ?? 0));
}

// ═══════════════════════════════════════════════════════════════
// ADD REPLACE DIALOG — StatefulWidget (complex form state)
// ═══════════════════════════════════════════════════════════════
class _AddReplaceDialog extends StatefulWidget {
  final ReplaceController rc;
  const _AddReplaceDialog({required this.rc});

  @override
  State<_AddReplaceDialog> createState() => _AddReplaceDialogState();
}

class _AddReplaceDialogState extends State<_AddReplaceDialog> {
  // Controllers
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  final _userSearch = TextEditingController();
  final _productSearch = TextEditingController();

  // State
  UserModel? _selectedUser;
  ProductModel? _selectedProduct;
  DateTime _date = DateTime.now();
  bool _saving = false;

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _userSearch.dispose();
    _productSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uc = Get.find<UserController>();
    final pc = Get.find<ProductController>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('নতুন Replace যোগ করুন',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Get.back()),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User/Shop selection ──────────────────────────────
                    _sectionLabel('কাস্টমার / শপ *'),
                    if (_selectedUser != null)
                      _selectedChip(
                        label: _selectedUser!.shopName,
                        sublabel: _selectedUser!.proprietorName,
                        onRemove: () => setState(() => _selectedUser = null),
                        color: Colors.blue,
                      )
                    else ...[
                      TextField(
                        controller: _userSearch,
                        decoration: const InputDecoration(
                          hintText: 'শপের নাম লিখুন...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 4),
                      _buildUserList(uc),
                    ],
                    const SizedBox(height: 14),

                    // ── Product selection ────────────────────────────────
                    _sectionLabel('পণ্য *'),
                    if (_selectedProduct != null)
                      _selectedChip(
                        label: _selectedProduct!.name,
                        sublabel: 'স্টক: ${_selectedProduct!.stock}',
                        onRemove: () => setState(() => _selectedProduct = null),
                        color: Colors.deepOrange,
                      )
                    else ...[
                      TextField(
                        controller: _productSearch,
                        decoration: const InputDecoration(
                          hintText: 'পণ্যের নাম লিখুন...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 4),
                      _buildProductList(pc),
                    ],
                    const SizedBox(height: 14),

                    // ── Quantity ─────────────────────────────────────────
                    _sectionLabel('পরিমাণ *'),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '1',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: 'টি',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Date ─────────────────────────────────────────────
                    _sectionLabel('তারিখ'),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(_fmt(_date),
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Note ─────────────────────────────────────────────
                    _sectionLabel('মন্তব্য (ঐচ্ছিক)'),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'সমস্যার বিবরণ...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('বাতিল'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('যোগ করুন'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white),
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(UserController uc) {
    final q = _userSearch.text.toLowerCase();
    final filtered = uc.users
        .where((u) =>
            q.isEmpty ||
            u.shopName.toLowerCase().contains(q) ||
            u.proprietorName.toLowerCase().contains(q))
        .take(6)
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = filtered[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.storefront_rounded, size: 20),
            title: Text(u.shopName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(u.proprietorName,
                style: const TextStyle(fontSize: 11)),
            onTap: () {
              setState(() {
                _selectedUser = u;
                _userSearch.clear();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildProductList(ProductController pc) {
    final q = _productSearch.text.toLowerCase();
    final filtered = pc.products
        .where((p) =>
            !p.isInternal &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
        .take(6)
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = filtered[i];
          return ListTile(
            dense: true,
            leading: p.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(p.images.first,
                        width: 32, height: 32, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.inventory_2_rounded, size: 20)),
                  )
                : const Icon(Icons.inventory_2_rounded, size: 20),
            title: Text(p.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('স্টক: ${p.stock} • ${p.productCategory}',
                style: const TextStyle(fontSize: 11)),
            onTap: () {
              setState(() {
                _selectedProduct = p;
                _productSearch.clear();
              });
            },
          );
        },
      ),
    );
  }

  Widget _selectedChip({
    required String label,
    required String sublabel,
    required VoidCallback onRemove,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13)),
                Text(sublabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
    );
  }

  Future<void> _submit() async {
    if (_selectedUser == null) {
      Get.snackbar('ত্রুটি', 'কাস্টমার/শপ সিলেক্ট করুন',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_selectedProduct == null) {
      Get.snackbar('ত্রুটি', 'পণ্য সিলেক্ট করুন',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      Get.snackbar('ত্রুটি', 'সঠিক পরিমাণ দিন',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.rc.addReplace(
        userId: _selectedUser!.id,
        shopName: _selectedUser!.shopName,
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        quantity: qty,
        note: _noteCtrl.text.trim(),
        date: _date,
      );
      Get.back();
      Get.snackbar(
        '✓ যোগ হয়েছে',
        '${_selectedProduct!.name} (${qty}টি) — ${_selectedUser!.shopName}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/admin_replace_controller.dart';
import '../model/admin_replace_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../supplier/controller/supplier_controller.dart';
import '../../supplier/model/supplier_model.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../../widgets/responsive.dart';

class AdminReplaceView extends StatefulWidget {
  const AdminReplaceView({super.key});

  @override
  State<AdminReplaceView> createState() => _AdminReplaceViewState();
}

class _AdminReplaceViewState extends State<AdminReplaceView>
    with SingleTickerProviderStateMixin {
  late final AdminReplaceController _rc;
  late TabController _tabs;
  final _tab = 0.obs;
  final _customerFilter = 'all'.obs; // 'all' | 'pending' | 'delivered'
  static final _fmt = NumberFormat('dd');

  @override
  void initState() {
    super.initState();
    _rc = Get.find<AdminReplaceController>();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() => _tab.value = _tabs.index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Replace Management'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'At Shop'),
            Tab(icon: Icon(Icons.person_rounded, size: 18), text: 'Customer'),
            Tab(icon: Icon(Icons.schedule_rounded, size: 18), text: 'Pending'),
            Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'Supplier'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'History'),
          ],
        ),
        actions: [
          Obx(() => _rc.loading.value
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _rc.fetchEntries(force: true),
                )),
        ],
      ),
      body: ResponsiveWrapper(
        child: TabBarView(
          controller: _tabs,
          children: [
            _atShopTab(cs),
            _customerTab(cs),
            _pendingTab(cs),
            _withSupplierTab(cs),
            _historyTab(cs),
          ],
        ),
      ),
      floatingActionButton: Obx(() {
        if (_tab.value == 4) return const SizedBox.shrink(); // history
        if (_tab.value == 2) return const SizedBox.shrink(); // pending
        if (_tab.value == 0) {
          return FloatingActionButton.extended(
            onPressed: () => _showAddAtShopDialog(context),
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.add_rounded),
            label: const Text('At Shop যোগ করুন'),
          );
        }
        if (_tab.value == 1) {
          return FloatingActionButton.extended(
            onPressed: () => _showAddCustomerDialog(context),
            backgroundColor: Colors.deepPurple,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Customer Replace'),
          );
        }
        if (_tab.value == 3) {
          return FloatingActionButton.extended(
            onPressed: () => _showAddDirectSupplierDialog(context),
            backgroundColor: Colors.blue,
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('Supplier এ যোগ করুন'),
          );
        }
        return const SizedBox.shrink();
      }),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1 — CUSTOMER (all entries with resolution)
  // ══════════════════════════════════════════════
  Widget _customerTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = _rc.customerEntries;
      if (all.isEmpty) {
        return _empty(Icons.person_rounded, 'কোনো কাস্টমার রিপ্লেস এন্ট্রি নেই');
      }
      return Column(
        children: [
          _strip(
            icon: Icons.person_rounded,
            color: Colors.deepPurple,
            label: '${all.length}টি কাস্টমার রিপ্লেস',
            right: 'মোট: ${all.fold(0, (s, e) => s + e.quantity)}টি প্রডাক্ট',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _customerCard(ctx, all[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _filterChip(String value, String label, RxString filter,
      {Color? color}) {
    final selected = filter.value == value;
    final c = color ?? Colors.deepPurple;
    return GestureDetector(
      onTap: () => filter.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? c : Colors.grey.shade600,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }

  Widget _customerCard(BuildContext context, AdminReplaceModel e, ColorScheme cs) {
    final isMoneyDeduct = e.customerResolutionType == 'money_deduct';
    final isProductReplace = e.customerResolutionType == 'product_replace';
    final isDelivered = e.deliveredToCustomer;

    Color statusColor;
    String statusText;
    if (isDelivered) {
      statusColor = Colors.green;
      statusText = isMoneyDeduct ? 'টাকা কাটা' : 'রিপ্লেস নেওয়া হল';
    } else if (isProductReplace) {
      statusColor = Colors.deepPurple;
      statusText = 'রিপ্লেস নেওয়া হল';
    } else if (isMoneyDeduct) {
      statusColor = const Color(0xFFDC2626);
      statusText = 'টাকা কাটা';
    } else {
      statusColor = Colors.orange;
      statusText = 'অপেক্ষমাণ';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBox(Icons.person_rounded, statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.customerName.isNotEmpty ? e.customerName : 'অজানা কাস্টমার',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (e.customerPhone.isNotEmpty)
                        Text(e.customerPhone,
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(120))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: Colors.red.shade400,
                  tooltip: 'ডিলিট',
                  onPressed: () => _confirmDelete(context, e),
                ),
              ],
            ),
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ফেরত দিয়েছে',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('${e.productName} × ${e.quantity}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isMoneyDeduct)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('− ৳ ${_fmt.format(e.deductionAmount)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                  ),
                if (isProductReplace && e.replaceProductName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(e.replaceProductName,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_fmtDate(e.date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                if (e.note.isNotEmpty)
                  Flexible(
                    child: Text(e.note,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 0 — AT SHOP (expandable product-wise)
  // ══════════════════════════════════════════════
  final _expandedProducts = <String>{}.obs;

  Widget _atShopTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = _rc.atShop;
      if (list.isEmpty) {
        return _empty(Icons.inventory_2_rounded,
            'দোকানে কোনো replace item নেই');
      }
      // Group by product
      final grouped = <String, List<AdminReplaceModel>>{};
      for (final e in list) {
        grouped.putIfAbsent(e.productName, () => []);
        grouped[e.productName]!.add(e);
      }

      final totalItems = list.fold(0, (s, e) => s + e.quantity);
      return Column(
        children: [
          _strip(
            icon: Icons.inventory_2_rounded,
            color: Colors.orange,
            label: '${grouped.length}টি প্রডাক্ট',
            right: 'মোট: $totalItemsটি',
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: grouped.length,
              itemBuilder: (ctx, i) {
                final name = grouped.keys.elementAt(i);
                final items = grouped[name]!;
                final totalQty = items.fold(0, (s, e) => s + e.quantity);
                final isExpanded = _expandedProducts.contains(name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            if (isExpanded) {
                              _expandedProducts.remove(name);
                            } else {
                              _expandedProducts.add(name);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: Colors.orange, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.orange.withAlpha(60)),
                                  ),
                                  child: Text('$totalQtyটি',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.orange)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          ...items.map((e) => _atShopEntryRow(e, cs)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _atShopEntryRow(AdminReplaceModel e, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle_rounded, size: 8, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.productName} × ${e.quantity}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (e.customerName.isNotEmpty)
                  Text(e.customerName,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(120))),
              ],
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              _miniBtn(Icons.edit_rounded, 'Qty', Colors.teal,
                  () => _showEditEntryQty(e)),
              _miniBtn(Icons.local_shipping_rounded, 'Send', Colors.blue,
                  () => _showSendToSupplierDialog(context, e)),
              _miniBtn(Icons.build_circle_rounded, 'Done', Colors.green,
                  () => _showResolveDialog(context, e)),
              _miniBtn(Icons.delete_outline_rounded, 'Del', Colors.red,
                  () => _confirmDelete(context, e)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditEntryQty(AdminReplaceModel e) {
    final qtyCtrl = TextEditingController(text: e.quantity.toString());
    Get.dialog(
      AlertDialog(
        title: Text('${e.productName} — পরিমাণ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            prefixText: 'পরিমাণ: ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final newQty = int.tryParse(qtyCtrl.text.trim());
              if (newQty == null || newQty <= 0 || newQty == e.quantity) {
                Get.back();
                return;
              }
              final delta = newQty - e.quantity;
              await FirebaseFirestore.instance
                  .collection('admin_replace_entries')
                  .doc(e.id)
                  .update({'quantity': newQty});
              if (e.productId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(e.productId)
                    .update({'replaceCount': FieldValue.increment(delta)});
              }
              await _rc.fetchEntries(force: true);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('আপডেট'),
          ),
        ],
      ),
    ).then((_) => qtyCtrl.dispose());
  }

  Widget _miniBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1 — PENDING CUSTOMER DELIVERY
  // ══════════════════════════════════════════════
  Widget _pendingTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      // All entries where customer will receive a product but not yet delivered
      final pending = _rc.entries
          .where((e) =>
              e.customerResolutionType == 'product_replace' &&
              !e.deliveredToCustomer)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (pending.isEmpty) {
        return _empty(Icons.schedule_rounded,
            'কোনো পেন্ডিং রিপ্লেস ডেলিভারি নেই');
      }

      // Group by product for summary
      final grouped = <String, int>{};
      for (final e in pending) {
        grouped[e.productName] =
            (grouped[e.productName] ?? 0) + e.quantity;
      }

      return Column(
        children: [
          _strip(
            icon: Icons.schedule_rounded,
            color: Colors.deepPurple,
            label: '${pending.length}টি পেন্ডিং ডেলিভারি',
            right: 'মোট: ${pending.fold(0, (s, e) => s + e.quantity)}টি',
          ),
          // Product-wise summary
          if (grouped.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: grouped.entries
                    .map((e) => Text(
                        '${e.key}: ${e.value}টি',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple)))
                    .toList(),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _pendingCard(ctx, pending[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _pendingCard(
      BuildContext context, AdminReplaceModel e, ColorScheme cs) {
    final hasReplace = e.replaceProductName.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.schedule_rounded,
                hasReplace ? Colors.deepPurple : Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.customerName.isNotEmpty ? e.customerName : 'অজানা কাস্টমার',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (e.customerPhone.isNotEmpty)
                    _infoRow(Icons.phone_outlined, e.customerPhone, ''),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward_rounded,
                            size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('ফেরত: ${e.productName}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasReplace)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(18),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.green.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded,
                              size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('পাবে: ${e.replaceProductName}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.green)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(18),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.orange.withAlpha(50)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded,
                              size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text('রিপ্লেস প্রোডাক্ট নির্ধারিত নয়',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange)),
                          ),
                        ],
                      ),
                    ),
                  if (e.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(e.note,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  _infoRow(
                      Icons.calendar_today_rounded, _fmtDate(e.date), ''),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _qtyBadge(e.quantity, Colors.deepPurple),
                const SizedBox(height: 6),
                if (hasReplace)
                  _actionChip(
                    Icons.check_circle_rounded,
                    'দিয়েছি',
                    Colors.green,
                    () => _showDeliverDialog(context, e),
                  )
                else
                  _actionChip(
                    Icons.add_circle_rounded,
                    'প্রোডাক্ট সেট',
                    Colors.deepPurple,
                    () => _showSetResolutionDialog(context, e),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 3 — WITH SUPPLIER
  // ══════════════════════════════════════════════
  Widget _withSupplierTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = _rc.withSupplier;
      if (list.isEmpty) {
        return _empty(Icons.local_shipping_rounded,
            'সাপ্লাইয়ারে কোনো আইটেম নেই');
      }
      return Column(
        children: [
          _strip(
            icon: Icons.local_shipping_rounded,
            color: Colors.blue,
            label: '${list.length}টি আইটেম সাপ্লাইয়ারে',
            right: 'মোট: ${list.fold(0, (s, e) => s + e.quantity)}টি',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _supplierCard(ctx, list[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _supplierCard(
      BuildContext context, AdminReplaceModel e, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.local_shipping_rounded, Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  _infoRow(Icons.store_rounded, e.supplierName, ''),
                  if (e.sentToSupplierDate != null)
                    _infoRow(Icons.send_rounded,
                        'পাঠানো: ${_fmtDate(e.sentToSupplierDate!)}', ''),
                  if (e.customerName.isNotEmpty)
                    _infoRow(
                        Icons.person_outline_rounded, e.customerName, ''),
                  if (e.note.isNotEmpty)
                    Text(e.note,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _qtyBadge(e.quantity, Colors.blue),
                const SizedBox(height: 6),
                _actionChip(
                  Icons.call_received_rounded,
                  'ফেরত পেলাম',
                  Colors.green,
                  () => _showResolveDialog(context, e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // (DEPRECATED — replaced by _pendingTab)
  // ══════════════════════════════════════════════
  Widget _customerDeliveryTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = _rc.pendingCustomerDelivery;
      if (list.isEmpty) {
        return _empty(Icons.person_pin_rounded,
            'সব কাস্টমারকে ডেলিভারি দেওয়া হয়েছে');
      }
      return Column(
        children: [
          _strip(
            icon: Icons.person_pin_rounded,
            color: Colors.deepPurple,
            label: '${list.length}জন কাস্টমার ডেলিভারি পেন্ডিং',
            right: 'মোট: ${list.fold(0, (s, e) => s + e.quantity)}টি',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _deliveryCard(ctx, list[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _deliveryCard(
      BuildContext context, AdminReplaceModel e, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.person_pin_rounded, Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.customerName.isNotEmpty ? e.customerName : 'অজানা কাস্টমার',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (e.customerPhone.isNotEmpty)
                    _infoRow(Icons.phone_outlined, e.customerPhone, ''),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward_rounded,
                            size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('দিয়েছে: ${e.productName}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: Colors.green.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('পাবে: ${e.replaceProductName}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.green)),
                      ],
                    ),
                  ),
                  if (e.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(e.note,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  _infoRow(Icons.calendar_today_rounded, _fmtDate(e.date), ''),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _qtyBadge(e.quantity, Colors.deepPurple),
                const SizedBox(height: 6),
                _actionChip(
                  Icons.check_circle_rounded,
                  'দিয়েছি',
                  Colors.green,
                  () => _showDeliverDialog(context, e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // (DEPRECATED — replace stock tab removed)
  // ══════════════════════════════════════════════
  Widget _replaceStockTab(ColorScheme cs) {
    return Obx(() {
      final pc = Get.find<ProductController>();
      if (pc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      // Show products that have replaceStock > 0
      final list = pc.products
          .where((p) => p.replaceStock > 0)
          .toList()
        ..sort((a, b) =>
            b.replaceStock.compareTo(a.replaceStock));
      if (list.isEmpty) {
        return _empty(Icons.inventory_2_rounded,
            'কোনো রিপ্লেস প্রডাক্ট নেই');
      }
      final totalReplaceStock = list.fold(0, (s, p) => s + p.replaceStock);
      return Column(
        children: [
          _strip(
            icon: Icons.inventory_2_rounded,
            color: Colors.teal,
            label: '${list.length} প্রডাক্ট',
            right: 'মোট: $totalReplaceStockটি',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _replaceStockCard(list[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _replaceStockCard(ProductModel p, ColorScheme cs) {
    final hasReplaceStock = p.replaceStock > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: p.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(p.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_rounded,
                                  color: Colors.teal)))
                      : const Icon(Icons.inventory_2_rounded, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      if (p.brandName.isNotEmpty || p.productCode.isNotEmpty)
                        Text(
                          [p.brandName, p.productCode].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge('রেগুলার: ${p.stock}', Colors.green),
                if (hasReplaceStock)
                  _badge('রিপ্লেস স্টক: ${p.replaceStock}', Colors.teal),
                // Action buttons
                const SizedBox(width: 4),
                _actionChip(Icons.edit_rounded, 'Edit', Colors.teal,
                    () => _showEditReplaceStock(p)),
                if (hasReplaceStock)
                  _actionChip(Icons.delete_outline_rounded, 'Clear', Colors.red,
                      () => _showClearReplaceStock(p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit replace stock dialog ─────────────────────────────

  void _showEditReplaceStock(ProductModel p) {
    final qtyCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Row(children: [
          const Icon(Icons.edit_rounded, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('রিপ্লেস স্টক: ${p.name}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('বর্তমান রিপ্লেস স্টক: ${p.replaceStock}টি',
                style: const TextStyle(fontSize: 13, color: Colors.teal)),
            const SizedBox(height: 10),
            const Text('পরিমাণ পরিবর্তন (+/-):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'যেমন: 5 (যোগ) বা -3 (বাদ)',
                filled: true,
                fillColor: Colors.teal.withAlpha(8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 4),
            const Text('যোগ করতে +, বাদ দিতে - ব্যবহার করুন',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () async {
              final delta = int.tryParse(qtyCtrl.text.trim());
              if (delta == null || delta == 0) {
                Get.snackbar('ত্রুটি', 'সঠিক সংখ্যা লিখুন',
                    snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              await _rc.adjustReplaceStock(p.id, delta);
              Get.back();
              Get.snackbar('আপডেট', 'রিপ্লেস স্টক $delta পরিবর্তন হয়েছে',
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.teal, colorText: Colors.white);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('আপডেট'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          ),
        ],
      ),
    ).then((_) => qtyCtrl.dispose());
  }

  // ── Clear replace stock dialog ───────────────────────────

  void _showClearReplaceStock(ProductModel p) {
    Get.dialog(
      AlertDialog(
        title: const Text('রিপ্লেস স্টক ক্লিয়ার করবেন?'),
        content: Text('"${p.name}" এর ${p.replaceStock}টি রিপ্লেস স্টক ০ করা হবে।'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('না')),
          ElevatedButton.icon(
            onPressed: () async {
              await _rc.adjustReplaceStock(p.id, -p.replaceStock);
              Get.back();
              Get.snackbar('ক্লিয়ার', 'রিপ্লেস স্টক ০ করা হয়েছে',
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.teal, colorText: Colors.white);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('হ্যাঁ, ক্লিয়ার'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 4 — HISTORY (resolved entries)
  // ══════════════════════════════════════════════
  Widget _historyTab(ColorScheme cs) {
    return Obx(() {
      if (_rc.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final list = _rc.resolved;
      if (list.isEmpty) {
        return _empty(Icons.history_rounded, 'কোনো ইতিহাস নেই');
      }
      return Column(
        children: [
          _strip(
            icon: Icons.history_rounded,
            color: Colors.grey.shade600,
            label: 'মোট ${list.length}টি সম্পন্ন',
            right: '${list.fold(0, (s, e) => s + e.resolvedQty)}টি রিজলভড',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _historyCard(list[i], cs),
            ),
          ),
        ],
      );
    });
  }

  Widget _historyCard(AdminReplaceModel e, ColorScheme cs) {
    final color = e.resolution == 'scrapped'
        ? Colors.grey
        : e.resolution == 'added_to_replace_stock'
            ? Colors.teal
            : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.check_circle_rounded, color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  _infoRow(Icons.info_outline_rounded, e.statusLabel, ''),
                  if (e.supplierName.isNotEmpty)
                    _infoRow(Icons.store_rounded, e.supplierName, ''),
                  if (e.customerName.isNotEmpty)
                    _infoRow(
                        Icons.person_outline_rounded, e.customerName, ''),
                  if (e.resolvedAt != null)
                    _infoRow(Icons.event_available_rounded,
                        'রিজলভড: ${_fmtDate(e.resolvedAt!)}', ''),
                  if (e.hasCustomer && e.hasReplaceProduct)
                    _infoRow(
                      e.deliveredToCustomer
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      e.deliveredToCustomer
                          ? 'কাস্টমারকে দেওয়া হয়েছে'
                          : 'কাস্টমার ডেলিভারি পেন্ডিং',
                      '',
                    ),
                  if (e.note.isNotEmpty)
                    Text(e.note,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            _qtyBadge(e.resolvedQty > 0 ? e.resolvedQty : e.quantity, color),
            const SizedBox(height: 6),
            _actionChip(
              Icons.delete_outline_rounded,
              'মুছুন',
              Colors.red,
              () => _confirmDelete(context, e),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddReplaceSheet(rc: _rc),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddCustomerReplaceSheet(rc: _rc),
    );
  }

  void _showAddDirectSupplierDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddDirectSupplierSheet(rc: _rc),
    );
  }

  void _showAddAtShopDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddAtShopSheet(rc: _rc),
    );
  }

  void _showSendToSupplierDialog(
      BuildContext context, AdminReplaceModel e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SendToSupplierSheet(rc: _rc, entry: e),
    );
  }

  void _showResolveDialog(BuildContext context, AdminReplaceModel e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ResolveSheet(rc: _rc, entry: e),
    );
  }

  void _showDeliverDialog(BuildContext context, AdminReplaceModel e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DeliverToCustomerSheet(rc: _rc, entry: e),
    );
  }

  void _showSetResolutionDialog(BuildContext context, AdminReplaceModel e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SetResolutionSheet(rc: _rc, entry: e),
    );
  }

  void _confirmDelete(BuildContext context, AdminReplaceModel e) {
    Get.dialog(AlertDialog(
      title: const Text('মুছে দেবেন?'),
      content: Text(
          '"${e.productName}" এন্ট্রিটি মুছে যাবে।\nreplaceCount আপডেট হবে।'),
      actions: [
        TextButton(
            onPressed: Get.back, child: const Text('বাতিল')),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await _rc.deleteEntry(e);
            Get.back();
          },
          child: const Text('মুছুন',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ══════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════

  Widget _empty(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _strip({
    required IconData icon,
    required Color color,
    required String label,
    required String right,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12))),
          Text(right,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _qtyBadge(int qty, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${qty}টি',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14)),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String text, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text('$text$suffix',
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD REPLACE SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _AddReplaceSheet extends StatefulWidget {
  final AdminReplaceController rc;
  const _AddReplaceSheet({required this.rc});

  @override
  State<_AddReplaceSheet> createState() => _AddReplaceSheetState();
}

class _AddReplaceSheetState extends State<_AddReplaceSheet> {
  UserModel? _customer;
  final _noteCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  ProductModel? _product;
  ProductModel? _replaceProduct; // what the customer will get
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _product = picked);
  }

  Future<void> _pickReplaceProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _replaceProduct = picked);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('প্রডাক্ট বেছে নিন')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() => _saving = true);
    try {
      await widget.rc.addCustomerIn(
        productId: _product!.id,
        productName: _product!.name,
        quantity: qty,
        customerId: _customer?.id ?? '',
        customerName: _customer?.shopName ?? '',
        customerPhone: _customer?.phone ?? '',
        customerAddress: _customer?.address ?? '',
        replaceProductId: _replaceProduct?.id ?? '',
        replaceProductName: _replaceProduct?.name ?? '',
        note: _noteCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('যোগ হয়েছে', 'Replace entry সফলভাবে যোগ হয়েছে',
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
          _handle(),
          _sheetHeader('Replace যোগ করুন', Icons.add_circle_rounded,
              scheme.primary),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  // Defective product (what customer is giving us)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('কাস্টমার কি দিচ্ছে? (সমস্যার প্রডাক্ট)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 6),
                  // Product picker
                  InkWell(
                    onTap: _pickProduct,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _product != null
                                ? scheme.primary
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _product != null
                            ? scheme.primaryContainer.withAlpha(50)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 18,
                              color: _product != null
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _product != null
                                ? Text(_product!.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary))
                                : Text('প্রডাক্ট বেছে নিন',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Replace product picker (what customer will get)
                  InkWell(
                    onTap: _pickReplaceProduct,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _replaceProduct != null
                                ? Colors.green
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _replaceProduct != null
                            ? Colors.green.withAlpha(18)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              size: 18,
                              color: _replaceProduct != null
                                  ? Colors.green
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _replaceProduct != null
                                ? Text(_replaceProduct!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green))
                                : Text(
                                    'কাস্টমার কি পাবে? (ঐচ্ছিক)',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                          ),
                          if (_replaceProduct != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _replaceProduct = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: Colors.grey),
                            )
                          else
                            Icon(Icons.arrow_drop_down_rounded,
                                color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date + Qty row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                    DateFormat('dd MMM, yyyy')
                                        .format(_date),
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'পরিমাণ',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Customer picker (optional)
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _customer != null
                                ? scheme.primary
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _customer != null
                            ? scheme.primaryContainer.withAlpha(40)
                            : null,
                      ),
                      child: _customer == null
                          ? Row(
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 18,
                                    color: scheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text('কাস্টমার বেছে নিন (ঐচ্ছিক)',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(Icons.store_rounded,
                                    size: 18, color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_customer!.shopName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: scheme.primary)),
                                      if (_customer!.phone.isNotEmpty)
                                        Text(_customer!.phone,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_rounded,
                                    size: 14, color: Colors.grey),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'নোট (ঐচ্ছিক)',
                      prefixIcon: const Icon(Icons.note_alt_outlined,
                          size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
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
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('সংরক্ষণ করুন'),
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
}

// ══════════════════════════════════════════════════════════════════════════════
// SEND TO SUPPLIER SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _SendToSupplierSheet extends StatefulWidget {
  final AdminReplaceController rc;
  final AdminReplaceModel entry;
  const _SendToSupplierSheet({required this.rc, required this.entry});

  @override
  State<_SendToSupplierSheet> createState() => _SendToSupplierSheetState();
}

class _SendToSupplierSheetState extends State<_SendToSupplierSheet> {
  SupplierModel? _supplier;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    try {
      Get.find<SupplierController>();
    } catch (_) {
      Get.lazyPut<SupplierController>(() => SupplierController());
    }
    final picked = await showModalBottomSheet<SupplierModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierPickerSheet(),
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _save() async {
    if (_supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সাপ্লাইয়ার বেছে নিন')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.rc.sendToSupplier(
        entry: widget.entry,
        supplierId: _supplier!.id,
        supplierName: _supplier!.shopName,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('পাঠানো হয়েছে',
          '"${widget.entry.productName}" সাপ্লাইয়ারে পাঠানো হয়েছে',
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
          _handle(),
          _sheetHeader(
              'সাপ্লাইয়ারে পাঠান', Icons.local_shipping_rounded, Colors.blue),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                _productInfo(widget.entry, scheme),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickSupplier,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _supplier != null
                              ? Colors.blue
                              : scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                      color: _supplier != null
                          ? Colors.blue.withAlpha(15)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store_rounded,
                            size: 18,
                            color: _supplier != null
                                ? Colors.blue
                                : scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _supplier != null
                              ? Text(_supplier!.shopName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue))
                              : Text('সাপ্লাইয়ার বেছে নিন',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant)),
                        ),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'নোট (ঐচ্ছিক)',
                    prefixIcon:
                        const Icon(Icons.note_alt_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: const Text('পাঠিয়ে দিন'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RESOLVE SHEET (Add to stock / scrap)
// ══════════════════════════════════════════════════════════════════════════════

class _ResolveSheet extends StatefulWidget {
  final AdminReplaceController rc;
  final AdminReplaceModel entry;
  const _ResolveSheet({required this.rc, required this.entry});

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  String _resolution = 'added_to_replace_stock';
  late final _qtyCtrl =
      TextEditingController(text: widget.entry.quantity.toString());
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? widget.entry.quantity;
    setState(() => _saving = true);
    try {
      await widget.rc.resolveEntry(
        entry: widget.entry,
        resolution: _resolution,
        resolvedQty: qty,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      final label = _resolution == 'scrapped'
          ? 'বাতিল করা হয়েছে'
          : _resolution == 'added_to_regular_stock'
              ? 'রেগুলার স্টকে যোগ হয়েছে'
              : 'রিপ্লেস স্টকে যোগ হয়েছে';
      Get.snackbar('সম্পন্ন!', '"${widget.entry.productName}" — $label',
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
          _handle(),
          _sheetHeader('পরিস্থিতি নির্ধারণ',
              Icons.check_circle_outline_rounded, Colors.green),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productInfo(widget.entry, scheme),
                const SizedBox(height: 16),
                const Text('কোথায় যাবে?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _resolutionOption(
                  'added_to_replace_stock',
                  Icons.inventory_2_rounded,
                  'রিপ্লেস স্টকে যোগ করুন',
                  'মেরামত/পরিবর্তিত — রিপ্লেস স্টক হিসেবে রাখুন',
                  Colors.teal,
                ),
                const SizedBox(height: 8),
                _resolutionOption(
                  'added_to_regular_stock',
                  Icons.add_box_rounded,
                  'রেগুলার স্টকে যোগ করুন',
                  'নতুনের মতো — সাধারণ স্টকে রাখুন',
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _resolutionOption(
                  'scrapped',
                  Icons.delete_forever_rounded,
                  'বাতিল করুন',
                  'মেরামত অযোগ্য — ফেলে দিন',
                  Colors.red,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('পরিমাণ: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('/ ${widget.entry.quantity}টি',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'নোট (ঐচ্ছিক)',
                    prefixIcon:
                        const Icon(Icons.note_alt_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: const Text('নিশ্চিত করুন'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resolutionOption(String value, IconData icon, String title,
      String subtitle, Color color) {
    final selected = _resolution == value;
    return InkWell(
      onTap: () => setState(() => _resolution = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : null,
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? color : null,
                          fontSize: 13)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD CUSTOMER REPLACE SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _AddCustomerReplaceSheet extends StatefulWidget {
  final AdminReplaceController rc;
  const _AddCustomerReplaceSheet({required this.rc});

  @override
  State<_AddCustomerReplaceSheet> createState() =>
      _AddCustomerReplaceSheetState();
}

class _AddCustomerReplaceSheetState extends State<_AddCustomerReplaceSheet> {
  UserModel? _customer;
  final _noteCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();
  ProductModel? _defectiveProduct;
  ProductModel? _replaceProduct;
  DateTime _date = DateTime.now();
  String _resolutionType = ''; // '' | 'product_replace' | 'money_deduct'
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickDefectiveProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _defectiveProduct = picked);
  }

  Future<void> _pickReplaceProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _replaceProduct = picked);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_defectiveProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defective product বেছে নিন')));
      return;
    }
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer বেছে নিন')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    setState(() => _saving = true);
    try {
      await widget.rc.addCustomerIn(
        productId: _defectiveProduct!.id,
        productName: _defectiveProduct!.name,
        quantity: qty,
        customerId: _customer!.id,
        customerName: _customer!.shopName,
        customerPhone: _customer!.phone,
        customerAddress: _customer!.address,
        replaceProductId: _replaceProduct?.id ?? '',
        replaceProductName: _replaceProduct?.name ?? '',
        customerResolutionType: _resolutionType,
        deductionAmount:
            _resolutionType == 'money_deduct' ? amount : 0,
        note: _noteCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('Added', 'Customer replace entry added',
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
          _handle(),
          _sheetHeader(
              'Customer Replace', Icons.person_add_rounded, Colors.deepPurple),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer picker
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _customer != null
                              ? Colors.deepPurple
                              : scheme.outlineVariant,
                          width: _customer != null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: _customer != null
                            ? Colors.deepPurple.withAlpha(8)
                            : null,
                      ),
                      child: _customer == null
                          ? Row(
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 20, color: Colors.grey.shade500),
                                const SizedBox(width: 10),
                                Text('Customer বেছে নিন *',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14)),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.store_rounded,
                                    size: 18, color: Colors.deepPurple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_customer!.shopName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      Row(
                                        children: [
                                          if (_customer!.phone.isNotEmpty) ...[
                                            const Icon(Icons.phone_rounded,
                                                size: 12,
                                                color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(_customer!.phone,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey)),
                                            const SizedBox(width: 8),
                                          ],
                                          if (_customer!.address
                                              .isNotEmpty) ...[
                                            const Icon(
                                                Icons.location_on_rounded,
                                                size: 12,
                                                color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(_customer!.address,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_rounded,
                                    size: 14, color: Colors.deepPurple),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Defective product picker
                  Text('Defective Product (Received from customer)',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  _pickerTile(
                    onTap: _pickDefectiveProduct,
                    icon: Icons.broken_image_rounded,
                    label: _defectiveProduct?.name ?? 'Pick defective product *',
                    selected: _defectiveProduct != null,
                    color: Colors.red,
                    scheme: scheme,
                  ),
                  const SizedBox(height: 14),
                  // Resolution type
                  const Text('Resolution Type',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _resolutionOption(
                          'product_replace',
                          Icons.swap_horiz_rounded,
                          'Product Replace',
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolutionOption(
                          'money_deduct',
                          Icons.currency_rupee_rounded,
                          'Money Deduct',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolutionOption(
                          '',
                          Icons.hourglass_empty_rounded,
                          'Decide Later',
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Conditional fields
                  if (_resolutionType == 'product_replace') ...[
                    Text('Replace Product (Customer will receive)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    _pickerTile(
                      onTap: _pickReplaceProduct,
                      icon: Icons.inventory_2_rounded,
                      label:
                          _replaceProduct?.name ?? 'Pick replace product',
                      selected: _replaceProduct != null,
                      color: Colors.teal,
                      scheme: scheme,
                    ),
                    const SizedBox(height: 12),
                  ] else if (_resolutionType == 'money_deduct') ...[
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Deduction Amount (৳)',
                        prefixIcon: const Icon(
                            Icons.currency_rupee_rounded,
                            size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Date + qty row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                    DateFormat('dd MMM, yyyy')
                                        .format(_date),
                                    style:
                                        const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon:
                          const Icon(Icons.note_alt_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepPurple),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save Entry'),
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

  Widget _resolutionOption(
      String value, IconData icon, String label, Color color) {
    final selected = _resolutionType == value;
    return GestureDetector(
      onTap: () => setState(() => _resolutionType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20, color: selected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? color : Colors.grey,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }


  Widget _pickerTile({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required ColorScheme scheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? color : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
          color: selected ? color.withAlpha(18) : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: selected ? color : scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? color : scheme.onSurfaceVariant)),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SET RESOLUTION SHEET (Update resolution for an existing entry)
// ══════════════════════════════════════════════════════════════════════════════

class _SetResolutionSheet extends StatefulWidget {
  final AdminReplaceController rc;
  final AdminReplaceModel entry;
  const _SetResolutionSheet({required this.rc, required this.entry});

  @override
  State<_SetResolutionSheet> createState() => _SetResolutionSheetState();
}

class _SetResolutionSheetState extends State<_SetResolutionSheet> {
  late String _resolutionType;
  ProductModel? _replaceProduct;
  late final _amountCtrl = TextEditingController(
      text: widget.entry.deductionAmount > 0
          ? widget.entry.deductionAmount.toString()
          : '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolutionType = widget.entry.customerResolutionType;
    // Pre-fill replace product name if set
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _replaceProduct = picked);
  }

  Future<void> _save() async {
    if (_resolutionType == 'product_replace' &&
        _replaceProduct == null &&
        widget.entry.replaceProductName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Replace product বেছে নিন')));
      return;
    }
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    setState(() => _saving = true);
    try {
      await widget.rc.setCustomerResolution(
        entry: widget.entry,
        resolutionType: _resolutionType,
        replaceProductId:
            _replaceProduct?.id ?? widget.entry.replaceProductId,
        replaceProductName:
            _replaceProduct?.name ?? widget.entry.replaceProductName,
        deductionAmount:
            _resolutionType == 'money_deduct' ? amount : 0,
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('Updated', 'Customer resolution updated',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.entry;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _sheetHeader('Set Resolution', Icons.edit_rounded, Colors.deepPurple),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Entry info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.deepPurple.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                          e.customerName.isNotEmpty
                              ? e.customerName
                              : 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple)),
                      const Spacer(),
                      const Icon(Icons.broken_image_rounded,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(e.productName,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Resolution Type',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _resolutionOption(
                            'product_replace',
                            Icons.swap_horiz_rounded,
                            'Product Replace',
                            Colors.teal)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _resolutionOption(
                            'money_deduct',
                            Icons.currency_rupee_rounded,
                            'Money Deduct',
                            Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_resolutionType == 'product_replace') ...[
                  InkWell(
                    onTap: _pickProduct,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _replaceProduct != null
                                ? Colors.teal
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _replaceProduct != null
                            ? Colors.teal.withAlpha(18)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 18,
                              color: _replaceProduct != null
                                  ? Colors.teal
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _replaceProduct?.name ??
                                  (e.replaceProductName.isNotEmpty
                                      ? e.replaceProductName
                                      : 'Pick replace product'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _replaceProduct != null ||
                                          e.replaceProductName.isNotEmpty
                                      ? Colors.teal
                                      : scheme.onSurfaceVariant),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (_resolutionType == 'money_deduct') ...[
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Deduction Amount (৳)',
                      prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resolutionOption(
      String value, IconData icon, String label, Color color) {
    final selected = _resolutionType == value;
    return GestureDetector(
      onTap: () => setState(() => _resolutionType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? color : Colors.grey,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELIVER TO CUSTOMER SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _DeliverToCustomerSheet extends StatefulWidget {
  final AdminReplaceController rc;
  final AdminReplaceModel entry;
  const _DeliverToCustomerSheet({required this.rc, required this.entry});

  @override
  State<_DeliverToCustomerSheet> createState() =>
      _DeliverToCustomerSheetState();
}

class _DeliverToCustomerSheetState extends State<_DeliverToCustomerSheet> {
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.rc.deliverToCustomer(
        entry: widget.entry,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar(
        'ডেলিভারি দেওয়া হয়েছে',
        '${widget.entry.customerName.isNotEmpty ? widget.entry.customerName : "কাস্টমার"}কে "${widget.entry.replaceProductName}" দেওয়া হয়েছে',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.entry;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _sheetHeader(
              'কাস্টমারকে ডেলিভারি দিন',
              Icons.person_pin_rounded,
              Colors.deepPurple),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                // Customer info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.deepPurple.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Text(
                            e.customerName.isNotEmpty
                                ? e.customerName
                                : 'অজানা কাস্টমার',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.deepPurple),
                          ),
                        ],
                      ),
                      if (e.customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(e.customerPhone,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                      const Divider(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('দিয়েছিল:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey)),
                                Text(e.productName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.grey),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('পাবে:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey)),
                                Text(e.replaceProductName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'নোট (ঐচ্ছিক)',
                    prefixIcon:
                        const Icon(Icons.note_alt_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: const Text('ডেলিভারি নিশ্চিত করুন'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT PICKER SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<ProductController>();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _sheetHeader(
              'প্রডাক্ট বেছে নিন', Icons.inventory_2_rounded, Colors.teal),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'প্রডাক্ট সার্চ করুন...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: Obx(() {
              final list = pc.products.where((p) {
                if (_query.isEmpty) return true;
                return p.name.toLowerCase().contains(_query) ||
                    p.productCode.toLowerCase().contains(_query);
              }).toList();
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${p.productCategory} · স্টক: ${p.stock}',
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUPPLIER PICKER SHEET (local copy for replace module)
// ══════════════════════════════════════════════════════════════════════════════

class _AddDirectSupplierSheet extends StatefulWidget {
  final AdminReplaceController rc;
  const _AddDirectSupplierSheet({required this.rc});

  @override
  State<_AddDirectSupplierSheet> createState() =>
      _AddDirectSupplierSheetState();
}

class _AddDirectSupplierSheetState
    extends State<_AddDirectSupplierSheet> {
  ProductModel? _product;
  SupplierModel? _supplier;
  UserModel? _customer;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _product = picked);
  }

  Future<void> _pickSupplier() async {
    final picked = await showModalBottomSheet<SupplierModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _SupplierPickerSheet(),
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('প্রডাক্ট বেছে নিন')));
      return;
    }
    if (_supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সাপ্লাইয়ার বেছে নিন')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() => _saving = true);
    try {
      await widget.rc.addDirectToSupplier(
        productId: _product!.id,
        productName: _product!.name,
        quantity: qty,
        supplierId: _supplier!.id,
        supplierName: _supplier!.shopName,
        customerId: _customer?.id ?? '',
        customerName: _customer?.shopName ?? '',
        customerPhone: _customer?.phone ?? '',
        customerAddress: _customer?.address ?? '',
        note: _noteCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('যোগ হয়েছে', 'সাপ্লাইয়ারে সরাসরি এন্ট্রি যোগ হয়েছে',
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
          _handle(),
          _sheetHeader('Supplier এ যোগ করুন',
              Icons.local_shipping_rounded, Colors.blue),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product picker
                  InkWell(
                    onTap: _pickProduct,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _product != null
                                ? Colors.blue
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _product != null
                            ? Colors.blue.withAlpha(12)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 18,
                              color: _product != null
                                  ? Colors.blue
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _product?.name ?? 'প্রডাক্ট বেছে নিন *',
                              style: TextStyle(
                                  fontWeight: _product != null
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: _product != null
                                      ? Colors.blue
                                      : scheme.onSurfaceVariant),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Supplier picker
                  InkWell(
                    onTap: _pickSupplier,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _supplier != null
                                ? Colors.blue
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _supplier != null
                            ? Colors.blue.withAlpha(12)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.store_rounded,
                              size: 18,
                              color: _supplier != null
                                  ? Colors.blue
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _supplier?.shopName ?? 'সাপ্লাইয়ার বেছে নিন *',
                              style: TextStyle(
                                  fontWeight: _supplier != null
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: _supplier != null
                                      ? Colors.blue
                                      : scheme.onSurfaceVariant),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Customer picker (optional)
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _customer != null
                                ? Colors.deepPurple
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _customer != null
                            ? Colors.deepPurple.withAlpha(8)
                            : null,
                      ),
                      child: _customer == null
                          ? Row(children: [
                              Icon(Icons.person_search_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text('Customer বেছে নিন (ঐচ্ছিক)',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant)),
                            ])
                          : Row(children: [
                              const Icon(Icons.store_rounded,
                                  size: 18, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_customer!.shopName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    if (_customer!.phone.isNotEmpty)
                                      Text(_customer!.phone,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_rounded,
                                  size: 14, color: Colors.deepPurple),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date + Qty
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(DateFormat('dd MMM, yyyy').format(_date),
                                  style: const TextStyle(fontSize: 13)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon:
                          const Icon(Icons.note_alt_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('সংরক্ষণ করুন'),
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
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    UserController uc;
    try {
      uc = Get.find<UserController>();
    } catch (_) {
      Get.lazyPut<UserController>(() => UserController(), fenix: true);
      uc = Get.find<UserController>();
    }
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _sheetHeader(
              'Customer বেছে নিন', Icons.person_search_rounded, Colors.deepPurple),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'দোকানের নাম, ফোন বা ঠিকানা দিয়ে সার্চ করুন...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: Obx(() {
              final list = uc.users.where((u) {
                if (_query.isEmpty) return true;
                return u.shopName.toLowerCase().contains(_query) ||
                    u.phone.toLowerCase().contains(_query) ||
                    u.address.toLowerCase().contains(_query) ||
                    u.proprietorName.toLowerCase().contains(_query);
              }).toList();
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('কোনো customer পাওয়া যায়নি',
                          style: TextStyle(color: Colors.grey))),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = list[i];
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEDE7F6),
                      child: Icon(Icons.store_rounded,
                          size: 16, color: Colors.deepPurple),
                    ),
                    title: Text(u.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (u.proprietorName.isNotEmpty)
                          Text(u.proprietorName,
                              style: const TextStyle(fontSize: 11)),
                        Row(
                          children: [
                            if (u.phone.isNotEmpty) ...[
                              const Icon(Icons.phone_rounded,
                                  size: 11, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(u.phone,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 8),
                            ],
                            if (u.address.isNotEmpty) ...[
                              const Icon(Icons.location_on_rounded,
                                  size: 11, color: Colors.grey),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(u.address,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: u.proprietorName.isNotEmpty,
                    onTap: () => Navigator.of(context).pop(u),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SupplierPickerSheet extends StatefulWidget {
  const _SupplierPickerSheet();

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sc = Get.find<SupplierController>();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _sheetHeader(
              'সাপ্লাইয়ার বেছে নিন', Icons.store_rounded, Colors.blue),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'সাপ্লাইয়ার সার্চ করুন...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: Obx(() {
              final list = sc.suppliers.where((s) {
                if (_query.isEmpty) return true;
                return s.shopName.toLowerCase().contains(_query) ||
                    s.ownerName.toLowerCase().contains(_query);
              }).toList();
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = list[i];
                  return ListTile(
                    dense: true,
                    title: Text(s.shopName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(s.ownerName,
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD AT SHOP SHEET (direct entry, no customer required)
// ══════════════════════════════════════════════════════════════════════════════

class _AddAtShopSheet extends StatefulWidget {
  final AdminReplaceController rc;
  const _AddAtShopSheet({required this.rc});

  @override
  State<_AddAtShopSheet> createState() => _AddAtShopSheetState();
}

class _AddAtShopSheetState extends State<_AddAtShopSheet> {
  ProductModel? _product;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _product = picked);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('প্রডাক্ট বেছে নিন')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() => _saving = true);
    try {
      await widget.rc.addAtShopEntry(
        productId: _product!.id,
        productName: _product!.name,
        quantity: qty,
        note: _noteCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.of(context).pop();
      Get.snackbar('যোগ হয়েছে', '${_product!.name} × $qtyটি At Shop-এ যোগ হয়েছে',
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
          _handle(),
          _sheetHeader(
              'At Shop যোগ করুন', Icons.inventory_2_rounded, Colors.orange),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _pickProduct,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _product != null
                                ? Colors.orange
                                : scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: _product != null
                            ? Colors.orange.withAlpha(15)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 18,
                              color: _product != null
                                  ? Colors.orange
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _product?.name ?? 'প্রডাক্ট বেছে নিন *',
                              style: TextStyle(
                                  fontWeight: _product != null
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: _product != null
                                      ? Colors.orange
                                      : scheme.onSurfaceVariant),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                    DateFormat('dd MMM, yyyy').format(_date),
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'পরিমাণ',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'নোট (ঐচ্ছিক)',
                      prefixIcon:
                          const Icon(Icons.note_alt_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('সংরক্ষণ করুন'),
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
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════════════════════════════════════════

Widget _handle() {
  return Container(
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2)),
  );
}

Widget _sheetHeader(String title, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color)),
        ),
        IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(
                Get.context ?? Get.overlayContext!,
                rootNavigator: false)
                .pop()),
      ],
    ),
  );
}

Widget _productInfo(AdminReplaceModel e, ColorScheme scheme) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withAlpha(60),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${e.quantity}টি · ${e.statusLabel}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';

class DispatchHistoryView extends StatefulWidget {
  const DispatchHistoryView({super.key});
  @override
  State<DispatchHistoryView> createState() => _DispatchHistoryViewState();
}

class _DispatchHistoryViewState extends State<DispatchHistoryView> {
  final _db = FirebaseFirestore.instance;
  final orders = <OrderModel>[].obs;
  final loading = false.obs;
  final searchText = ''.obs;
  final NumberFormat _fmt = NumberFormat('#,##,##0');
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy, h:mm a');
  final DateFormat _dayFmt = DateFormat('dd MMM yyyy');

  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedProductId = '';
  String _selectedProductName = '';
  List<ProductModel> _allProducts = [];

  @override
  void initState() {
    super.initState();
    fetchOrders();
    loadProducts();
  }

  void loadProducts() {
    try {
      final pc = Get.find<ProductController>();
      if (pc.products.isNotEmpty) {
        _allProducts = List.from(pc.products)
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (_) {}
  }

  Future<void> fetchOrders() async {
    loading.value = true;
    try {
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();
      final list = snap.docs
          .map((e) => OrderModel.fromFirestore(e))
          .toList()
        ..sort((a, b) {
          final da = a.deliveredAt ?? a.createdAt;
          final db_ = b.deliveredAt ?? b.createdAt;
          return db_.compareTo(da);
        });
      orders.assignAll(list);
    } catch (_) {}
    loading.value = false;
  }

  List<OrderModel> get filteredOrders {
    var list = orders.toList();

    if (_selectedProductId.isNotEmpty) {
      list = list
          .where((o) =>
              o.items.any((item) => item.productId == _selectedProductId))
          .toList();
    }
    if (_fromDate != null) {
      list = list.where((o) {
        final d = o.deliveredAt ?? o.createdAt;
        return !d.isBefore(_fromDate!);
      }).toList();
    }
    if (_toDate != null) {
      list = list.where((o) {
        final d = o.deliveredAt ?? o.createdAt;
        final toEnd = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        return !d.isAfter(toEnd);
      }).toList();
    }

    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((o) =>
              o.shopName.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.shopPhone.contains(q) ||
              o.localMemo.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFilters = _fromDate != null || _toDate != null || _selectedProductId.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Text('Delivered (${filteredOrders.length})',
            style: const TextStyle(fontWeight: FontWeight.w800))),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded,
                color: hasFilters ? const Color(0xFF16A34A) : null),
            tooltip: 'ফিল্টার',
            onPressed: () => _showFilterSheet(scheme),
          ),
          Obx(() => loading.value
              ? const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.refresh_rounded),
                  onPressed: fetchOrders)),
        ],
      ),
      body: ResponsiveWrapper(child: Column(children: [
        if (hasFilters) _activeFilterChips(scheme),
        _quickDateChips(scheme),
        if (_selectedProductId.isNotEmpty) _productSummary(scheme),
        _searchBar(scheme),
        Expanded(child: Obx(() {
          final isSearching = searchText.value.trim().isNotEmpty;
          final showGrouped = _fromDate == null && _toDate == null && _selectedProductId.isEmpty && !isSearching;
          if (orders.isEmpty && loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, size: 56,
                    color: scheme.onSurface.withAlpha(60)),
                const SizedBox(height: 12),
                Text(_selectedProductId.isNotEmpty
                    ? '"$_selectedProductName" এর Delivered তথ্য নেই'
                    : 'কোনো Delivered অর্ডার নেই'),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: fetchOrders,
            child: showGrouped
                ? _buildGroupedList(scheme)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: filteredOrders.length,
                    itemBuilder: (_, i) => _orderCard(filteredOrders[i], scheme),
                  ),
          );
        })),
      ])),
    );
  }

  // ── Quick date chips ──────────────────────────────────────
  Widget _quickDateChips(ColorScheme scheme) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(height: 36, child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _dateChip('আজ', todayDate, todayDate),
          const SizedBox(width: 6),
          _dateChip('গতকাল', todayDate.subtract(const Duration(days: 1)), todayDate.subtract(const Duration(days: 1))),
          const SizedBox(width: 6),
          _dateChip('সপ্তাহ', todayDate.subtract(const Duration(days: 7)), todayDate),
          const SizedBox(width: 6),
          _dateChip('মাস', DateTime(today.year, today.month, 1), todayDate),
          const SizedBox(width: 6),
          _dateChip('সব', null, null),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.calendar_today_rounded, size: 16),
            label: const Text('কাস্টম', style: TextStyle(fontSize: 11)),
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _fromDate ?? today,
                firstDate: DateTime(2020),
                lastDate: today.add(const Duration(days: 1)),
              );
              if (p != null) setState(() { _fromDate = p; _toDate = p; });
            },
          ),
        ],
      )),
    );
  }

  Widget _dateChip(String label, DateTime? from, DateTime? to) {
    final active = _fromDate == from && _toDate == to;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
      selected: active,
      onSelected: (_) => setState(() { _fromDate = from; _toDate = to; }),
      selectedColor: const Color(0xFF16A34A).withAlpha(30),
      labelStyle: TextStyle(color: active ? const Color(0xFF16A34A) : null),
      side: active ? const BorderSide(color: Color(0xFF16A34A)) : null,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Active filter chips ───────────────────────────────────
  Widget _activeFilterChips(ColorScheme scheme) {
    final chips = <Widget>[];
    if (_fromDate != null || _toDate != null) {
      final l = '${_fromDate != null ? _dayFmt.format(_fromDate!) : 'শুরু'} → ${_toDate != null ? _dayFmt.format(_toDate!) : 'শেষ'}';
      chips.add(_chip(l, () => setState(() { _fromDate = null; _toDate = null; })));
    }
    if (_selectedProductId.isNotEmpty) {
      chips.add(_chip(_selectedProductName, () => setState(() {
        _selectedProductId = ''; _selectedProductName = '';
      })));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onDeleted: onRemove,
      backgroundColor: const Color(0xFF16A34A).withAlpha(20),
      side: BorderSide(color: const Color(0xFF16A34A).withAlpha(60)),
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Product summary ──────────────────────────────────────
  Widget _productSummary(ColorScheme scheme) {
    if (loading.value) return const SizedBox.shrink();
    int totalQty = 0;
    final customerData = <String, ({int qty, Set<String> memos})>{};
    for (final o in filteredOrders) {
      for (final item in o.items) {
        if (item.productId == _selectedProductId) {
          totalQty += item.quantity;
          final name = o.shopName.isNotEmpty ? o.shopName : 'Unknown';
          final memo = o.localMemo.isNotEmpty ? '#${o.localMemo}' : (o.memoNumber.isNotEmpty ? o.memoNumber : '');
          final entry = customerData[name] ?? (qty: 0, memos: <String>{});
          final updatedMemos = entry.memos;
          if (memo.isNotEmpty) updatedMemos.add(memo);
          customerData[name] = (qty: entry.qty + item.quantity, memos: updatedMemos);
        }
      }
    }
    final sorted = customerData.entries.toList()
      ..sort((a, b) => b.value.qty.compareTo(a.value.qty));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A).withAlpha(40)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Expanded(child: Text(_selectedProductName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          Text('$totalQtyটি • ${filteredOrders.length} অর্ডার • ${sorted.length} কাস্টমার',
              style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Divider(height: 1, color: const Color(0xFF16A34A).withAlpha(30)),
        const SizedBox(height: 6),
        ...sorted.map((e) {
          final memos = e.value.memos.isNotEmpty ? ' [${e.value.memos.join(', ')}]' : '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: e.key, style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(180))),
                    if (memos.isNotEmpty)
                      TextSpan(text: memos, style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(100))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${e.value.qty}টি', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Filter sheet ─────────────────────────────────────────
  void _showFilterSheet(ColorScheme scheme) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9,
          builder: (_, sc) => Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(controller: sc, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('ফিল্টার', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const Text('তারিখ রেঞ্জ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_fromDate != null ? _dayFmt.format(_fromDate!) : 'শুরু'),
                    onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: _fromDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) setSt(() => _fromDate = d);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_toDate != null ? _dayFmt.format(_toDate!) : 'শেষ'),
                    onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: _toDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) setSt(() => _toDate = d);
                    },
                  )),
                ]),
                const SizedBox(height: 16),
                const Text('প্রডাক্ট', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_allProducts.isEmpty)
                  const Text('লোড হচ্ছে...', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  _productPicker(setSt),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () {
                    setSt(() { _fromDate = null; _toDate = null; _selectedProductId = ''; _selectedProductName = ''; });
                  }, child: const Text('ক্লিয়ার'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(ctx); setState(() {}); },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('প্রয়োগ'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                  )),
                ]),
              ],
            )),
          ),
        );
      }),
    );
  }

  Widget _productPicker(StateSetter setSt) {
    String q = '';
    return StatefulBuilder(builder: (ctx, ss) {
      final f = q.isEmpty ? _allProducts.take(20).toList() :
          _allProducts.where((p) => p.name.toLowerCase().contains(q) || p.productCode.toLowerCase().contains(q)).take(20).toList();
      return Column(children: [
        TextField(
          decoration: InputDecoration(hintText: 'প্রডাক্ট খুঁজুন...', prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          onChanged: (v) => ss(() => q = v.trim().toLowerCase()),
        ),
        if (f.isNotEmpty)
          Container(constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(
            shrinkWrap: true, itemCount: f.length, itemBuilder: (_, i) {
              final p = f[i]; final sel = _selectedProductId == p.id;
              return ListTile(dense: true,
                leading: Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18,
                    color: sel ? const Color(0xFF16A34A) : Colors.grey),
                title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () => setSt(() => sel ? (_selectedProductId = '', _selectedProductName = '') : (_selectedProductId = p.id, _selectedProductName = p.name)),
              );
            },
          )),
      ]);
    });
  }

  // ── Search bar ────────────────────────────────────────────
  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TextField(
        onChanged: (v) => searchText.value = v,
        decoration: InputDecoration(hintText: 'কাস্টমার নাম বা Order ID...', prefixIcon: const Icon(Icons.search_rounded),
            filled: true, fillColor: scheme.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
      ),
    );
  }

  // ── Grouped list (when "সব" is selected) ──────────────────
  Map<String, List<OrderModel>> _groupByDate(List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (var o in orders) {
      final d = o.deliveredAt ?? o.createdAt;
      final date = DateFormat('dd MMMM yyyy').format(d);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }

  Widget _dateHeader(String date, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(date,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(ColorScheme scheme) {
    final grouped = _groupByDate(filteredOrders);
    final entries = grouped.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateHeader(entry.key, entry.value.length),
            ...entry.value.map((o) => _orderCard(o, scheme)),
          ],
        )).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: entries,
    );
  }

  // ── Order card ────────────────────────────────────────────
  Widget _orderCard(OrderModel order, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => OrderDetailsView(order: order)),
        child: IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: const Color(0xFF16A34A)),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order.shopName.isEmpty ? 'Unknown' : order.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (order.shopPhone.isNotEmpty)
                      Text(order.shopPhone, style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF16A34A).withAlpha(80))),
                    child: const Text('Delivered',
                        style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip2(Icons.tag_rounded, '#${order.id}', scheme),
                  if (order.memoNumber.isNotEmpty)
                    _chip2(Icons.receipt_long_rounded, 'মেমো: ${order.memoNumber}', scheme, labelColor: const Color(0xFFD97706)),
                  _chip2(Icons.shopping_bag_outlined, '${order.items.length} পণ্য', scheme),
                  if (order.deliveredAt != null)
                    _chip2(Icons.check_circle_rounded, _dayFmt.format(order.deliveredAt!), scheme, labelColor: const Color(0xFF16A34A)),
                  if (order.deductionAmount > 0)
                    _chip2(Icons.money_off_rounded, 'কাটা: ৳${_fmt.format(order.deductionAmount.toInt())}', scheme, labelColor: const Color(0xFFDC2626)),
                  if (order.returnAmount > 0)
                    _chip2(Icons.keyboard_return_rounded, 'ফেরত: ৳${_fmt.format(order.returnAmount.toInt())}', scheme, labelColor: const Color(0xFF8B5CF6)),
                  if (order.discountAmount > 0)
                    _chip2(Icons.discount_rounded, 'ডিসকাউন্ট: ৳${_fmt.format(order.discountAmount.toInt())}', scheme, labelColor: const Color(0xFFD97706)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(
                    order.items.take(2).map((i) => i.productName).join(', ') +
                        (order.items.length > 2 ? ' +${order.items.length - 2}' : ''),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140)),
                  )),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('৳ ${_fmt.format(order.totalAmount.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0891B2))),
                    Builder(builder: (_) {
                      final net = (order.totalAmount.toInt() - order.deductionAmount.toInt() - order.returnAmount.toInt() - order.discountAmount.toInt()).clamp(0, 9999999);
                      num cost = 0;
                      try {
                        final pc = Get.find<ProductController>();
                        for (final item in order.items) {
                          num c = item.purchasePrice;
                          if (c <= 0) { final p = pc.products.firstWhereOrNull((p) => p.id == item.productId); if (p != null) c = p.purchasePrice; }
                          cost += c * item.quantity;
                        }
                      } catch (_) {}
                      final hasSr = order.deliveryAssignedSrId.isNotEmpty || order.deliveredBySrId.isNotEmpty;
                      final comm = (net * 0.06).round();
                      final profit = (net - cost.toInt() - (hasSr ? comm : 0)).clamp(0, 9999999);
                      return Text('লাভ: ৳${_fmt.format(profit)}',
                          style: TextStyle(fontSize: 10, color: profit > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)));
                    }),
                  ]),
                ]),
              ]),
            )),
          ],
        )),
      ),
    );
  }

  Widget _chip2(IconData icon, String label, ColorScheme scheme, {Color? labelColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: labelColor != null ? labelColor.withAlpha(18) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: labelColor != null ? Border.all(color: labelColor.withAlpha(80), width: 1) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: labelColor ?? scheme.onSurface.withAlpha(160)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: labelColor != null ? FontWeight.w700 : FontWeight.normal,
            color: labelColor ?? scheme.onSurface.withAlpha(180))),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../order/controller/order_controller.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';
import 'sr_panel_shell.dart';

class SrMyOrdersView extends StatefulWidget {
  const SrMyOrdersView({super.key});

  @override
  State<SrMyOrdersView> createState() => _SrMyOrdersViewState();
}

class _SrMyOrdersViewState extends State<SrMyOrdersView> {
  late final OrderController _orderCtrl;
  late final SrPanelController _srCtrl;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##,##0');

  // 0 = সব অর্ডার · 1 = আমার কাটা · 2 = নির্ধারিত ডেলিভারি
  int _tabIdx = 0;
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _orderCtrl = Get.find<OrderController>();
    _srCtrl = Get.find<SrPanelController>();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          _orderCtrl.hasMore.value) {
        _orderCtrl.fetchOrders(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────

  List<OrderModel> _filteredOrders(List<OrderModel> all) {
    final srDocId = _srCtrl.srDocId;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    List<OrderModel> base;
    switch (_tabIdx) {
      case 1:
        base = all
            .where((o) =>
                o.orderedBy == srDocId || o.deliveredBySrId == srDocId)
            .toList();
        break;
      case 2:
        base = all
            .where((o) => o.scheduledDeliveryDate != null)
            .toList()
          ..sort((a, b) {
            final da = DateTime(
                a.scheduledDeliveryDate!.year,
                a.scheduledDeliveryDate!.month,
                a.scheduledDeliveryDate!.day);
            final db = DateTime(
                b.scheduledDeliveryDate!.year,
                b.scheduledDeliveryDate!.month,
                b.scheduledDeliveryDate!.day);
            return da.compareTo(db);
          });
        break;
      default:
        base = List<OrderModel>.from(all);
    }

    if (_statusFilter != 'all') {
      base = base.where((o) => o.status == _statusFilter).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base
          .where((o) =>
              o.shopName.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.shopPhone.contains(q) ||
              o.userPhone.contains(q))
          .toList();
    }

    return base;
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Get.find<SrNavController>(tag: 'sr_nav').tabIndex.value = 1,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('নতুন অর্ডার',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('অর্ডার সমূহ',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${_orderCtrl.orders.length} টি অর্ডার',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withAlpha(160)),
                ),
              ],
            )),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: () {
              _orderCtrl.lastDoc = null;
              _orderCtrl.hasMore.value = true;
              _orderCtrl.fetchOrders();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                _tabChip('সব অর্ডার', 0, scheme),
                const SizedBox(width: 8),
                _tabChip('আমার কাটা', 1, scheme),
                const SizedBox(width: 8),
                _tabChip('নির্ধারিত ডেলিভারি', 2, scheme,
                    icon: Icons.local_shipping_rounded),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _searchBar(scheme),
          _statusChips(),
          Expanded(
            child: Obx(() {
              final orders = _filteredOrders(_orderCtrl.orders);
              if (orders.isEmpty && _orderCtrl.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tabIdx == 2
                            ? Icons.event_available_rounded
                            : Icons.receipt_long_rounded,
                        size: 60,
                        color: scheme.onSurface.withAlpha(60),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tabIdx == 2
                            ? 'কোনো নির্ধারিত ডেলিভারি নেই'
                            : 'কোনো অর্ডার পাওয়া যায়নি',
                        style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurface.withAlpha(120)),
                      ),
                    ],
                  ),
                );
              }

              final grouped = _tabIdx == 2
                  ? _groupByScheduledDate(orders)
                  : _groupByDate(orders);

              return RefreshIndicator(
                onRefresh: () async {
                  _orderCtrl.lastDoc = null;
                  _orderCtrl.hasMore.value = true;
                  await _orderCtrl.fetchOrders();
                },
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  children: [
                    ...grouped.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dateHeader(
                                entry.key, entry.value.length, scheme),
                            ...entry.value
                                .map((o) => _orderCard(o, scheme)),
                          ],
                        )),
                    if (_orderCtrl.loading.value)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────

  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Shop নাম, ফোন নং বা Order ID দিয়ে খুঁজুন…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // ── Status chips ───────────────────────────────────────────────

  Widget _statusChips() {
    const filters = [
      ('all', 'সব'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('delivered', 'Delivered'),
      ('cancelled', 'বাতিল'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters.map((pair) {
          final (val, label) = pair;
          final selected = _statusFilter == val;
          final color =
              val == 'all' ? const Color(0xFF0891B2) : _statusColor(val);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _statusFilter = val),
              selectedColor: color.withAlpha(30),
              checkmarkColor: color,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? color : null,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: selected
                  ? BorderSide(color: color, width: 1.5)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab chip ───────────────────────────────────────────────────

  Widget _tabChip(String label, int idx, ColorScheme scheme,
      {IconData? icon}) {
    final active = _tabIdx == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIdx = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: active ? scheme.onPrimary : scheme.onSurface),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date header ────────────────────────────────────────────────

  Widget _dateHeader(String date, int count, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(date,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order card ─────────────────────────────────────────────────

  Widget _orderCard(OrderModel order, ColorScheme scheme) {
    final srDocId = _srCtrl.srDocId;
    final statusColor = _statusColor(order.status);
    final time = DateFormat('h:mm a').format(order.createdAt);
    final isMyOrder =
        order.orderedBy == srDocId || order.deliveredBySrId == srDocId;
    final delivDate = order.scheduledDeliveryDate;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final delivDateOnly = delivDate != null
        ? DateTime(delivDate.year, delivDate.month, delivDate.day)
        : null;
    final isToday = delivDateOnly != null && delivDateOnly == todayDate;
    final isPast = delivDateOnly != null &&
        delivDateOnly.isBefore(todayDate) &&
        order.status != 'delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Get.to(
              () => OrderDetailsView(order: order, srDocId: srDocId));
          _orderCtrl.lastDoc = null;
          _orderCtrl.hasMore.value = true;
          _orderCtrl.fetchOrders();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status color strip (self-sizing)
            Container(
              width: 5,
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Content
            Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: shop name + "আমার" badge + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isMyOrder)
                                      Container(
                                        margin: const EdgeInsets.only(
                                            right: 6),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'আমার',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.primary),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        order.shopName.isEmpty
                                            ? 'Unknown Shop'
                                            : order.shopName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.shopPhone.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.storefront_rounded,
                                          size: 13,
                                          color: scheme.onSurface
                                              .withAlpha(140)),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.shopPhone,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurface
                                                .withAlpha(160)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(order.status, statusColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Row 2: meta chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip(Icons.tag_rounded, '#${order.id}', scheme),
                          _chip(Icons.schedule_rounded, time, scheme),
                          _chip(Icons.shopping_bag_outlined,
                              '${order.items.length} পণ্য', scheme),
                          if (order.userPhone.isNotEmpty)
                            _chip(Icons.phone_rounded, order.userPhone,
                                scheme),
                          if (order.userDue > 0)
                            _chip(
                              Icons.account_balance_wallet_outlined,
                              'বাকি: ৳${_fmt.format(order.userDue)}',
                              scheme,
                              labelColor: const Color(0xFFDC2626),
                            ),
                          if (delivDate != null)
                            _chip(
                              Icons.local_shipping_rounded,
                              isToday
                                  ? 'আজকের ডেলিভারি'
                                  : isPast
                                      ? 'মিস: ${DateFormat('dd MMM').format(delivDate)}'
                                      : 'ডেলিভারি: ${DateFormat('dd MMM').format(delivDate)}',
                              scheme,
                              labelColor: isToday
                                  ? const Color(0xFF0891B2)
                                  : isPast
                                      ? const Color(0xFFDC2626)
                                      : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Row 3: address + amount
                      Row(
                        children: [
                          if (order.shopAddress.isNotEmpty) ...[
                            Icon(Icons.location_on_outlined,
                                size: 13,
                                color: scheme.onSurface.withAlpha(120)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.shopAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        scheme.onSurface.withAlpha(140)),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF0891B2).withAlpha(18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '৳ ${_fmt.format(order.totalAmount.toInt())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0891B2),
                              ),
                            ),
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

  // ── Helpers ────────────────────────────────────────────────────

  Widget _statusBadge(String status, Color color) {
    final label = {
          'pending': 'Pending',
          'approved': 'Approved',
          'delivered': 'Delivered',
          'cancelled': 'Cancelled',
        }[status] ??
        (status.capitalizeFirst ?? status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme scheme,
      {Color? labelColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: labelColor != null
            ? labelColor.withAlpha(18)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: labelColor != null
            ? Border.all(color: labelColor.withAlpha(80), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: labelColor ?? scheme.onSurface.withAlpha(160)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: labelColor != null
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: labelColor ?? scheme.onSurface.withAlpha(180),
              )),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Map<String, List<OrderModel>> _groupByDate(List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (final o in orders) {
      final date = DateFormat('dd MMMM yyyy').format(o.createdAt);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }

  Map<String, List<OrderModel>> _groupByScheduledDate(
      List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (final o in orders) {
      final d = o.scheduledDeliveryDate!;
      final date = DateFormat('dd MMMM yyyy').format(d);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }
}

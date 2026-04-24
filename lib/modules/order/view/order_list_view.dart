import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/order_controller.dart';
import '../model/order_model.dart';
import 'order_details_view.dart';

class OrderListView extends StatefulWidget {
  const OrderListView({super.key});

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView> {
  final controller = Get.find<OrderController>();
  final ScrollController _scrollCtrl = ScrollController();
  final _fmt = NumberFormat('#,##,##0');

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          controller.hasMore.value) {
        controller.fetchOrders(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Orders',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${controller.filteredOrders.length} টি অর্ডার',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withAlpha(160)),
                ),
              ],
            )),
      ),
      body: Column(
        children: [
          _searchBar(scheme),
          _statusChips(),
          Expanded(
            child: Obx(() {
              final orders = controller.filteredOrders;
              if (orders.isEmpty && controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 56,
                          color: scheme.onSurface.withAlpha(60)),
                      const SizedBox(height: 12),
                      Text('কোনো অর্ডার পাওয়া যায়নি',
                          style: TextStyle(
                              color: scheme.onSurface.withAlpha(120))),
                    ],
                  ),
                );
              }

              final grouped = _groupByDate(orders);
              return RefreshIndicator(
                onRefresh: () async {
                  controller.lastDoc = null;
                  controller.hasMore.value = true;
                  await controller.fetchOrders();
                },
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    ...grouped.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dateHeader(entry.key, entry.value.length),
                            ...entry.value
                                .map((o) => _orderCard(o, scheme)),
                          ],
                        )),
                    if (controller.loading.value)
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
        onChanged: (v) => controller.searchText.value = v,
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

  // ── Horizontal status chips ────────────────────────────────────

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
      child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: filters.map((pair) {
              final (val, label) = pair;
              final selected = controller.selectedStatus.value == val;
              final color = val == 'all'
                  ? const Color(0xFF0891B2)
                  : _statusColor(val);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => controller.changeFilter(val),
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
          )),
    );
  }

  // ── Date group header ──────────────────────────────────────────

  Widget _dateHeader(String date, int count) {
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order card ─────────────────────────────────────────────────

  Widget _orderCard(OrderModel order, ColorScheme scheme) {
    final statusColor = _statusColor(order.status);
    final time = DateFormat('h:mm a').format(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Get.to(() => OrderDetailsView(order: order));
          controller.lastDoc = null;
          controller.hasMore.value = true;
          controller.fetchOrders();
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status color strip on left
              Container(width: 5, color: statusColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: shop info + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.shopName.isEmpty
                                      ? 'Unknown Shop'
                                      : order.shopName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
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
                          _chip(
                              Icons.tag_rounded,
                              order.id.length > 8
                                  ? '#${order.id.substring(0, 8)}'
                                  : '#${order.id}',
                              scheme),
                          _chip(Icons.schedule_rounded, time, scheme),
                          _chip(Icons.shopping_bag_outlined,
                              '${order.items.length} পণ্য', scheme),
                          if (order.userPhone.isNotEmpty)
                            _chip(Icons.phone_rounded,
                                order.userPhone, scheme),
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
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurface.withAlpha(160)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withAlpha(180))),
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
    for (var o in orders) {
      final date = DateFormat('dd MMMM yyyy').format(o.createdAt);
      map.putIfAbsent(date, () => []).add(o);
    }
    return map;
  }
}
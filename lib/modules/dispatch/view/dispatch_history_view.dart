import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';
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

  @override
  void initState() {
    super.initState();
    fetchDispatchedOrders();
  }

  Future<void> fetchDispatchedOrders() async {
    loading.value = true;
    try {
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'dispatched')
          .orderBy('dispatchedAt', descending: true)
          .get();

      orders.assignAll(snap.docs.map((e) => OrderModel.fromFirestore(e)).toList());
    } catch (_) {
      // Try fallback without ordering
      try {
        final snap = await _db
            .collection('orders')
            .where('status', isEqualTo: 'dispatched')
            .get();
        final list = snap.docs.map((e) => OrderModel.fromFirestore(e)).toList()
          ..sort((a, b) {
            final da = a.dispatchedAt ?? a.createdAt;
            final db_ = b.dispatchedAt ?? b.createdAt;
            return db_.compareTo(da);
          });
        orders.assignAll(list);
      } catch (_) {}
    }
    loading.value = false;
  }

  List<OrderModel> get filteredOrders {
    var list = orders.toList();
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) =>
        o.shopName.toLowerCase().contains(q) ||
        o.id.toLowerCase().contains(q) ||
        o.shopPhone.contains(q) ||
        o.memoNumber.toLowerCase().contains(q)
      ).toList();
    }
    return list;
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
                const Text('Dispatch History', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${filteredOrders.length} টি Dispatched অর্ডার',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
              ],
            )),
      ),
      body: ResponsiveWrapper(child: Column(
        children: [
          _searchBar(scheme),
          Expanded(child: Obx(() {
            if (orders.isEmpty && loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (filteredOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 56, color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('কোনো Dispatched অর্ডার পাওয়া যায়নি',
                        style: TextStyle(color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => fetchDispatchedOrders(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: filteredOrders.length,
                itemBuilder: (_, i) => _dispatchedOrderCard(filteredOrders[i], scheme),
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
        onChanged: (v) => searchText.value = v,
        decoration: InputDecoration(
          hintText: 'কাস্টমার নাম, মেমো নাম্বার বা Order ID দিয়ে খুঁজুন…',
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

  Widget _dispatchedOrderCard(OrderModel order, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => OrderDetailsView(order: order)),
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
                                Text(order.shopName.isEmpty ? 'Unknown Shop' : order.shopName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                if (order.shopPhone.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(order.shopPhone,
                                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
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
                                child: const Text('Dispatched',
                                    style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip(Icons.tag_rounded, '#${order.id}', scheme),
                          _chip(Icons.receipt_long_rounded, 'মেমো: ${order.memoNumber}', scheme,
                              labelColor: const Color(0xFFD97706)),
                          _chip(Icons.shopping_bag_outlined, '${order.items.length} পণ্য', scheme),
                          if (order.dispatchedAt != null)
                            _chip(Icons.access_time_rounded, _dateFmt.format(order.dispatchedAt!), scheme),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.items.take(2).map((i) => i.productName).join(', ') +
                                  (order.items.length > 2 ? ' +${order.items.length - 2} more' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0891B2).withAlpha(18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '৳ ${_fmt.format(order.totalAmount.toInt())}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0891B2)),
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
}

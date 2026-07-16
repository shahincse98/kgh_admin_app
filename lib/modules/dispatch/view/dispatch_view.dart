import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/dispatch_controller.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';
import '../../../widgets/responsive.dart';

class DispatchView extends GetView<DispatchController> {
  const DispatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##,##0');

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('স্টক আউট / Dispatch',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${controller.filteredOrders.length} টি অর্ডার (Pending / Approved / Delivered w/o Dispatch)',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160)),
                ),
              ],
            )),
        actions: [
          Obx(() {
            final count = controller.selectedOrderIds.length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showBulkDispatchDialog(scheme),
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: Text('Dispatch ($count)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }),
        ],
      ),
      body: ResponsiveWrapper(child: Column(
        children: [
          _searchBar(scheme),
          _selectAllBar(scheme),
          Expanded(child: Obx(() {
            final orders = controller.filteredOrders;
            if (orders.isEmpty && controller.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 56, color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('Dispatch করার মতো কোনো Approved অর্ডার নেই',
                        style: TextStyle(color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => controller.fetchDispatchableOrders(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: orders.length,
                itemBuilder: (_, i) => _dispatchOrderCard(orders[i], scheme, fmt),
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
          hintText: 'কাস্টমার নাম, Order ID বা মেমো নাম্বার দিয়ে খুঁজুন…',
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

  Widget _selectAllBar(ColorScheme scheme) {
    return Obx(() {
      if (controller.orders.isEmpty) return const SizedBox.shrink();
      final allSelected = controller.selectedOrderIds.length == controller.orders.length &&
          controller.orders.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => controller.selectAll(),
              icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
              label: Text(allSelected ? 'সব বাতিল' : 'সব সিলেক্ট'),
            ),
            const Spacer(),
            if (controller.selectedOrderIds.isNotEmpty)
              Text('${controller.selectedOrderIds.length} টি সিলেক্ট | ${controller.totalItems} টি প্রডাক্ট',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
          ],
        ),
      );
    });
  }

  Widget _dispatchOrderCard(OrderModel order, ColorScheme scheme, NumberFormat fmt) {
    final isSelected = controller.selectedOrderIds.contains(order.id);
    final time = DateFormat('dd MMM yyyy, h:mm a').format(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: Color(0xFFD97706), width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Get.to(() => OrderDetailsView(order: order));
          controller.fetchDispatchableOrders();
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: isSelected ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => controller.toggleSelection(order.id),
                            activeColor: const Color(0xFFD97706),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
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
                                  color: const Color(0xFF2563EB).withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Approved',
                                    style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                              const SizedBox(height: 4),
                              Text(time, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
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
                          _chip(Icons.shopping_bag_outlined, '${order.items.length} পণ্য', scheme),
                          if (order.deliveryAssignedSrName.isNotEmpty)
                            _chip(Icons.person_pin_rounded, order.deliveryAssignedSrName, scheme, labelColor: const Color(0xFF7C3AED)),
                          if (order.scheduledDeliveryDate != null)
                            _chip(Icons.calendar_month_rounded,
                                DateFormat('dd MMM').format(order.scheduledDeliveryDate!), scheme,
                                labelColor: const Color(0xFF0891B2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.items.take(3).map((i) => i.productName).join(', ') +
                                  (order.items.length > 3 ? ' +${order.items.length - 3} more' : ''),
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
                              '৳ ${fmt.format(order.totalAmount.toInt())}',
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

  Future<void> _showBulkDispatchDialog(ColorScheme scheme) async {
    final memoCtrl = TextEditingController(
      text: '#MEM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Text('বাল্ক Dispatch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('অর্ডার সংখ্যা', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      Text('${controller.selectedOrderIds.length} টি',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('প্রডাক্ট সংখ্যা', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      Text('${controller.totalItems} টি',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('মেমো / চালান নাম্বার',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 4),
              TextField(
                controller: memoCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'সকল অর্ডারের জন্য মেমো নাম্বার',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'সতর্কতা: ${controller.selectedOrderIds.length} টি অর্ডার Dispatch করলে স্টক কেটে যাবে।',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text('${controller.selectedOrderIds.length} টি Dispatch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final memo = memoCtrl.text.trim();
      if (memo.isEmpty) {
        Get.snackbar('ত্রুটি', 'মেমো নাম্বার দিতে হবে',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      Get.snackbar('প্রক্রিয়াধীন', 'Dispatch করা হচ্ছে…',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFD97706), colorText: Colors.white);
      await controller.dispatchSelected(memoNumber: memo);
      Get.closeCurrentSnackbar();
      Get.snackbar('সফল', '${controller.selectedOrderIds.length} টি অর্ডার Dispatch হয়েছে\nমেমো: $memo',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
    }
    memoCtrl.dispose();
  }
}

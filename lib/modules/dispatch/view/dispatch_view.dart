import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/dispatch_controller.dart';
import '../../order/model/order_model.dart';
import '../../order/view/order_details_view.dart';
import '../../../widgets/responsive.dart';
import '../../../localization/domain_labels.dart';
import '../../product/controller/product_controller.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';

class DispatchView extends GetView<DispatchController> {
  const DispatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##,##0');

    return Scaffold(
      drawer: appDrawerFor(context),
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'স্টক আউট / Dispatch'.tr,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              // সরু স্ক্রিনে বন্ধনীর ব্যাখ্যাটুকু বাদ যায়, নইলে শিরোনাম কেটে যায়
              Text(
                MediaQuery.sizeOf(context).width < 600
                    ? '${controller.filteredOrders.length} ${'টি অর্ডার'.tr}'
                    : '${controller.filteredOrders.length} ${'টি অর্ডার'.tr} (Pending / Approved / Delivered w/o Dispatch)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
        ),
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
      body: ResponsiveWrapper(
        child: Column(
          children: [
            _searchBar(scheme),
            _deliveredToggle(scheme),
            _selectAllBar(scheme),
            Expanded(
              child: Obx(() {
                final orders = controller.filteredOrders;
                if (orders.isEmpty && controller.loading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (orders.isEmpty && controller.loadError.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text('তালিকা লোড হয়নি'.tr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(controller.loadError.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: controller.fetchDispatchableOrders,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('আবার চেষ্টা করুন'.tr),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 56,
                          color: scheme.onSurface.withAlpha(60),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dispatch করার মতো কোনো Approved অর্ডার নেই'.tr,
                          style: TextStyle(
                            color: scheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Flat list of date headers and cards, built lazily — the
                // queue can hold thousands of orders.
                final rows = <Object>[];
                for (final entry in _groupByDate(orders).entries) {
                  rows.add(_DateGroup(entry.key, entry.value));
                  rows.addAll(entry.value);
                }
                return RefreshIndicator(
                  onRefresh: () => controller.fetchDispatchableOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      if (row is _DateGroup) {
                        return _dateHeader(row.date, row.orders, scheme, fmt);
                      }
                      return _dispatchOrderCard(row as OrderModel, scheme, fmt);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Current purchase price of a product, for items saved without one.
  num _productCost(String productId) {
    try {
      return Get.find<ProductController>()
              .products
              .firstWhereOrNull((p) => p.id == productId)
              ?.purchasePrice ??
          0;
    } catch (_) {
      return 0;
    }
  }

  Map<String, List<OrderModel>> _groupByDate(List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (final o in orders) {
      map.putIfAbsent(DateFormat('dd MMMM yyyy').format(o.createdAt), () => [])
          .add(o);
    }
    return map;
  }

  /// Date header with the day's sale total, expected profit and margin.
  Widget _dateHeader(String date, List<OrderModel> orders, ColorScheme scheme,
      NumberFormat fmt) {
    final total = orders.fold<num>(0, (s, o) => s + o.totalAmount);
    final sellable =
        orders.where((o) => !o.isDueCollection && o.items.isNotEmpty);
    final profit = sellable.fold<num>(0, (s, o) => s + o.profit(_productCost));
    final netSales = sellable.fold<num>(0, (s, o) => s + o.netSales);
    final rate = netSales > 0 ? profit / netSales * 100 : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(date,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${orders.length}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer)),
          ),
          _statPill(Icons.shopping_cart_rounded, '৳ ${fmt.format(total.round())}',
              const Color(0xFF0891B2)),
          if (sellable.isNotEmpty)
            _statPill(
              Icons.savings_rounded,
              '${'সম্ভাব্য লাভ'.tr}: ৳ ${fmt.format(profit.round())}'
              '${netSales > 0 ? ' (${rate.toStringAsFixed(1)}%)' : ''}',
              profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: InputDecoration(
          hintText: 'কাস্টমার নাম, Order ID বা মেমো নাম্বার দিয়ে খুঁজুন…'.tr,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  /// Delivered-without-dispatch orders are usually old paperwork, so they
  /// are shown only on demand.
  Widget _deliveredToggle(ColorScheme scheme) {
    return Obx(() {
      final count = controller.deliveredWithoutDispatchCount.value;
      if (count == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(children: [
          Expanded(
            child: Text(
              '${'ডেলিভার্ড কিন্তু ডিসপ্যাচ হয়নি'.tr} ($count) — ${'শেষ ৩০ দিন'.tr}',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurface.withAlpha(160)),
            ),
          ),
          Switch(
            value: controller.showDeliveredWithoutDispatch.value,
            onChanged: controller.toggleDeliveredWithoutDispatch,
          ),
        ]),
      );
    });
  }

  Widget _selectAllBar(ColorScheme scheme) {
    return Obx(() {
      if (controller.orders.isEmpty) return const SizedBox.shrink();
      final allSelected =
          controller.selectedOrderIds.length == controller.orders.length &&
          controller.orders.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => controller.selectAll(),
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(allSelected ? 'সব বাতিল'.tr : 'সব সিলেক্ট'.tr),
            ),
            const Spacer(),
            if (controller.selectedOrderIds.isNotEmpty)
              Text(
                '${controller.selectedOrderIds.length} ${'টি সিলেক্ট'.tr} | ${controller.totalItems} ${'টি প্রডাক্ট'.tr}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _dispatchOrderCard(
    OrderModel order,
    ColorScheme scheme,
    NumberFormat fmt,
  ) {
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
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? const Color(0xFFD97706)
                    : const Color(0xFF2563EB),
                width: 5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            onChanged: (_) =>
                                controller.toggleSelection(order.id),
                            activeColor: const Color(0xFFD97706),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.shopName.isEmpty
                                      ? 'Unknown Shop'.tr
                                      : order.shopName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (order.shopPhone.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    order.shopPhone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurface.withAlpha(160),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Approved'.tr,
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface.withAlpha(120),
                                ),
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
                          _chip(
                            Icons.shopping_bag_outlined,
                            DomainLabels.productCount(order.items.length),
                            scheme,
                          ),
                          if (order.deliveryAssignedSrName.isNotEmpty)
                            _chip(
                              Icons.person_pin_rounded,
                              order.deliveryAssignedSrName,
                              scheme,
                              labelColor: const Color(0xFF7C3AED),
                            ),
                          if (order.scheduledDeliveryDate != null)
                            _chip(
                              Icons.calendar_month_rounded,
                              DateFormat(
                                'dd MMM',
                              ).format(order.scheduledDeliveryDate!),
                              scheme,
                              labelColor: const Color(0xFF0891B2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Every product with its own profit, so it is clear
                      // what this dispatch earns (or loses).
                      ...order.items.map((i) {
                        final cost = i.purchasePrice > 0
                            ? i.purchasePrice
                            : _productCost(i.productId);
                        final lineProfit = i.totalPrice - cost * i.quantity;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                '${i.productName}  ${i.quantity} × ৳${fmt.format(i.pricePerUnit.round())}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface.withAlpha(150)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (cost > 0)
                              Text(
                                '${'লাভ'.tr} ৳${fmt.format(lineProfit.round())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: lineProfit >= 0
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              )
                            else
                              Text('${'ক্রয়মূল্য নেই'.tr}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFFDC2626))),
                            const SizedBox(width: 8),
                            Text('৳ ${fmt.format(i.totalPrice.round())}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0891B2))),
                          ]),
                        );
                      }),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Whole-order profit (after discount, replace, return).
                          if (!order.isDueCollection && order.items.isNotEmpty)
                            Builder(builder: (_) {
                              final p = order.profit(_productCost);
                              return _statPill(
                                Icons.savings_rounded,
                                '${'মোট লাভ'.tr}: ৳ ${fmt.format(p.round())}',
                                p >= 0
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              );
                            }),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0891B2).withAlpha(18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '৳ ${fmt.format(order.totalAmount.toInt())}',
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

  Widget _chip(
    IconData icon,
    String label,
    ColorScheme scheme, {
    Color? labelColor,
  }) {
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
          Icon(
            icon,
            size: 13,
            color: labelColor ?? scheme.onSurface.withAlpha(160),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: labelColor != null
                  ? FontWeight.w700
                  : FontWeight.normal,
              color: labelColor ?? scheme.onSurface.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkDispatchDialog(ColorScheme scheme) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              Icons.local_shipping_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'বাল্ক Dispatch'.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'অর্ডার সংখ্যা'.tr,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        Text(
                          '${controller.selectedOrderIds.length} ${'টি'.tr}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'প্রডাক্ট সংখ্যা'.tr,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        Text(
                          '${controller.totalItems} ${'টি'.tr}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${'সতর্কতা'.tr}: ${controller.selectedOrderIds.length} ${'টি অর্ডার'.tr} Dispatch ${'করলে স্টক কেটে যাবে'.tr}।',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('বাতিল'.tr),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(
              '${controller.selectedOrderIds.length} ${'টি'.tr} Dispatch',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Get.snackbar(
        'প্রক্রিয়াধীন'.tr,
        'Dispatch করা হচ্ছে…'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFD97706),
        colorText: Colors.white,
      );
      await controller.dispatchSelected();
      Get.closeCurrentSnackbar();
      Get.snackbar(
        'সফল'.tr,
        '${controller.selectedOrderIds.length} ${'টি অর্ডার'.tr} Dispatch হয়েছে',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
    }
  }
}

/// A date header row in the dispatch list.
class _DateGroup {
  final String date;
  final List<OrderModel> orders;
  const _DateGroup(this.date, this.orders);
}

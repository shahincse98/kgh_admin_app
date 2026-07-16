import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import 'stock_in_detail_view.dart';
import '../../../widgets/responsive.dart';

class StockInHistoryView extends GetView<StockInController> {
  const StockInHistoryView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

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
                const Text('স্টক ইন ইতিহাস',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${controller.filteredGroups.length} টি এন্ট্রি',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurface.withAlpha(160))),
              ],
            )),
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            _searchBar(scheme),
            _summaryBar(scheme),
            Expanded(
              child: Obx(() {
                final groups = controller.filteredGroups;
                if (groups.isEmpty && controller.loading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 56, color: scheme.onSurface.withAlpha(60)),
                        const SizedBox(height: 12),
                        Text('কোনো এন্ট্রি পাওয়া যায়নি',
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(120))),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => controller.fetchEntries(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: groups.length,
                    itemBuilder: (_, i) => _groupListItem(groups[i], scheme),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: InputDecoration(
          hintText: 'প্রডাক্ট নাম, সোর্স বা নোট দিয়ে খুঁজুন…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _summaryBar(ColorScheme scheme) {
    return Obx(() {
      if (controller.totalEntries == 0) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF16A34A).withAlpha(40)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('মোট কেনা',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                  Text(
                    '৳ ${_fmt.format(controller.totalPurchaseValue.toInt())}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${controller.totalEntries} এন্ট্রি',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534))),
                Text('${controller.totalQuantity} pcs',
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withAlpha(140))),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _groupListItem(StockInGroup group, ColorScheme scheme) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final dayFmt = DateFormat('dd');
    final monFmt = DateFormat('MMM');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Get.to(() => StockInDetailView(group: group));
          controller.fetchEntries();
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date strip
              Container(
                width: 56,
                color: const Color(0xFF16A34A).withAlpha(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayFmt.format(group.date),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A))),
                    Text(monFmt.format(group.date).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: source + date
                      Row(
                        children: [
                          if (group.source.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0891B2).withAlpha(18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 12, color: Color(0xFF0891B2)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(group.source,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0891B2)),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Text(dateFmt.format(group.date),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface.withAlpha(140))),
                          const Spacer(),
                          Text(
                            '৳ ${_fmt.format(group.totalValue.toInt())}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: product count + qty
                      Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 14, color: scheme.onSurface.withAlpha(120)),
                          const SizedBox(width: 4),
                          Text(
                            '${group.entries.length} প্রডাক্ট • ${group.totalQty} pcs',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withAlpha(180)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 3: product names preview
                      Text(
                        group.entries
                            .take(3)
                            .map((e) => e.productName)
                            .join(', ') +
                            (group.entries.length > 3
                                ? ' +${group.entries.length - 3} more'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withAlpha(140)),
                      ),
                      if (group.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.note_rounded,
                                size: 12, color: scheme.onSurface.withAlpha(100)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(group.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withAlpha(120))),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Chevron
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

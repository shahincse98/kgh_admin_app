import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import '../../product/controller/product_controller.dart';
import 'stock_in_detail_view.dart';
import '../../../widgets/responsive.dart';

class StockInHistoryView extends GetView<StockInController> {
  const StockInHistoryView({super.key});

  static final _fmt = NumberFormat('#,##,##0');
  static final _dayFmt = DateFormat('dd MMM yyyy');

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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'ফিল্টার',
            onPressed: () => _showFilterSheet(scheme),
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            _searchBar(scheme),
            _quickDateChips(scheme),
            _activeFilterChips(scheme),
            Obx(() {
              if (controller.selectedProductId.value.isNotEmpty) {
                return _productSummary(scheme);
              }
              return const SizedBox.shrink();
            }),
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
                  onRefresh: () => controller.fetchEntries(force: true),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: InputDecoration(
          hintText: 'প্রডাক্ট নাম, সোর্স বা নোট দিয়ে খুঁজুন…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Obx(() => controller.searchText.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => controller.searchText.value = '',
                )
              : const SizedBox.shrink()),
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

  Widget _quickDateChips(ColorScheme scheme) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final ctx = Get.context!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _dateChip('আজ', todayDate, todayDate),
            const SizedBox(width: 6),
            _dateChip('গতকাল', todayDate.subtract(const Duration(days: 1)),
                todayDate.subtract(const Duration(days: 1))),
            const SizedBox(width: 6),
            _dateChip('সপ্তাহ',
                todayDate.subtract(const Duration(days: 7)), todayDate),
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
                  context: ctx,
                  initialDate: controller.fromDate.value ?? today,
                  firstDate: DateTime(2020),
                  lastDate: today.add(const Duration(days: 1)),
                );
                if (p != null) {
                  controller.fromDate.value = p;
                  controller.toDate.value = p;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String label, DateTime? from, DateTime? to) {
    return Obx(() {
      final active = controller.fromDate.value == from &&
          controller.toDate.value == to;
      return ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
        selected: active,
        onSelected: (_) {
          controller.fromDate.value = from;
          controller.toDate.value = to;
        },
        selectedColor: const Color(0xFF16A34A).withAlpha(30),
        labelStyle:
            TextStyle(color: active ? const Color(0xFF16A34A) : null),
        side: active ? const BorderSide(color: Color(0xFF16A34A)) : null,
        visualDensity: VisualDensity.compact,
      );
    });
  }

  Widget _activeFilterChips(ColorScheme scheme) {
    return Obx(() {
      final chips = <Widget>[];
      if (controller.fromDate.value != null ||
          controller.toDate.value != null) {
        final from = controller.fromDate.value;
        final to = controller.toDate.value;
        final l =
            '${from != null ? _dayFmt.format(from) : 'শুরু'} → ${to != null ? _dayFmt.format(to) : 'শেষ'}';
        chips.add(_chip(l, () {
          controller.fromDate.value = null;
          controller.toDate.value = null;
        }));
      }
      if (controller.selectedProductId.value.isNotEmpty) {
        chips.add(_chip(controller.selectedProductName.value, () {
          controller.selectedProductId.value = '';
          controller.selectedProductName.value = '';
        }));
      }
      if (chips.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Wrap(spacing: 8, runSpacing: 4, children: chips),
      );
    });
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

  Widget _productSummary(ColorScheme scheme) {
    return Obx(() {
      final pid = controller.selectedProductId.value;
      final pname = controller.selectedProductName.value;
      if (pid.isEmpty) return const SizedBox.shrink();
      final filtered = controller.filteredEntries;
      final totalQty = filtered.fold(0, (s, e) => s + e.quantity);
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF16A34A).withAlpha(40)),
        ),
        child: Row(children: [
          const Icon(Icons.inventory_2_rounded,
              size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(pname,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800))),
          Text('$totalQty pcs • ${filtered.length} এন্ট্রি',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w600)),
        ]),
      );
    });
  }

  void _showFilterSheet(ColorScheme scheme) {
    final ctx = Get.context!;
    DateTime? tempFrom = controller.fromDate.value;
    DateTime? tempTo = controller.toDate.value;
    String tempProductId = controller.selectedProductId.value;
    String tempProductName = controller.selectedProductName.value;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final searchCtrl = TextEditingController();
        final scrollCtrl = ScrollController();
        List<dynamic> products = [];
        try {
          final pc = Get.find<ProductController>();
          products = pc.products;
        } catch (_) {}

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          builder: (_, sc) => Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              controller: sc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('ফিল্টার',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  const Text('তারিখ রেঞ্জ',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(tempFrom != null
                          ? _dayFmt.format(tempFrom!)
                          : 'শুরু'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: tempFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setSt(() => tempFrom = d);
                      },
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                          tempTo != null ? _dayFmt.format(tempTo!) : 'শেষ'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: tempTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setSt(() => tempTo = d);
                      },
                    )),
                  ]),
                  const SizedBox(height: 20),
                  const Text('প্রডাক্ট',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'প্রডাক্ট খুঁজুন…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setSt(() {}),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: ListView(controller: scrollCtrl, children: [
                      ...products.where((p) {
                        final q =
                            searchCtrl.text.trim().toLowerCase();
                        if (q.isEmpty) return true;
                        final name = (p.name ?? '').toString();
                        final code = (p.productCode ?? '').toString();
                        return name.toLowerCase().contains(q) ||
                            code.toLowerCase().contains(q);
                      }).take(30).map((p) {
                        final pid = (p.id ?? '').toString();
                        final pname = (p.name ?? '').toString();
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            tempProductId == pid
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: tempProductId == pid
                                ? const Color(0xFF16A34A)
                                : Colors.grey,
                          ),
                          title: Text(pname, style: const TextStyle(fontSize: 13)),
                          onTap: () => setSt(() {
                            tempProductId = pid;
                            tempProductName = pname;
                          }),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () {
                        setSt(() {
                          tempFrom = null;
                          tempTo = null;
                          tempProductId = '';
                          tempProductName = '';
                        });
                      },
                      child: const Text('ক্লিয়ার'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                      onPressed: () {
                        controller.fromDate.value = tempFrom;
                        controller.toDate.value = tempTo;
                        controller.selectedProductId.value = tempProductId;
                        controller.selectedProductName.value = tempProductName;
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('প্রয়োগ'),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              size: 14,
                              color: scheme.onSurface.withAlpha(120)),
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
                                size: 12,
                                color: scheme.onSurface.withAlpha(100)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(group.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          scheme.onSurface.withAlpha(120))),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

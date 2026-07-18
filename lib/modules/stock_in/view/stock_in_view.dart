import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import 'stock_in_detail_view.dart';
import '../../../widgets/responsive.dart';

class StockInView extends StatefulWidget {
  const StockInView({super.key});

  @override
  State<StockInView> createState() => _StockInViewState();
}

class _StockInViewState extends State<StockInView> {
  final controller = Get.find<StockInController>();
  final pc = Get.find<ProductController>();
  static final _fmt = NumberFormat('#,##,##0');

  @override
  void initState() {
    super.initState();
    if (controller.entries.isEmpty) controller.fetchEntries();
    if (pc.products.isEmpty) pc.fetchProducts();
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
                const Text('স্টক ইন',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${controller.filteredGroups.length} টি এন্ট্রি',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurface.withAlpha(160))),
              ],
            )),
        actions: [
          Obx(() => controller.loading.value
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => controller.fetchEntries(),
                )),
        ],
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
                        Text('কোনো স্টক ইন এন্ট্রি নেই',
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(120))),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => controller.fetchEntries(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: groups.length,
                    itemBuilder: (_, i) => _groupListItem(groups[i], scheme),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStockInSheet(context, scheme),
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('স্টক ইন যোগ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  // ── Add Stock-In Bottom Sheet ─────────────────────────────────

  void _showAddStockInSheet(BuildContext context, ColorScheme scheme) {
    final dateCtrl = TextEditingController(
        text: DateFormat('dd MMM yyyy').format(DateTime.now()));
    final sourceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final selectedItems = <_CartItem>[].obs;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          int totalQty() => selectedItems.fold(0, (s, i) => s + i.quantity);
          num totalValue() => selectedItems.fold(0, (s, i) => s + i.totalPrice);

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('নতুন স্টক ইন',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800))),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        for (final item in selectedItems) {
                          item.dispose();
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date + Source
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('তারিখ',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: dateCtrl,
                                        readOnly: true,
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: selectedDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now()
                                                .add(const Duration(days: 1)),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              selectedDate = picked;
                                              dateCtrl.text =
                                                  DateFormat('dd MMM yyyy')
                                                      .format(picked);
                                            });
                                          }
                                        },
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 20),
                                          filled: true,
                                          fillColor: scheme.surfaceContainerHigh,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('সোর্স (কোথা থেকে)',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: sourceCtrl,
                                        decoration: InputDecoration(
                                          hintText: 'যেমন: ঢাকা, চট্টগ্রাম',
                                          prefixIcon: const Icon(
                                              Icons.location_on_rounded,
                                              size: 20),
                                          filled: true,
                                          fillColor: scheme.surfaceContainerHigh,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('নোট (ঐচ্ছিক)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey)),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: noteCtrl,
                                decoration: InputDecoration(
                                  hintText: 'কোনো নোট থাকলে লিখুন',
                                  filled: true,
                                  fillColor: scheme.surfaceContainerHigh,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Products
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('প্রডাক্ট সিলেক্ট করুন',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                  const Spacer(),
                                  Obx(() => selectedItems.isEmpty
                                      ? const SizedBox.shrink()
                                      : Text(
                                          '${selectedItems.length} টি | ${totalQty()} pcs | ৳${_fmt.format(totalValue().toInt())}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF16A34A),
                                              fontWeight: FontWeight.w600))),
                                ]),
                                const SizedBox(height: 8),
                                Obx(() {
                                  if (selectedItems.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: Text(
                                            'কোনো প্রডাক্ট যোগ করা হয়নি',
                                            style: TextStyle(
                                                color: scheme.onSurface
                                                    .withAlpha(100),
                                                fontSize: 13)),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: selectedItems
                                        .asMap()
                                        .entries
                                        .map((e) {
                                      final idx = e.key;
                                      final item = e.value;
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHigh
                                              .withAlpha(120),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  item.image,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: scheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                        Icons
                                                            .image_not_supported_rounded,
                                                        size: 16),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item.name,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                    Text('স্টক: ${item.stock}',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: scheme
                                                                .onSurface
                                                                .withAlpha(120))),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18),
                                                color: Colors.red.shade400,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  item.dispose();
                                                  selectedItems.removeAt(idx);
                                                },
                                              ),
                                            ]),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _qtyBtn(
                                                      Icons.remove_rounded,
                                                      () {
                                                    if (item.quantity > 1) {
                                                      item.quantity--;
                                                      selectedItems.refresh();
                                                    } else {
                                                      item.dispose();
                                                      selectedItems
                                                          .removeAt(idx);
                                                    }
                                                  }),
                                                  SizedBox(
                                                    width: 42,
                                                    child: TextField(
                                                      controller:
                                                          TextEditingController(
                                                              text:
                                                                  '${item.quantity}'),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 14),
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        isDense: true,
                                                      ),
                                                      onChanged: (v) {
                                                        final q =
                                                            int.tryParse(v);
                                                        if (q != null &&
                                                            q > 0) {
                                                          item.quantity = q;
                                                          selectedItems
                                                              .refresh();
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  _qtyBtn(
                                                      Icons.add_rounded, () {
                                                    item.quantity++;
                                                    selectedItems.refresh();
                                                  }),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 90,
                                                child: TextField(
                                                  controller: item.priceCtrl,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  decoration: InputDecoration(
                                                    prefixText: '৳',
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 9),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)),
                                                  ),
                                                  onChanged: (v) {
                                                    final p = num.tryParse(v);
                                                    if (p != null && p >= 0) {
                                                      item.unitPrice = p;
                                                      selectedItems.refresh();
                                                    }
                                                  },
                                                ),
                                              ),
                                              const Spacer(),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  const Text('মোট',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey)),
                                                  Text(
                                                    '৳${_fmt.format(item.totalPrice.toInt())}',
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                            0xFF16A34A)),
                                                  ),
                                                ],
                                              ),
                                            ]),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showProductPicker(
                                        ctx, scheme, selectedItems),
                                    icon: const Icon(Icons.add_rounded),
                                    label:
                                        const Text('প্রডাক্ট যোগ করুন'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Submit
                        Obx(() {
                          final canSubmit =
                              selectedItems.isNotEmpty && !submitting;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: canSubmit
                                  ? () async {
                                      setSheetState(
                                          () => submitting = true);
                                      await controller.addMultipleStockIn(
                                        date: selectedDate,
                                        source: sourceCtrl.text.trim(),
                                        note: noteCtrl.text.trim(),
                                        items: selectedItems
                                            .map((i) => {
                                                  'productId': i.id,
                                                  'productName': i.name,
                                                  'image': i.image,
                                                  'quantity': i.quantity,
                                                  'unitPrice': i.unitPrice,
                                                })
                                            .toList(),
                                      );
                                      Get.snackbar(
                                          'সফল',
                                          '${selectedItems.length} টি প্রডাক্ট, ${totalQty()} pcs স্টক ইন হয়েছে',
                                          snackPosition:
                                              SnackPosition.BOTTOM,
                                          backgroundColor:
                                              const Color(0xFF16A34A),
                                          colorText: Colors.white);
                                      for (final item in selectedItems) {
                                        item.dispose();
                                      }
                                      selectedItems.clear();
                                      Navigator.pop(ctx);
                                    }
                                  : null,
                              icon: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.check_rounded),
                              label: Text(submitting
                                  ? 'সাবমিট হচ্ছে…'
                                  : 'স্টক ইন করুন (${totalQty()} pcs | ৳${_fmt.format(totalValue().toInt())})'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    scheme.surfaceContainerHigh,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF16A34A).withAlpha(80)),
          color: const Color(0xFF16A34A).withAlpha(14),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
      ),
    );
  }

  void _showProductPicker(
      BuildContext ctx, ColorScheme scheme, RxList<_CartItem> selectedItems) {
    String query = '';
    final allProducts = List<ProductModel>.from(pc.products)
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx2) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          final displayed = query.isEmpty
              ? allProducts
              : allProducts
                  .where((p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.brandName.toLowerCase().contains(query) ||
                      p.productCode.toLowerCase().contains(query))
                  .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('প্রডাক্ট বেছে নিন',
                        style: Theme.of(ctx2)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) =>
                          setSheetState(() => query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'নাম বা কোড দিয়ে খুঁজুন…',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: displayed.isEmpty
                        ? const Center(
                            child: Text('কোনো প্রডাক্ট পাওয়া যায়নি',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = displayed[i];
                              final already =
                                  selectedItems.any((e) => e.id == p.id);
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.images.isNotEmpty
                                      ? Image.network(p.images.first,
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                  width: 42,
                                                  height: 42,
                                                  color: scheme
                                                      .surfaceContainerHighest,
                                                  child: const Icon(
                                                      Icons
                                                          .image_not_supported_rounded,
                                                      size: 16)))
                                      : Container(
                                          width: 42,
                                          height: 42,
                                          color: scheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                              Icons
                                                  .image_not_supported_rounded,
                                              size: 16)),
                                ),
                                title: Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                subtitle: Text(
                                    'স্টক: ${p.stock} | ৳${_fmt.format(p.wholesalePrice)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurface
                                            .withAlpha(120))),
                                trailing: already
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF16A34A))
                                    : const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Color(0xFF16A34A)),
                                onTap: () {
                                  if (!already) {
                                    selectedItems.add(_CartItem(
                                      id: p.id,
                                      name: p.name,
                                      image: p.images.isNotEmpty
                                          ? p.images.first
                                          : '',
                                      stock: p.stock,
                                      quantity: 1,
                                      unitPrice: p.purchasePrice,
                                    ));
                                  }
                                  Get.back();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartItem {
  final String id;
  final String name;
  final String image;
  final int stock;
  int quantity;
  num unitPrice;
  late final TextEditingController priceCtrl;

  _CartItem(
      {required this.id,
      required this.name,
      required this.image,
      required this.stock,
      required this.quantity,
      required this.unitPrice}) {
    priceCtrl = TextEditingController(text: unitPrice.toStringAsFixed(0));
  }

  num get totalPrice => quantity * unitPrice;

  void dispose() {
    priceCtrl.dispose();
  }
}

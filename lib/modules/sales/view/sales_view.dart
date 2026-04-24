import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sales_controller.dart';

class SalesView extends GetView<SalesController> {
  const SalesView({super.key});

  static final _fmtInt = NumberFormat('#,##,##0');
  static final _fmtDec = NumberFormat('#,##0.##');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Obx(() {
        return Column(
          children: [
            _monthNav(context, scheme),
            if (controller.loading.value)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadData,
                  child: controller.allOrders.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bar_chart_rounded,
                                      size: 56, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                      'এই মাসে কোনো delivered order নেই',
                                      style:
                                          TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 30),
                          children: [
                            _summaryCards(context),
                            const SizedBox(height: 16),
                            _topProductsSection(context, scheme),
                            const SizedBox(height: 16),
                            _topShopsSection(context, scheme),
                            const SizedBox(height: 16),
                            _sectionHeader(
                                context, 'দিনওয়ারি Sales বিবরণ'),
                            const SizedBox(height: 10),
                            ...controller.dayRows
                                .map((row) => _dayTile(context, row, scheme)),
                          ],
                        ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ── Month Nav ──────────────────────────────────────────────────

  Widget _monthNav(BuildContext context, ColorScheme scheme) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            bottom:
                BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: controller.prevMonth,
          ),
          Obx(() => Text(
                DateFormat('MMMM yyyy')
                    .format(controller.selectedMonth.value),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              )),
          Obx(() {
            final m = controller.selectedMonth.value;
            final now = DateTime.now();
            final isCurrent =
                m.year == now.year && m.month == now.month;
            return IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isCurrent ? Colors.grey : null),
              onPressed: isCurrent ? null : controller.nextMonth,
            );
          }),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────

  Widget _summaryCards(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 600 ? 3 : 1;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          _summaryCard(
            'মোট বিক্রি',
            '৳ ${_fmtInt.format(controller.monthRevenue.value.toInt())}',
            Icons.attach_money_rounded,
            const Color(0xFF0891B2),
          ),
          _summaryCard(
            'মোট Delivered Orders',
            controller.monthOrderCount.value.toString(),
            Icons.check_circle_outline_rounded,
            const Color(0xFF16A34A),
          ),
          _summaryCard(
            'গড় Order মূল্য',
            '৳ ${_fmtInt.format(controller.avgOrderValue.value.toInt())}',
            Icons.calculate_rounded,
            const Color(0xFF7C3AED),
          ),
        ],
      );
    });
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Products ──────────────────────────────────────────────

  Widget _topProductsSection(BuildContext context, ColorScheme scheme) {
    if (controller.topProducts.isEmpty) return const SizedBox();
    final maxQty = controller.topProducts.first.value.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'সর্বোচ্চ বিক্রীত প্রডাক্ট'),
            const SizedBox(height: 12),
            ...controller.topProducts.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text('${e.value} টি',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0891B2))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxQty > 0 ? e.value / maxQty : 0,
                          minHeight: 6,
                          backgroundColor:
                              const Color(0xFF0891B2).withAlpha(20),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF0891B2)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Top Shops ──────────────────────────────────────────────────

  Widget _topShopsSection(BuildContext context, ColorScheme scheme) {
    if (controller.topShops.isEmpty) return const SizedBox();
    final maxRev = controller.topShops.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'সর্বোচ্চ ক্রয়কারী Shop'),
            const SizedBox(height: 12),
            ...controller.topShops.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(
                              '৳ ${_fmtInt.format(e.value.toInt())}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxRev > 0 ? e.value / maxRev : 0,
                          minHeight: 6,
                          backgroundColor:
                              const Color(0xFF16A34A).withAlpha(20),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Day tiles ──────────────────────────────────────────────────

  Widget _dayTile(
      BuildContext context, SalesDayRow row, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(row.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFF0891B2),
                  ),
                ),
                Text(
                  DateFormat('MMM').format(row.date).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF0891B2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            DateFormat('EEEE, dd MMMM').format(row.date),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Row(
            children: [
              _chip('${row.orderCount}টি order',
                  Colors.orange.shade700, Colors.orange.shade50),
              const SizedBox(width: 8),
              Text(
                '৳ ${_fmtInt.format(row.totalRevenue.toInt())}',
                style: TextStyle(
                    color: const Color(0xFF0891B2),
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 1),
            ...row.orders.map((o) => _orderTile(o, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(SalesOrderRow o, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
            top:
                BorderSide(color: scheme.outlineVariant.withAlpha(60))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.shopName.isEmpty ? 'Unknown Shop' : o.shopName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                '৳ ${_fmtInt.format(o.totalAmount.toInt())}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF0891B2)),
              ),
            ],
          ),
          if (o.shopPhone.isNotEmpty)
            Text(o.shopPhone,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          // Items list
          ...o.items.map((item) {
            final name =
                (item['productName'] ?? item['name'] ?? '').toString();
            final qty =
                (item['quantity'] as num?)?.toInt() ?? 1;
            final price =
                (item['price'] ?? item['unitPrice'] as num?)
                        ?.toDouble() ??
                    0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right_rounded,
                      size: 14, color: Colors.grey),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                    '$qty × ৳${_fmtDec.format(price)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            'Order ID: ${o.id} | ${DateFormat('hh:mm a').format(o.createdAt)}',
            style: TextStyle(
                fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

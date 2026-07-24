import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sales_controller.dart';
import 'day_sales_detail_view.dart';

class SalesView extends GetView<SalesController> {
  const SalesView({super.key});

  static final _fmtInt = NumberFormat('#,##,##0');
  static final _dayFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales'),
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
            _quickDateChips(context, scheme),
            if (controller.loading.value)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadData,
                  child: controller.allOrders.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 56, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('এই সময়ের মধ্যে কোনো ডাটা নেই',
                                    style: TextStyle(color: Colors.grey)),
                              ])),
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                          children: [
                            _summaryCards(context),
                            const SizedBox(height: 14),
                            _paymentBreakdownCard(scheme),
                            const SizedBox(height: 16),
                            const Text('দিনওয়ারি বিবরণ',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ...controller.dayRows
                                .map((row) => _dayTile(scheme, row)),
                          ],
                        ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _quickDateChips(BuildContext context, ColorScheme scheme) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _dateChip('আজ', todayDate, todayDate),
              const SizedBox(width: 6),
              _dateChip(
                  'গতকাল',
                  todayDate.subtract(const Duration(days: 1)),
                  todayDate.subtract(const Duration(days: 1))),
              const SizedBox(width: 6),
              _dateChip(
                  'সপ্তাহ', todayDate.subtract(const Duration(days: 7)), todayDate),
              const SizedBox(width: 6),
              _dateChip('মাস', DateTime(today.year, today.month, 1), todayDate),
              const SizedBox(width: 6),
              _dateChip('সব', null, null),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('কাস্টম', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  final from = await showDatePicker(
                    context: context,
                    initialDate: controller.fromDate.value ?? today,
                    firstDate: DateTime(2020),
                    lastDate: today.add(const Duration(days: 1)),
                  );
                  if (from != null) {
                    final to = await showDatePicker(
                      context: context,
                      initialDate: controller.toDate.value ?? today,
                      firstDate: from,
                      lastDate: today.add(const Duration(days: 1)),
                    );
                    if (to != null) controller.setDateRange(from, to);
                  }
                },
              ),
            ],
          )),
    );
  }

  Widget _dateChip(String label, DateTime? from, DateTime? to) {
    final active = controller.fromDate.value == from &&
        controller.toDate.value == to;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
      selected: active,
      onSelected: (_) => controller.setDateRange(from, to),
      selectedColor: const Color(0xFF16A34A).withAlpha(30),
      labelStyle: TextStyle(color: active ? const Color(0xFF16A34A) : null),
      side: active ? const BorderSide(color: Color(0xFF16A34A)) : null,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _summaryCards(BuildContext context) {
    final netSales =
        _fmtInt.format(controller.monthNetSales.value.toInt());
    final orders = controller.monthOrderCount.value.toString();
    final purch =
        _fmtInt.format(controller.totalPurchaseCost.value.toInt());
    final exp = _fmtInt.format(controller.totalExpenses.value.toInt());
    final rate = controller.srCommissionPercent.value / 100;
    final commission =
        _fmtInt.format((controller.monthNetSales.value * rate).toInt());
    final profit = _fmtInt.format(
        (controller.monthNetSales.value -
                controller.totalPurchaseCost.value -
                controller.monthNetSales.value * rate -
                controller.totalExpenses.value)
            .toInt());
    final profitVal = controller.monthNetSales.value -
        controller.totalPurchaseCost.value -
        controller.monthNetSales.value * rate -
        controller.totalExpenses.value;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _summaryCard(context, 'মোট বিক্রি', '৳ $netSales',
            Icons.trending_up_rounded, const Color(0xFF0891B2)),
        _summaryCard(context, 'মোট অর্ডার', '$orders টি',
            Icons.receipt_long_rounded, const Color(0xFF7C3AED)),
        _summaryCard(context, 'ক্রয় মূল্য', '৳ $purch',
            Icons.shopping_cart_rounded, const Color(0xFFD97706)),
        _summaryCard(context, 'SR কমিশন', '৳ $commission',
            Icons.person_pin_rounded, const Color(0xFF8B5CF6)),
        _summaryCard(context, 'খরচ', '৳ $exp',
            Icons.money_off_rounded, const Color(0xFFDC2626)),
        _summaryCard(
            context,
            'নিট লাভ',
            '৳ $profit',
            Icons.savings_rounded,
            profitVal >= 0
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626)),
      ]),
    ]);
  }

  Widget _summaryCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(title,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _paymentBreakdownCard(ColorScheme scheme) {
    final items = controller.paymentBreakdown;
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('পেমেন্ট মাধ্যম ভিত্তিক জমা',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...items.map((e) {
            final total =
                items.fold<double>(0, (s, i) => s + i.value);
            final ratio = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                      Text('৳ ${_fmtInt.format(e.value.toInt())}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED))),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor:
                            scheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF7C3AED)),
                        minHeight: 6,
                      ),
                    ),
                  ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _dayTile(ColorScheme scheme, SalesDayRow row) {
    final netSales = _fmtInt.format(row.totalNetSales.toInt());
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.to(() => DaySalesDetailView(date: row.date)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${row.date.day}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0891B2)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('MMMM yyyy').format(row.date),
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withAlpha(120))),
                Text(_dayFmt.format(row.date),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('মোট: ৳ $netSales',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0891B2))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${row.orderCount}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A))),
                  const SizedBox(width: 2),
                  const Text('অর্ডার',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF16A34A))),
                ]),
              ),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: scheme.onSurface.withAlpha(100)),
            ]),
          ]),
        ),
      ),
    );
  }

}

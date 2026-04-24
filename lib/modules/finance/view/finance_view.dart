import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../routes/app_routes.dart';
import '../controller/finance_controller.dart';

class FinanceView extends GetView<FinanceController> {
  const FinanceView({super.key});

  static String _fmt(double value) =>
      NumberFormat('#,##0.##').format(value);
  static String _fmtInt(double value) =>
      NumberFormat('#,##,##0').format(value.toInt());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _openSettingsDialog(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refreshAnalytics,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.refreshAnalytics,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 1200 ? 4 : w >= 800 ? 3 : w >= 500 ? 2 : 1;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stock Valuation Section ──
                  _sectionHeader(context, 'স্টক মূল্যায়ন (বর্তমান)',
                      Icons.inventory_2_rounded),
                  const SizedBox(height: 10),
                  _stockValuationRow(context, w),
                  const SizedBox(height: 20),

                  // ── Period filter ──
                  _sectionHeader(context, 'Period Filter', Icons.date_range_rounded),
                  const SizedBox(height: 8),
                  _rangeSelector(context),
                  const SizedBox(height: 14),

                  // ── KPI Grid ──
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _kpiCard('মোট বিক্রি', controller.totalSales.value,
                          const Color(0xFF0284C7)),
                      _kpiCard('ক্রয় মূল্য (COGS)',
                          controller.totalCost.value,
                          const Color(0xFFEA580C)),
                      _kpiCard('মোট লাভ (Gross)',
                          controller.grossProfit.value,
                          const Color(0xFF16A34A)),
                      _kpiCard('SR কমিশন',
                          controller.srCommissionCost.value,
                          const Color(0xFF7C3AED)),
                      _kpiCard('বেতন বরাদ্দ',
                          controller.salaryAllocated.value,
                          const Color(0xFFDC2626)),
                      _kpiCard('মোট খরচ', controller.totalExpenses.value,
                          const Color(0xFFD97706)),
                      _kpiCard('স্টক কেনা (Purchase In)',
                          controller.totalPurchased.value,
                          const Color(0xFF0891B2)),
                      // Gross margin %
                      _pctCard('Gross Margin %',
                          controller.grossMarginPct.value,
                          const Color(0xFF16A34A)),
                      // Delivered orders count
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivered Orders',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              const Spacer(),
                              Text(
                                controller.deliveredOrders.value
                                    .toString(),
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Final Net Profit banner ──
                  _netProfitBanner(context),
                  const SizedBox(height: 16),

                  // ── Quick Navigation ──
                  _navRow(context),
                  const SizedBox(height: 20),

                  // ── Day-wise Ledger ──
                  _sectionHeader(context, 'দিনওয়ারি Purchase vs Sales',
                      Icons.compare_arrows_rounded),
                  const SizedBox(height: 10),
                  if (controller.dayLedger.isEmpty)
                    _emptyCard('এই period এ কোনো purchase/sales নেই')
                  else
                    ...controller.dayLedger.map(_dayLedgerTile),
                  const SizedBox(height: 20),

                  // ── Order-wise Profit ──
                  _sectionHeader(context, 'Order-wise Profit (Delivered)',
                      Icons.receipt_long_rounded),
                  const SizedBox(height: 10),
                  if (controller.orderRows.isEmpty)
                    _emptyCard('এই period এ delivered order নেই')
                  else
                    ...controller.orderRows.map(_orderProfitTile),
                  const SizedBox(height: 16),
                  Text(
                    'লাভ গণনা: শুধুমাত্র delivered orders | '
                    'COGS = purchasePrice × qty | '
                    'SR commission = sales × ${controller.commissionPercent.value.toStringAsFixed(1)}%',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  // ── Stock Valuation ──────────────────────────────────────────────

  Widget _stockValuationRow(BuildContext context, double width) {
    final capital = controller.stockCapital.value;
    final saleVal = controller.stockSaleValue.value;
    final margin = controller.stockAvgMarginPct.value;
    final profit = saleVal - capital;

    final cards = [
      _stockCard(context, 'কেনা দামে স্টক', capital,
          'মোট কেনা মূল্য × স্টক পরিমাণ',
          const Color(0xFF0891B2), Icons.shopping_cart_rounded),
      _stockCard(context, 'বিক্রয় মূল্যে স্টক', saleVal,
          'মোট wholesale মূল্য × স্টক পরিমাণ',
          const Color(0xFF0284C7), Icons.sell_rounded),
      _stockCard(context, 'সম্ভাব্য লাভ', profit,
          'বিক্রয় মূল্য − ক্রয় মূল্য',
          const Color(0xFF16A34A), Icons.trending_up_rounded),
      _stockPctCard(context, 'গড় লাভের হার', margin),
    ];

    if (width >= 800) {
      return Row(
        children: cards
            .map((c) =>
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c)))
            .toList(),
      );
    }
    return Column(
        children: cards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c))
            .toList());
  }

  Widget _stockCard(BuildContext context, String title, double value,
      String subtitle, Color color, IconData icon) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '৳ ${_fmtInt(value)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockPctCard(BuildContext context, String title, double pct) {
    final color = pct >= 0 ? const Color(0xFF16A34A) : Colors.red;
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
              child: Icon(Icons.percent_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '${_fmt(pct)}%',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                Text('wholesale − cost পার্থক্য',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Range Selector ──────────────────────────────────────────────

  Widget _rangeSelector(BuildContext context) {
    return Obx(() {
      final sel = controller.selectedRange.value;
      final customStart = controller.customStart.value;
      final customEnd = controller.customEnd.value;
      final df = DateFormat('dd MMM yy');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('আজকে'),
                selected: sel == FinanceRange.today,
                onSelected: (_) => controller.setRange(FinanceRange.today),
              ),
              ChoiceChip(
                label: const Text('এই সপ্তাহ'),
                selected: sel == FinanceRange.week,
                onSelected: (_) => controller.setRange(FinanceRange.week),
              ),
              ChoiceChip(
                label: const Text('এই মাস'),
                selected: sel == FinanceRange.month,
                onSelected: (_) =>
                    controller.setRange(FinanceRange.month),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  sel == FinanceRange.custom && customStart != null
                      ? '${df.format(customStart)} → ${customEnd != null ? df.format(customEnd) : '?'}'
                      : 'Custom range',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: sel == FinanceRange.custom
                    ? const Color(0xFF0891B2).withAlpha(30)
                    : null,
                onPressed: () => _pickCustomRange(context),
              ),
            ],
          ),
        ],
      );
    });
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          controller.customStart.value != null &&
                  controller.customEnd.value != null
              ? DateTimeRange(
                  start: controller.customStart.value!,
                  end: controller.customEnd.value!)
              : null,
      helpText: 'Date Range বেছে নিন',
      saveText: 'Apply',
    );
    if (range != null) {
      controller.setCustomRange(range.start, range.end);
    }
  }

  // ── Net Profit Banner ──────────────────────────────────────────

  Widget _netProfitBanner(BuildContext context) {
    final fnp = controller.finalNetProfit.value;
    final isPos = fnp >= 0;
    final color =
        isPos ? const Color(0xFF15803D) : Colors.red.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isPos
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('চূড়ান্ত নিট লাভ (খরচ বাদে)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color)),
              Text(
                '৳ ${_fmtInt(fnp)}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nav Row ────────────────────────────────────────────────────

  Widget _navRow(BuildContext context) {
    final btns = [
      ('Expense Ledger', Icons.receipt_long_rounded, AppRoutes.expenses),
      ('SR Performance', Icons.person_pin_circle_rounded, AppRoutes.sr),
      ('Purchase Ledger', Icons.shopping_cart_rounded, AppRoutes.purchases),
      ('Sales', Icons.bar_chart_rounded, AppRoutes.sales),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: btns
          .map((b) => OutlinedButton.icon(
                onPressed: () => Get.toNamed(b.$3),
                icon: Icon(b.$2, size: 16),
                label: Text(b.$1, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                ),
              ))
          .toList(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Widget _sectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0891B2)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _emptyCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text,
            style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _kpiCard(String title, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            Text(
              '৳ ${_fmtInt(value)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pctCard(String title, double pct, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            Text(
              '${_fmt(pct)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayLedgerTile(DayLedgerRow row) {
    final isPositive = row.net >= 0;
    final netColor =
        isPositive ? const Color(0xFF15803D) : Colors.red.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM, EEE').format(row.date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniPill('কেনা', row.purchased, Colors.blue.shade700),
                    const SizedBox(width: 8),
                    _miniPill('বিক্রি', row.sold, Colors.green.shade700),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('নেট',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                Text(
                  '${isPositive ? '+' : ''}৳${_fmt(row.net)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: netColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        '$label: ৳${_fmt(val)}',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _orderProfitTile(OrderProfitRow row) {
    final df = DateFormat('dd MMM, hh:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.shopName.isEmpty ? 'Unknown Shop' : row.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(df.format(row.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text('ID: ${row.id}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill('Sales', row.revenue, const Color(0xFF0284C7)),
                _pill('Cost', row.cost, const Color(0xFFEA580C)),
                _pill('Gross', row.gross, const Color(0xFF16A34A)),
                _pill('Comm', row.commission, const Color(0xFF7C3AED)),
                _pill('Net*', row.netBeforeSalary,
                    const Color(0xFF15803D)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, double value, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ৳${_fmtInt(value)}',
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12),
      ),
    );
  }

  Future<void> _openSettingsDialog(BuildContext context) async {
    final commissionCtrl = TextEditingController(
        text: controller.commissionPercent.value.toStringAsFixed(2));
    final salaryCtrl = TextEditingController(
        text:
            controller.srMonthlyFixedSalary.value.toStringAsFixed(2));

    await Get.dialog(
      AlertDialog(
        title: const Text('Finance Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commissionCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'SR কমিশন (%)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: salaryCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'SR মাসিক ফিক্সড বেতন'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final c = double.tryParse(commissionCtrl.text.trim()) ??
                  controller.commissionPercent.value;
              final s = double.tryParse(salaryCtrl.text.trim()) ??
                  controller.srMonthlyFixedSalary.value;
              await controller.saveSettings(commission: c, salary: s);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

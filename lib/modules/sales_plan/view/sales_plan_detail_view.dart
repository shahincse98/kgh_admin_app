import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/sales_plan_controller.dart';
import '../model/sales_plan_model.dart';

class SalesPlanDetailView extends StatefulWidget {
  final SalesPlanModel plan;
  const SalesPlanDetailView({super.key, required this.plan});

  @override
  State<SalesPlanDetailView> createState() =>
      _SalesPlanDetailViewState();
}

class _SalesPlanDetailViewState extends State<SalesPlanDetailView> {
  late final SalesPlanController _ctrl;
  Map<String, int> _actuals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<SalesPlanController>();
    _loadActuals();
  }

  Future<void> _loadActuals({bool refresh = false}) async {
    setState(() => _loading = true);
    if (refresh) _ctrl.clearActualsCache(widget.plan.id);
    final result = await _ctrl.loadActuals(widget.plan);
    setState(() {
      _actuals = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plan = widget.plan;

    // Compute overall achievement
    int totalTarget = 0, totalActual = 0;
    for (final item in plan.items) {
      totalTarget += item.targetQty;
      totalActual += _actuals[item.productName] ?? 0;
    }
    final overallPct =
        totalTarget > 0 ? (totalActual / totalTarget).clamp(0.0, 1.0) : 0.0;
    final pctDisplay =
        totalTarget > 0 ? '${(overallPct * 100).toStringAsFixed(1)}%' : '–';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          plan.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh actuals',
            onPressed: () => _loadActuals(refresh: true),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(cs);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('পরিকল্পনা ডিলেট করুন',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                // ── Meta info ─────────────────────────────────────────────
                _metaCard(plan, cs),
                const SizedBox(height: 12),

                // ── Overall summary ───────────────────────────────────────
                _summaryCard(totalTarget, totalActual, overallPct,
                    pctDisplay, cs),
                const SizedBox(height: 16),

                // ── Product breakdown ─────────────────────────────────────
                _sectionHeader('প্রডাক্টওয়ারি অর্জন', cs),
                const SizedBox(height: 10),
                ...plan.items.map((item) =>
                    _productRow(item, _actuals[item.productName] ?? 0,
                        cs)),

                // ── Extra actuals (sold but not in plan) ──────────────────
                if (_extraActuals(plan).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionHeader('পরিকল্পনার বাইরে বিক্রীত', cs),
                  const SizedBox(height: 10),
                  ..._extraActuals(plan).map((e) =>
                      _extraRow(e.key, e.value, cs)),
                ],
              ],
            ),
    );
  }

  // ── Meta card ─────────────────────────────────────────────────────────────

  Widget _metaCard(SalesPlanModel plan, ColorScheme cs) {
    final isWeekly = plan.type == 'weekly';
    final typeColor =
        isWeekly ? const Color(0xFF7C3AED) : const Color(0xFF0891B2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(isWeekly ? 'সাপ্তাহিক' : 'মাসিক', typeColor),
                _badge(plan.displayPeriod, const Color(0xFF0891B2)),
                _badge(
                    plan.assignedTo == 'all'
                        ? 'সকল SR'
                        : plan.srName,
                    const Color(0xFF16A34A)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _summaryCard(int totalTarget, int totalActual,
      double overallPct, String pctDisplay, ColorScheme cs) {
    Color pctColor;
    if (overallPct >= 1.0) {
      pctColor = const Color(0xFF16A34A);
    } else if (overallPct >= 0.75) {
      pctColor = const Color(0xFFF59E0B);
    } else {
      pctColor = Colors.red.shade400;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('সামগ্রিক অর্জন',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statCol('মোট লক্ষ্য',
                      '$totalTarget টি', cs.onSurface),
                ),
                Expanded(
                  child: _statCol('মোট বিক্রি',
                      '$totalActual টি', const Color(0xFF0891B2)),
                ),
                Expanded(
                  child: _statCol('অর্জন %', pctDisplay, pctColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: overallPct,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(pctColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // ── Product row ───────────────────────────────────────────────────────────

  Widget _productRow(
      SalesPlanItem item, int actual, ColorScheme cs) {
    final target = item.targetQty;
    final pct = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final pctVal = target > 0 ? (pct * 100).toStringAsFixed(0) : '–';

    Color barColor;
    if (pct >= 1.0) {
      barColor = const Color(0xFF16A34A);
    } else if (pct >= 0.75) {
      barColor = const Color(0xFFF59E0B);
    } else if (pct >= 0.5) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red.shade400;
    }

    final extraQty = actual > target ? actual - target : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (pct >= 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('✓ লক্ষ্য পূরণ',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$actual / $target টি',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant)),
                        Text('$pctVal%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: barColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (extraQty > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '🎉 লক্ষ্য ছাড়িয়ে অতিরিক্ত $extraQty টি বিক্রি হয়েছে',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF16A34A)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Extra actuals ─────────────────────────────────────────────────────────

  List<MapEntry<String, int>> _extraActuals(SalesPlanModel plan) {
    final planNames =
        plan.items.map((i) => i.productName).toSet();
    return _actuals.entries
        .where((e) => !planNames.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  Widget _extraRow(String name, int qty, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border:
            Border.all(color: cs.outlineVariant.withAlpha(120)),
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record,
              size: 7, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(name, style: const TextStyle(fontSize: 13))),
          Text('$qty টি',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0891B2))),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, ColorScheme cs) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cs.primary)),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  void _confirmDelete(ColorScheme cs) {
    Get.dialog(AlertDialog(
      title: const Text('পরিকল্পনা ডিলেট করবেন?'),
      content:
          Text('"${widget.plan.title}" স্থায়ীভাবে মুছে যাবে।'),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('বাতিল')),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Get.back();
            await _ctrl.deletePlan(widget.plan.id);
            Get.back();
            Get.snackbar(
              'ডিলেট হয়েছে',
              '"${widget.plan.title}" মুছে ফেলা হয়েছে',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.shade700,
              colorText: Colors.white,
            );
          },
          child: const Text('ডিলেট করুন',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

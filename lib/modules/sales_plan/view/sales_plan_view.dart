import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sales_plan_controller.dart';
import '../model/sales_plan_model.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';

class SalesPlanView extends StatelessWidget {
  const SalesPlanView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SalesPlanController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('কাস্টমার বিক্রয় পরিকল্পনা'),
        actions: [
          Obx(() => ctrl.actualsLoading.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'Actual রিফ্রেশ করুন',
                  onPressed: ctrl.refreshActuals,
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('কাস্টমার যোগ করুন'),
        onPressed: () => _showAddCustomerDialog(context, ctrl, cs),
      ),
      body: Column(
        children: [
          _MonthStrip(ctrl: ctrl, cs: cs),
          Expanded(
            child: Obx(() {
              if (ctrl.planLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ctrl.planItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_outlined,
                          size: 58, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      Text(
                        '${ctrl.selectedMonth.value.year == DateTime.now().year && ctrl.selectedMonth.value.month == DateTime.now().month ? 'এই মাসে' : _monthLabel(ctrl.selectedMonth.value)} কোনো পরিকল্পনা নেই',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'কাস্টমার যোগ করতে নিচের + বোতাম চাপুন',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Summary
              final totalTarget = ctrl.planItems
                  .fold(0.0, (s, i) => s + i.targetAmount);
              final totalActual = ctrl.planItems
                  .fold(0.0, (s, i) => s + ctrl.actualFor(i));
              final pct = totalTarget > 0
                  ? (totalActual / totalTarget).clamp(0.0, double.infinity)
                  : 0.0;

              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 10, 14, 100),
                children: [
                  _SummaryCard(
                    totalTarget: totalTarget,
                    totalActual: totalActual,
                    pct: pct,
                    fmt: _fmt,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  ...ctrl.planItems.map((item) => _CustomerRow(
                        item: item,
                        actual: ctrl.actualFor(item),
                        fmt: _fmt,
                        cs: cs,
                        onEdit: () =>
                            _showEditDialog(context, ctrl, item, cs),
                        onDelete: () => _confirmDelete(
                            context, ctrl, item, cs),
                      )),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(DateTime m) {
    const names = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  // ── Add customer dialog ───────────────────────────────────────────────────

  void _showAddCustomerDialog(
      BuildContext context, SalesPlanController ctrl, ColorScheme cs) {
    UserModel? picked;
    final amtCtrl = TextEditingController();
    final searchCtrl = TextEditingController();

    Get.dialog(
      StatefulBuilder(builder: (ctx, setSt) {
        final userCtrl = Get.find<UserController>();
        final filtered = searchCtrl.text.trim().isEmpty
            ? userCtrl.users
            : userCtrl.users.where((u) {
                final q = searchCtrl.text.trim().toLowerCase();
                return u.shopName.toLowerCase().contains(q) ||
                    u.proprietorName.toLowerCase().contains(q) ||
                    u.phone.contains(q);
              }).toList();

        return AlertDialog(
          title: const Text('কাস্টমার যোগ করুন'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSt(() {}),
                    decoration: InputDecoration(
                      hintText: 'নাম / ফোন দিয়ে খুঁজুন...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // User list
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        final sel = picked?.id == u.id;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor:
                              cs.primary.withAlpha(20),
                          title: Text(
                            u.shopName.isNotEmpty
                                ? u.shopName
                                : u.proprietorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(u.phone,
                              style: const TextStyle(fontSize: 11)),
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              (u.shopName.isNotEmpty
                                      ? u.shopName
                                      : u.proprietorName)
                                  .characters
                                  .first,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          onTap: () => setSt(() => picked = u),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Amount
                  TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'লক্ষ্যমাত্রা (টাকা) *',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () async {
                if (picked == null) {
                  Get.snackbar('ত্রুটি', 'কাস্টমার সিলেক্ট করুন',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white);
                  return;
                }
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                if (amt <= 0) {
                  Get.snackbar('ত্রুটি', 'পরিমাণ ০-এর বেশি হতে হবে',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white);
                  return;
                }
                final item = CustomerPlanItem(
                  userId: picked!.id,
                  shopName: picked!.shopName.isNotEmpty
                      ? picked!.shopName
                      : picked!.proprietorName,
                  phone: picked!.phone,
                  address: picked!.address,
                  targetAmount: amt,
                );
                Get.back();
                await ctrl.upsertItem(item);
                Get.snackbar('যোগ হয়েছে',
                    '${item.shopName} পরিকল্পনায় যোগ হয়েছে',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white);
              },
              child: const Text('যোগ করুন'),
            ),
          ],
        );
      }),
    );
  }

  // ── Edit target dialog ───────────────────────────────────────────────────

  void _showEditDialog(BuildContext context, SalesPlanController ctrl,
      CustomerPlanItem item, ColorScheme cs) {
    final amtCtrl =
        TextEditingController(text: item.targetAmount.toInt().toString());

    Get.dialog(AlertDialog(
      title: Text(item.shopName),
      content: TextField(
        controller: amtCtrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'লক্ষ্যমাত্রা (টাকা)',
          prefixText: '৳ ',
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(amtCtrl.text) ?? 0;
            if (amt <= 0) return;
            Get.back();
            await ctrl.upsertItem(item.copyWith(targetAmount: amt));
          },
          child: const Text('সেভ'),
        ),
      ],
    ));
  }

  // ── Confirm delete ───────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, SalesPlanController ctrl,
      CustomerPlanItem item, ColorScheme cs) {
    Get.dialog(AlertDialog(
      title: const Text('কাস্টমার বাদ দেবেন?'),
      content: Text('"${item.shopName}" এই মাসের পরিকল্পনা থেকে বাদ যাবে।'),
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Get.back();
            await ctrl.removeItem(item.userId);
          },
          child: const Text('বাদ দিন',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

// ─── Month header ──────────────────────────────────────────────────────────────

class _MonthStrip extends StatelessWidget {
  final SalesPlanController ctrl;
  final ColorScheme cs;
  const _MonthStrip({required this.ctrl, required this.cs});

  static const _fullNames = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];
  static const _shortNames = [
    'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্ট', 'অক্টো', 'নভে', 'ডিসে',
  ];

  void _openPicker(BuildContext context) {
    final now = DateTime.now();
    int pickerYear = ctrl.selectedMonth.value.year;
    int pickerMonth = ctrl.selectedMonth.value.month;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('মাস ও সাল বেছে নিন'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setSt(() => pickerYear--),
                    ),
                    Text(
                      '$pickerYear',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setSt(() => pickerYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Month grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) {
                    final isSelected = pickerMonth == i + 1;
                    final isCurrent =
                        now.year == pickerYear && now.month == i + 1;
                    return GestureDetector(
                      onTap: () => setSt(() => pickerMonth = i + 1),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : isCurrent
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent && !isSelected
                              ? Border.all(color: cs.primary, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          _shortNames[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? cs.onPrimary
                                : cs.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ctrl.selectMonth(DateTime(pickerYear, pickerMonth));
              },
              child: const Text('ঠিক আছে'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Obx(() {
      final m = ctrl.selectedMonth.value;
      final isCurrentMonth = m.year == now.year && m.month == now.month;
      final label = '${_fullNames[m.month - 1]} ${m.year}';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
              bottom: BorderSide(color: cs.outlineVariant, width: 1)),
        ),
        child: Row(
          children: [
            // Prev month
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: ctrl.prevMonth,
              tooltip: 'আগের মাস',
            ),
            // Month label (tappable)
            Expanded(
              child: GestureDetector(
                onTap: () => _openPicker(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: cs.primary, size: 22),
                      ],
                    ),
                    if (isCurrentMonth)
                      Text(
                        'চলতি মাস',
                        style: TextStyle(
                            fontSize: 11, color: cs.primary),
                      ),
                  ],
                ),
              ),
            ),
            // Next month
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: ctrl.nextMonth,
              tooltip: 'পরের মাস',
            ),
          ],
        ),
      );
    });
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalTarget;
  final double totalActual;
  final double pct;
  final NumberFormat fmt;
  final ColorScheme cs;

  const _SummaryCard({
    required this.totalTarget,
    required this.totalActual,
    required this.pct,
    required this.fmt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    Color pctColor;
    if (pct >= 1.0) {
      pctColor = const Color(0xFF16A34A);
    } else if (pct >= 0.75) {
      pctColor = const Color(0xFFF59E0B);
    } else {
      pctColor = Colors.red.shade400;
    }
    final pctStr = totalTarget > 0
        ? '${(pct * 100).toStringAsFixed(1)}%'
        : '–';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('সামগ্রিক অগ্রগতি',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _stat('মোট লক্ষ্য',
                        '৳ ${fmt.format(totalTarget.toInt())}',
                        cs.onSurface)),
                Expanded(
                    child: _stat('মোট বিক্রি',
                        '৳ ${fmt.format(totalActual.toInt())}',
                        const Color(0xFF0891B2))),
                Expanded(
                    child: _stat('অর্জন', pctStr, pctColor)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(pctColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

// ─── Customer row ─────────────────────────────────────────────────────────────

class _CustomerRow extends StatelessWidget {
  final CustomerPlanItem item;
  final double actual;
  final NumberFormat fmt;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerRow({
    required this.item,
    required this.actual,
    required this.fmt,
    required this.cs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = item.targetAmount;
    final pct =
        target > 0 ? (actual / target).clamp(0.0, double.infinity) : 0.0;
    final barPct = pct.clamp(0.0, 1.0);
    final pctStr = target > 0
        ? '${(pct * 100).toStringAsFixed(0)}%'
        : '–';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    item.shopName.characters.first.toUpperCase(),
                    style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.shopName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      if (item.phone.isNotEmpty)
                        Text(item.phone,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant)),
                      if (item.address.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11,
                                color: cs.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                item.address,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (pct >= 1.0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('✓ পূরণ',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w700)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'del') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('লক্ষ্যমাত্রা পরিবর্তন'),
                        ])),
                    PopupMenuItem(
                        value: 'del',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Text('বাদ দিন',
                              style: TextStyle(
                                  color: Colors.red.shade400)),
                        ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '৳ ${fmt.format(actual.toInt())} / ৳ ${fmt.format(target.toInt())}',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant),
                          ),
                          Text(
                            pctStr,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: barColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barPct,
                          minHeight: 7,
                          backgroundColor:
                              cs.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pct > 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🎉 লক্ষ্য ছাড়িয়ে অতিরিক্ত ৳ ${fmt.format((actual - target).toInt())} বিক্রি',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF16A34A)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


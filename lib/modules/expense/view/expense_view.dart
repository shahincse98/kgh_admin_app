import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/expense_controller.dart';
import '../model/expense_model.dart';
import '../../../widgets/responsive.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';

class ExpenseView extends GetView<ExpenseController> {
  const ExpenseView({super.key});

  static const _types = [
    'rent',
    'electricity',
    'transport',
    'salary',
    'misc'
  ];
  // getter — ভাষা বদলালে লেবেলও বদলাবে (static field হলে একবারই বসত)
  static Map<String, String> get _typeLabels => {
    'rent': 'ভাড়া'.tr,
    'electricity': 'বিদ্যুৎ'.tr,
    'transport': 'পরিবহন'.tr,
    'salary': 'বেতন'.tr,
    'misc': 'অন্যান্য'.tr,
  };
  static final _typeIcons = {
    'rent': Icons.home_rounded,
    'electricity': Icons.bolt_rounded,
    'transport': Icons.local_shipping_rounded,
    'salary': Icons.badge_rounded,
    'misc': Icons.more_horiz_rounded,
  };
  static const _typeColors = {
    'rent': Color(0xFF6366F1),
    'electricity': Color(0xFFF59E0B),
    'transport': Color(0xFF0EA5E9),
    'salary': Color(0xFF10B981),
    'misc': Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: Text('Expense Ledger'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.tr,
            onPressed: controller.loadExpenses,
          ),
        ],
      ),
      body: ResponsiveWrapper(child: Obx(() {
        return Column(
          children: [
            _monthNavigator(context, scheme),
            if (controller.loading.value)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (controller.expenses.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('এই মাসে কোনো খরচ নেই'.tr,
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadExpenses,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      _summaryCard(context, scheme),
                      const SizedBox(height: 14),
                      ...controller.expenses
                          .map((e) => _expenseTile(context, e, scheme)),
                    ],
                  ),
                ),
              ),
          ],
        );
      })),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: Text('খরচ যোগ করুন'.tr),
      ),
    );
  }

  Widget _monthNavigator(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: controller.prevMonth,
          ),
          Obx(() {
            final m = controller.selectedMonth.value;
            return Text(
              DateFormat('MMMM yyyy').format(m),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            );
          }),
          Obx(() {
            final m = controller.selectedMonth.value;
            final now = DateTime.now();
            final isCurrentMonth =
                m.year == now.year && m.month == now.month;
            return IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isCurrentMonth ? Colors.grey : null),
              onPressed: isCurrentMonth ? null : controller.nextMonth,
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, ColorScheme scheme) {
    final byType = controller.byType;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('মোট খরচ'.tr,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '৳ ${NumberFormat('#,##,##0').format(controller.totalExpenses)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.where((t) => (byType[t] ?? 0) > 0).map((t) {
                return Chip(
                  avatar:
                      Icon(_typeIcons[t], size: 16, color: _typeColors[t]),
                  label: Text(
                    '${_typeLabels[t]}: ৳${NumberFormat('#,##,##0').format(byType[t]!.toInt())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  side: BorderSide(color: _typeColors[t]!.withAlpha(100)),
                  backgroundColor:
                      _typeColors[t]!.withAlpha(20),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(
      BuildContext context, ExpenseModel e, ColorScheme scheme) {
    final color = _typeColors[e.type] ?? const Color(0xFF94A3B8);
    final icon = _typeIcons[e.type] ?? Icons.more_horiz_rounded;
    final label = _typeLabels[e.type] ?? e.type;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.note.isNotEmpty ? e.note : '—',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy').format(e.date),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳ ${NumberFormat('#,##,##0').format(e.amount.toInt())}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'মুছুন'.tr,
              onPressed: () => _confirmDelete(context, e),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ExpenseModel e) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('খরচ মুছবেন?'.tr),
        content: Text(
            '${_typeLabels[e.type] ?? e.type}: ৳${e.amount.toInt()} — ${e.note.isNotEmpty ? e.note : 'কোনো note নেই'}'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('না'.tr)),
          TextButton(
              onPressed: () => Get.back(result: true),
              child:
                  Text('হ্যাঁ'.tr, style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await controller.deleteExpense(e.id);
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final typeObs = 'misc'.obs;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final dateObs = DateTime.now().obs;
    final formKey = GlobalKey<FormState>();

    await Get.dialog(
      AlertDialog(
        title: Text('নতুন খরচ যোগ করুন'.tr),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => DropdownButtonFormField<String>(
                      initialValue: typeObs.value,
                      decoration:
                          InputDecoration(labelText: 'ধরন'.tr),
                      items: _types
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_typeLabels[t] ?? t)))
                          .toList(),
                      onChanged: (v) => typeObs.value = v ?? 'misc',
                    )),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration:
                      InputDecoration(labelText: 'পরিমাণ (৳)'.tr),
                  validator: (v) =>
                      (v == null || v.isEmpty || int.tryParse(v) == null)
                          ? 'পরিমাণ লিখুন'.tr
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  decoration:
                      InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'.tr),
                ),
                const SizedBox(height: 12),
                Obx(() => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: Text(DateFormat('dd MMM yyyy')
                          .format(dateObs.value)),
                      subtitle: Text('তারিখ'.tr),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dateObs.value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) dateObs.value = picked;
                      },
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Get.back();
              await controller.addExpense(
                type: typeObs.value,
                amount: double.parse(amountCtrl.text),
                note: noteCtrl.text.trim(),
                date: dateObs.value,
              );
            },
            child: Text('সংরক্ষণ'.tr),
          ),
        ],
      ),
    );
  }
}

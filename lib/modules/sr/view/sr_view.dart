import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_controller.dart';
import '../model/sr_payment_model.dart';

class SrView extends GetView<SrController> {
  const SrView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SR Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadData,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _monthNavigator(context, scheme),
              const SizedBox(height: 14),
              _kpiGrid(context, scheme),
              const SizedBox(height: 14),
              _balanceCard(context, scheme),
              const SizedBox(height: 14),
              Text(
                'পেমেন্ট ইতিহাস',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (controller.payments.isEmpty)
                const SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('কোনো পেমেন্ট নেই',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...controller.payments
                    .map((p) => _paymentTile(context, p, scheme)),
              const SizedBox(height: 80),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context),
        icon: const Icon(Icons.payments_rounded),
        label: const Text('পেমেন্ট রেকর্ড'),
      ),
    );
  }

  Widget _monthNavigator(BuildContext context, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: Theme.of(context).textTheme.titleMedium
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
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 700 ? 3 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          _kpiCard(
            'ডেলিভারি',
            controller.totalDeliveries.value.toString(),
            Icons.local_shipping_rounded,
            const Color(0xFF0EA5E9),
          ),
          _kpiCard(
            'বিক্রয়',
            '৳ ${_fmt.format(controller.totalRevenue.value.toInt())}',
            Icons.payments_rounded,
            const Color(0xFF10B981),
          ),
          _kpiCard(
            'কমিশন (${controller.commissionPercent.value.toStringAsFixed(1)}%)',
            '৳ ${_fmt.format(controller.commissionDue.value.toInt())}',
            Icons.percent_rounded,
            const Color(0xFF6366F1),
          ),
          _kpiCard(
            'বেতন',
            '৳ ${_fmt.format(controller.monthlyFixedSalary.value.toInt())}',
            Icons.badge_rounded,
            const Color(0xFFF59E0B),
          ),
          _kpiCard(
            'মোট প্রাপ্য',
            '৳ ${_fmt.format(controller.totalDue.value.toInt())}',
            Icons.account_balance_wallet_rounded,
            const Color(0xFF0891B2),
          ),
          _kpiCard(
            'পরিশোধিত',
            '৳ ${_fmt.format(controller.totalPaid.value.toInt())}',
            Icons.check_circle_rounded,
            const Color(0xFF22C55E),
          ),
        ],
      );
    });
  }

  Widget _kpiCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, ColorScheme scheme) {
    final balance = controller.balance.value;
    final isPaid = balance <= 0;
    final color = isPaid ? Colors.green.shade600 : Colors.red.shade600;
    final icon = isPaid
        ? Icons.check_circle_outline_rounded
        : Icons.warning_amber_rounded;
    final label = isPaid
        ? (balance < 0
            ? 'অতিরিক্ত পরিশোধিত: ৳${_fmt.format((-balance).toInt())}'
            : 'সম্পূর্ণ পরিশোধিত')
        : 'বাকি আছে: ৳${_fmt.format(balance.toInt())}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('এই মাসের হিসাব',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(
      BuildContext context, SrPaymentModel p, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.payments_rounded,
              color: Colors.green, size: 22),
        ),
        title: Text(
          '৳ ${_fmt.format(p.amount.toInt())}',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.note.isNotEmpty)
              Text(p.note,
                  style: const TextStyle(fontSize: 12)),
            if (p.paidAt != null)
              Text(DateFormat('dd MMM yyyy, hh:mm a').format(p.paidAt!),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: p.note.isNotEmpty && p.paidAt != null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 20, color: Colors.red),
          tooltip: 'মুছুন',
          onPressed: () => _confirmDeletePayment(context, p),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePayment(
      BuildContext context, SrPaymentModel p) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('পেমেন্ট মুছবেন?'),
        content: Text('৳${p.amount.toInt()} — ${p.note.isNotEmpty ? p.note : 'কোনো বিবরণ নেই'}'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('না')),
          TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('হ্যাঁ',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await controller.deletePayment(p.id);
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await Get.dialog(
      AlertDialog(
        title: const Text('পেমেন্ট রেকর্ড করুন'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final bal = controller.balance.value;
                if (bal <= 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'বাকি: ৳${_fmt.format(bal.toInt())}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.orange),
                      ),
                    ],
                  ),
                );
              }),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: const InputDecoration(
                    labelText: 'পরিমাণ (৳)'),
                validator: (v) =>
                    (v == null || v.isEmpty || int.tryParse(v) == null)
                        ? 'পরিমাণ লিখুন'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'বিবরণ (ঐচ্ছিক)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Get.back();
              await controller.recordPayment(
                amount: double.parse(amountCtrl.text),
                note: noteCtrl.text.trim(),
              );
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }
}

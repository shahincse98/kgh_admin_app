import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_management_controller.dart';
import '../model/sr_model.dart';
import '../model/sr_payment_model.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';

class SrDetailView extends StatefulWidget {
  const SrDetailView({super.key});

  @override
  State<SrDetailView> createState() => _SrDetailViewState();
}

class _SrDetailViewState extends State<SrDetailView>
    with SingleTickerProviderStateMixin {
  late String _srId;
  late final SrManagementController ctrl;
  late final TabController _tabs;
  static final _fmt = NumberFormat('#,##,##0');

  final selectedMonth = DateTime.now().obs;
  final stats = Rxn<SrMonthStats>();
  final payments = <SrPaymentModel>[].obs;
  final loading = false.obs;

  // Always-fresh sr derived from ctrl.srList so UI reflects mutations immediately
  SrModel get sr =>
      ctrl.srList.firstWhere((s) => s.id == _srId,
          orElse: () => ctrl.srList.first);

  @override
  void initState() {
    super.initState();
    final initial = Get.arguments as SrModel;
    _srId = initial.id;
    ctrl = Get.find<SrManagementController>();
    // Ensure the SR is in srList (it always should be, but guard anyway)
    if (!ctrl.srList.any((s) => s.id == _srId)) {
      ctrl.srList.add(initial);
    }
    _tabs = TabController(length: 3, vsync: this);
    _loadMonth();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    loading.value = true;
    try {
      final m = selectedMonth.value;
      final monthKey =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final s = await ctrl.loadMonthStats(sr, m);
      final p = await ctrl.loadPayments(sr.id, monthKey);
      stats.value = s;
      payments.assignAll(p);
    } finally {
      loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(sr.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonth,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'পারফরম্যান্স'),
            Tab(text: 'ভিজিট তালিকা'),
            Tab(text: 'কল তালিকা'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _performanceTab(context, scheme),
          _shopListTab(context, scheme, isCall: false),
          _shopListTab(context, scheme, isCall: true),
        ],
      ),
    );
  }

  // ── Tab 1: Performance ───────────────────────────────────────────────────

  Widget _performanceTab(BuildContext context, ColorScheme scheme) {
    return Obx(() {
      if (loading.value && stats.value == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final s = stats.value;
      return RefreshIndicator(
        onRefresh: _loadMonth,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Month navigator
            _monthNavigator(context, scheme),
            const SizedBox(height: 14),

            if (s == null) ...[
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              // KPI grid
              _kpiGrid(context, s, scheme),
              const SizedBox(height: 14),

              // Due & frozen alert
              if (s.totalDueFromCustomers > 0)
                _dueAlert(s, scheme),
              const SizedBox(height: 14),

              // Balance card
              _balanceCard(s, scheme),
              const SizedBox(height: 14),

              // Payment history header + add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('পেমেন্ট ইতিহাস',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () =>
                        _showPaymentDialog(context, s),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('পেমেন্ট'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (payments.isEmpty)
                const SizedBox(
                  height: 60,
                  child: Center(
                      child: Text('কোনো পেমেন্ট নেই',
                          style: TextStyle(color: Colors.grey))),
                )
              else
                ...payments.map((p) => _paymentTile(context, p, scheme)),

              const SizedBox(height: 80),
            ],
          ],
        ),
      );
    });
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
              onPressed: () {
                final m = selectedMonth.value;
                selectedMonth.value = DateTime(m.year, m.month - 1);
                _loadMonth();
              },
            ),
            Obx(() => Text(
                  DateFormat('MMMM yyyy').format(selectedMonth.value),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                )),
            Obx(() {
              final m = selectedMonth.value;
              final now = DateTime.now();
              final isCurrent =
                  m.year == now.year && m.month == now.month;
              return IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: isCurrent ? Colors.grey : null),
                onPressed: isCurrent
                    ? null
                    : () {
                        selectedMonth.value = DateTime(
                            m.year, m.month + 1);
                        _loadMonth();
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _kpiGrid(
      BuildContext context, SrMonthStats s, ColorScheme scheme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth >= 700 ? 3 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: [
          _kpiCard('ডেলিভারি', '${s.totalDeliveries}',
              Icons.local_shipping_rounded, const Color(0xFF0EA5E9)),
          _kpiCard('বিক্রয়',
              '৳ ${_fmt.format(s.totalRevenue.toInt())}',
              Icons.payments_rounded, const Color(0xFF10B981)),
          _kpiCard('কমিশন (${sr.commissionPercent}%)',
              '৳ ${_fmt.format(s.commissionDue.toInt())}',
              Icons.percent_rounded, const Color(0xFF6366F1)),
          _kpiCard('বেতন',
              '৳ ${_fmt.format(sr.monthlyFixedSalary.toInt())}',
              Icons.badge_rounded, const Color(0xFFF59E0B)),
          _kpiCard('মোট প্রাপ্য',
              '৳ ${_fmt.format(s.totalDue.toInt())}',
              Icons.account_balance_wallet_rounded,
              const Color(0xFF0891B2)),
          _kpiCard('পরিশোধিত',
              '৳ ${_fmt.format(s.totalPaid.toInt())}',
              Icons.check_circle_rounded, const Color(0xFF22C55E)),
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
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _dueAlert(SrMonthStats s, ColorScheme scheme) {
    final overLimit = s.totalDueFromCustomers > sr.dueLimit;
    final color = overLimit ? Colors.red.shade600 : Colors.green.shade600;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  overLimit
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: color,
                  size: 20),
              const SizedBox(width: 8),
              Text('গ্রাহক বাকি ট্র্যাকার',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          _dueRow('মোট গ্রাহক বাকি',
              '৳ ${_fmt.format(s.totalDueFromCustomers.toInt())}', scheme),
          _dueRow('বাকি লিমিট',
              '৳ ${_fmt.format(sr.dueLimit.toInt())}', scheme),
          if (overLimit) ...[
            const Divider(height: 16),
            _dueRow(
              'অতিরিক্ত (ফ্রিজড)',
              '৳ ${_fmt.format(s.frozenAmount.toInt())}',
              scheme,
              valueColor: Colors.red,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ বাকি লিমিট ছাড়িয়ে গেছে। ৳${_fmt.format(s.frozenAmount.toInt())} বেতন ফ্রিজ। '
                'অতিরিক্ত বাকি আদায় করলে ফ্রিজ মুক্ত হবে।',
                style: const TextStyle(
                    fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dueRow(String label, String value, ColorScheme scheme,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: scheme.onSurface.withAlpha(160),
                  fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: valueColor ?? scheme.onSurface)),
        ],
      ),
    );
  }

  Widget _balanceCard(SrMonthStats s, ColorScheme scheme) {
    final isPaid = s.netPayable <= 0;
    final color = isPaid ? Colors.green.shade600 : Colors.orange.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                  isPaid
                      ? Icons.check_circle_outline_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: color,
                  size: 28),
              const SizedBox(width: 10),
              Text('এই মাসের সারসংক্ষেপ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          _dueRow('মোট প্রাপ্য',
              '৳ ${_fmt.format(s.totalDue.toInt())}', scheme),
          _dueRow('পরিশোধিত',
              '৳ ${_fmt.format(s.totalPaid.toInt())}', scheme),
          if (s.frozenAmount > 0)
            _dueRow('ফ্রিজড',
                '৳ ${_fmt.format(s.frozenAmount.toInt())}', scheme,
                valueColor: Colors.red),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('নেট প্রদেয়',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color)),
              Text(
                '৳ ${_fmt.format(s.netPayable.abs().toInt())}${s.netPayable < 0 ? ' (অতিরিক্ত)' : ''}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color),
              ),
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
        title: Text('৳ ${_fmt.format(p.amount.toInt())}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.note.isNotEmpty)
              Text(p.note,
                  style: const TextStyle(fontSize: 12)),
            if (p.paidAt != null)
              Text(
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(p.paidAt!),
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
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('পেমেন্ট মুছবেন?'),
      content: Text(
          '৳${p.amount.toInt()} — ${p.note.isNotEmpty ? p.note : 'কোনো বিবরণ নেই'}'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('না')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('হ্যাঁ',
                style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      await ctrl.deletePayment(p.id);
      await _loadMonth();
    }
  }

  Future<void> _showPaymentDialog(
      BuildContext context, SrMonthStats s) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final m = selectedMonth.value;
    final monthKey =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';

    await Get.dialog(AlertDialog(
      title: const Text('পেমেন্ট রেকর্ড'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Balance info
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('বাকি: ৳${_fmt.format(s.balance.toInt())}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.orange)),
                  if (s.frozenAmount > 0)
                    Text(
                        'ফ্রিজড: ৳${_fmt.format(s.frozenAmount.toInt())}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red)),
                  Text('নেট প্রদেয়: ৳${_fmt.format(s.netPayable.toInt())}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange)),
                ],
              ),
            ),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'পরিমাণ (৳)'),
              validator: (v) =>
                  (v == null || v.isEmpty || int.tryParse(v) == null)
                      ? 'পরিমাণ লিখুন'
                      : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Get.back();
            await ctrl.recordPayment(
              srId: sr.id,
              monthKey: monthKey,
              amount: double.parse(amountCtrl.text),
              note: noteCtrl.text.trim(),
            );
            await _loadMonth();
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    ));
  }

  // ── Tab 2 & 3: Shop / Call list ──────────────────────────────────────────

  Widget _shopListTab(BuildContext context, ColorScheme scheme,
      {required bool isCall}) {
    final uc = Get.find<UserController>();

    // Load today's visit logs once when this tab is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.loadVisitLogs(_srId);
    });

    return Obx(() {
      // Re-read sr from srList so it always has latest assignedShopIds
      final currentSr = sr;
      final assigned = isCall
          ? ctrl.getCallContacts(currentSr)
          : ctrl.getAssignedShops(currentSr);

      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        body: assigned.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        isCall
                            ? Icons.phone_missed_rounded
                            : Icons.store_mall_directory_rounded,
                        size: 56,
                        color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text(
                        isCall
                            ? 'কোনো কল তালিকা নেই'
                            : 'কোনো দোকান নির্ধারিত নেই',
                        style: TextStyle(
                            color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                itemCount: assigned.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 6),
                itemBuilder: (_, i) => _userListTile(
                    context, assigned[i], scheme,
                    isCall: isCall, isAssigned: true),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              _showAssignDialog(context, scheme, uc, isCall: isCall),
          icon: const Icon(Icons.add_rounded),
          label: Text(isCall ? 'কল তালিকায় যোগ করুন' : 'দোকান যোগ করুন'),
        ),
      );
    });
  }

  Widget _userListTile(BuildContext context, UserModel u, ColorScheme scheme,
      {required bool isCall, required bool isAssigned}) {
    // Fetch visit status for this shop from today's visit logs
    final visitStatus = ctrl.getVisitStatus(_srId, u.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: visitStatus != null
                  ? _visitColor(visitStatus).withAlpha(40)
                  : scheme.secondaryContainer,
              child: Icon(Icons.store_rounded,
                  color: visitStatus != null
                      ? _visitColor(visitStatus)
                      : scheme.onSecondaryContainer,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.shopName.isNotEmpty ? u.shopName : u.proprietorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${u.proprietorName}  •  ${u.phone}',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withAlpha(160))),
                  if (u.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: scheme.onSurface.withAlpha(120)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(u.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface.withAlpha(140))),
                        ),
                      ],
                    ),
                  ],                  if (!isCall) ...() {
                    final day = sr.shopDeliveryDays[u.id];
                    if (day == null || day.isEmpty) return <Widget>[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showDayPickerForExisting(context, scheme, u.id, u.shopName.isNotEmpty ? u.shopName : u.proprietorName),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 11,
                                color: scheme.primary.withAlpha(160)),
                            const SizedBox(width: 4),
                            Text('ডেলিভারি দিন নির্ধারণ করুন',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.primary.withAlpha(180),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ];
                    return [
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: () => _showDayPickerForExisting(context, scheme, u.id, u.shopName.isNotEmpty ? u.shopName : u.proprietorName),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.secondary.withAlpha(22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: scheme.secondary.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_shipping_rounded, size: 11, color: scheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.secondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_rounded, size: 11, color: scheme.onSurface.withAlpha(120)),
                          ],
                        ),
                      ),
                    ];
                  }(),                  if (visitStatus != null) ...[
                    const SizedBox(height: 5),
                    _visitBadge(visitStatus),
                  ],
                ],
              ),
            ),
            if (isAssigned)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.red),
                tooltip: 'সরিয়ে দিন',
                onPressed: () => _removeAssignment(u, isCall: isCall),
              ),
          ],
        ),
      ),
    );
  }

  // Visit status badge helpers
  static const _visitStatuses = [
    ('pending', 'অপেক্ষারত'),
    ('visited', 'ভিজিট সম্পন্ন'),
    ('ordered', 'অর্ডার সম্পন্ন'),
    ('order_later', 'অর্ডার পরে দিবে'),
    ('shop_closed', 'দোকান বন্ধ'),
    ('no_order', 'অর্ডার দিবেনা'),
  ];

  Color _visitColor(String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF16A34A);
      case 'ordered':
        return const Color(0xFF7C3AED);
      case 'order_later':
        return const Color(0xFFF59E0B);
      case 'shop_closed':
        return const Color(0xFF64748B);
      case 'no_order':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF0891B2);
    }
  }

  Widget _visitBadge(String status) {
    final label = _visitStatuses
        .firstWhere((e) => e.$1 == status,
            orElse: () => (status, status))
        .$2;
    final color = _visitColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Future<void> _showDayPickerOnAdd(
      String shopId, String shopName, ColorScheme scheme) async {
    const days = [
      'রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার',
      'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার',
    ];
    await Get.dialog(AlertDialog(
      title: Text('$shopName — ডেলিভারি দিন নির্বাচন'),
      contentPadding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...days.map((d) => ListTile(
                dense: true,
                leading:
                    Icon(Icons.local_shipping_rounded, size: 18, color: scheme.secondary),
                title: Text(d),
                onTap: () async {
                  Get.back();
                  await ctrl.setShopDeliveryDay(sr.id, shopId, d);
                },
              )),
          const Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.skip_next_rounded, size: 18),
            title: const Text('এখন না'),
            onTap: () => Get.back(),
          ),
        ],
      ),
    ));
  }

  Future<void> _showDayPickerForExisting(
      BuildContext context, ColorScheme scheme, String shopId, String shopName) async {
    const days = [
      'রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার',
      'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার',
    ];
    await Get.dialog(AlertDialog(
      title: Text('$shopName — ডেলিভারি দিন'),
      contentPadding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...days.map((d) => ListTile(
                dense: true,
                leading: Icon(Icons.local_shipping_rounded,
                    size: 18, color: scheme.secondary),
                title: Text(d),
                onTap: () async {
                  Get.back();
                  await ctrl.setShopDeliveryDay(sr.id, shopId, d);
                },
              )),
          const Divider(),
          ListTile(
            dense: true,
            leading: Icon(Icons.clear_rounded,
                size: 18, color: scheme.error),
            title: Text('ডেলিভারি দিন সরান',
                style: TextStyle(color: scheme.error)),
            onTap: () async {
              Get.back();
              await ctrl.removeShopDeliveryDay(sr.id, shopId);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
      ],
    ));
  }

  Future<void> _removeAssignment(UserModel u,
      {required bool isCall}) async {
    if (isCall) {
      final updated = List<String>.from(sr.callContactIds)
        ..remove(u.id);
      await ctrl.updateAssignments(sr.id, callIds: updated);
    } else {
      final updated = List<String>.from(sr.assignedShopIds)
        ..remove(u.id);
      await ctrl.updateAssignments(sr.id, shopIds: updated);
    }
    // No setState needed — Obx watching srList auto-refreshes
  }

  Future<void> _showAssignDialog(BuildContext context, ColorScheme scheme,
      UserController uc,
      {required bool isCall}) async {
    final searchCtrl = TextEditingController();
    final searchObs = ''.obs;
    // Multi-select: set of selected user IDs (only for shop tab)
    final selected = <String>{}.obs;

    await Get.dialog(
      StatefulBuilder(builder: (ctx, _) {
        return AlertDialog(
          title: Text(isCall ? 'কল তালিকায় যোগ' : 'দোকান নির্ধারণ'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => searchObs.value = v,
                  decoration: InputDecoration(
                    hintText: 'খুঁজুন…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
                if (!isCall) ...[
                  const SizedBox(height: 6),
                  Obx(() => selected.isEmpty
                      ? const SizedBox()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('${selected.length}টি দোকান নির্বাচিত',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary)),
                            ],
                          ),
                        )),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: Obx(() {
                    final q = searchObs.value.trim().toLowerCase();
                    final alreadyIds = isCall
                        ? sr.callContactIds
                        : sr.assignedShopIds;
                    final list = uc.users
                        .where((u) =>
                            !alreadyIds.contains(u.id) &&
                            (q.isEmpty ||
                                u.shopName.toLowerCase().contains(q) ||
                                u.proprietorName.toLowerCase().contains(q) ||
                                u.phone.contains(q)))
                        .toList();
                    if (list.isEmpty) {
                      return const Center(
                          child: Text('কোনো কাস্টমার পাওয়া যায়নি'));
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final u = list[i];
                        final isSelected = selected.contains(u.id);
                        return InkWell(
                          onTap: () async {
                            if (isCall) {
                              // Single tap → add immediately for call list
                              Get.back();
                              final updated =
                                  List<String>.from(sr.callContactIds)
                                    ..add(u.id);
                              await ctrl.updateAssignments(sr.id,
                                  callIds: updated);
                            } else {
                              // Toggle selection for shop tab
                              if (isSelected) {
                                selected.remove(u.id);
                              } else {
                                selected.add(u.id);
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: scheme.primary.withAlpha(120),
                                      width: 1)
                                  : null,
                            ),
                            child: ListTile(
                              dense: true,
                              leading: isCall
                                  ? null
                                  : AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: isSelected
                                          ? Icon(Icons.check_box_rounded,
                                              key: const ValueKey(true),
                                              color: scheme.primary,
                                              size: 22)
                                          : Icon(
                                              Icons.check_box_outline_blank_rounded,
                                              key: const ValueKey(false),
                                              color: scheme.onSurface
                                                  .withAlpha(120),
                                              size: 22),
                                    ),
                              title: Text(
                                  u.shopName.isNotEmpty
                                      ? u.shopName
                                      : u.proprietorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(u.phone,
                                      style:
                                          const TextStyle(fontSize: 12)),
                                  if (u.address.isNotEmpty)
                                    Text(u.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                ],
                              ),
                              isThreeLine: u.address.isNotEmpty,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: const Text('বাতিল')),
            if (!isCall)
              Obx(() => ElevatedButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            final ids = selected.toList();
                            Get.back();
                            final updated =
                                List<String>.from(sr.assignedShopIds)
                                  ..addAll(
                                      ids.where((id) => !sr.assignedShopIds.contains(id)));
                            await ctrl.updateAssignments(sr.id,
                                shopIds: updated);
                            // Ask delivery day for each added shop
                            for (final id in ids) {
                              final u = uc.users.firstWhere(
                                  (u) => u.id == id,
                                  orElse: () => uc.users.first);
                              await _showDayPickerOnAdd(
                                  id,
                                  u.shopName.isNotEmpty
                                      ? u.shopName
                                      : u.proprietorName,
                                  scheme);
                            }
                          },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Obx(() => Text(
                          selected.isEmpty
                              ? 'যোগ করুন'
                              : '${selected.length}টি যোগ করুন',
                        )),
                  )),
            if (isCall)
              TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('বন্ধ করুন')),
          ],
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_management_controller.dart';
import '../model/sr_model.dart';
import '../../../routes/app_routes.dart';

class SrManagementView extends GetView<SrManagementController> {
  const SrManagementView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('SR ব্যবস্থাপনা',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetchSrList,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('নতুন SR যোগ করুন',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              onChanged: (v) => controller.searchText.value = v,
              decoration: InputDecoration(
                hintText: 'নাম বা ফোন দিয়ে খুঁজুন…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filteredList;
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_rounded,
                          size: 56, color: scheme.onSurface.withAlpha(60)),
                      const SizedBox(height: 12),
                      Text('কোনো SR পাওয়া যায়নি',
                          style: TextStyle(
                              color: scheme.onSurface.withAlpha(120))),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: controller.fetchSrList,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(14, 0, 14, 120),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _SrCard(sr: list[i], scheme: scheme, fmt: _fmt),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditDialog(BuildContext context,
      {SrModel? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');
    final emailCtrl =
        TextEditingController(text: existing?.email ?? '');
    final passwordCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(
        text: existing?.monthlyFixedSalary.toInt().toString() ?? '');
    final commCtrl = TextEditingController(
        text: existing?.commissionPercent.toString() ?? '6');
    final dueLimitCtrl = TextEditingController(
        text: existing?.dueLimit.toInt().toString() ?? '60000');
    final isActive = (existing?.isActive ?? true).obs;
    final showPass = false.obs;
    final saving = false.obs;
    final formKey = GlobalKey<FormState>();
    final isNew = existing == null;

    await Get.dialog(
      AlertDialog(
        title: Text(isNew ? 'নতুন SR যোগ করুন' : 'SR সম্পাদনা'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'নাম *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'নাম লিখুন' : null),
                const SizedBox(height: 10),
                _field(phoneCtrl, 'ফোন নং *',
                    keyboard: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'ফোন নং লিখুন' : null),
                const SizedBox(height: 10),
                _field(emailCtrl, 'ইমেইল (লগইনের জন্য) *',
                    keyboard: TextInputType.emailAddress,
                    readOnly: !isNew, // email can't be changed after creation
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'ইমেইল আবশ্যক';
                      if (!GetUtils.isEmail(v)) return 'সঠিক ইমেইল দিন';
                      return null;
                    }),
                const SizedBox(height: 10),
                _field(salaryCtrl, 'মাসিক বেতন (৳) *',
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'বেতন লিখুন' : null),
                const SizedBox(height: 10),
                _field(commCtrl, 'কমিশন % *',
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'কমিশন % লিখুন' : null),
                const SizedBox(height: 10),
                _field(dueLimitCtrl, 'বাকি লিমিট (৳) *',
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'বাকি লিমিট লিখুন' : null),
                if (isNew) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('লগইন পাসওয়ার্ড',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => TextFormField(
                        controller: passwordCtrl,
                        obscureText: !showPass.value,
                        decoration: InputDecoration(
                          labelText: 'পাসওয়ার্ড *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(showPass.value
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            onPressed: () =>
                                showPass.value = !showPass.value,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'পাসওয়ার্ড দিন';
                          }
                          if (v.length < 6) {
                            return 'কমপক্ষে ৬ অক্ষর';
                          }
                          return null;
                        },
                      )),
                  const SizedBox(height: 10),
                  Obx(() => TextFormField(
                        controller: confirmPassCtrl,
                        obscureText: !showPass.value,
                        decoration: const InputDecoration(
                          labelText: 'পাসওয়ার্ড নিশ্চিত করুন *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v != passwordCtrl.text) {
                            return 'পাসওয়ার্ড মিলছে না';
                          }
                          return null;
                        },
                      )),
                ],
                const SizedBox(height: 12),
                Obx(() => SwitchListTile(
                      title: const Text('সক্রিয়'),
                      value: isActive.value,
                      onChanged: (v) => isActive.value = v,
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('বাতিল')),
          Obx(() => ElevatedButton(
                onPressed: saving.value
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        saving.value = true;
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'monthlyFixedSalary':
                              double.tryParse(salaryCtrl.text) ?? 0,
                          'commissionPercent':
                              double.tryParse(commCtrl.text) ?? 6,
                          'dueLimit':
                              double.tryParse(dueLimitCtrl.text) ?? 60000,
                          'isActive': isActive.value,
                        };
                        Get.back();
                        if (isNew) {
                          await controller.addSr(data,
                              password: passwordCtrl.text);
                        } else {
                          await controller.updateSr(existing!.id, data);
                        }
                        saving.value = false;
                      },
                child: saving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('সংরক্ষণ'),
              )),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard,
      String? Function(String?)? validator,
      bool readOnly = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.withAlpha(30) : null,
      ),
    );
  }
}

// ── SR Card Widget ────────────────────────────────────────────────────────────

class _SrCard extends StatelessWidget {
  final SrModel sr;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _SrCard(
      {required this.sr, required this.scheme, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SrManagementController>();

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(AppRoutes.srDetail, arguments: sr),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: sr.isActive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    child: Icon(Icons.person_rounded,
                        color: sr.isActive
                            ? scheme.primary
                            : scheme.onSurface.withAlpha(80)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sr.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Text(sr.phone,
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(160),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  // Active badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (sr.isActive
                              ? Colors.green
                              : Colors.grey)
                          .withAlpha(22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (sr.isActive ? Colors.green : Colors.grey)
                            .withAlpha(80),
                      ),
                    ),
                    child: Text(
                      sr.isActive ? 'সক্রিয়' : 'নিষ্ক্রিয়',
                      style: TextStyle(
                        color: sr.isActive ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(Icons.badge_rounded,
                      'বেতন: ৳${fmt.format(sr.monthlyFixedSalary.toInt())}',
                      scheme),
                  _chip(Icons.percent_rounded,
                      'কমিশন: ${sr.commissionPercent}%', scheme),
                  _chip(Icons.warning_amber_rounded,
                      'বাকি লিমিট: ৳${fmt.format(sr.dueLimit.toInt())}',
                      scheme),
                  _chip(Icons.store_rounded,
                      '${sr.assignedShopIds.length} দোকান', scheme),
                  _chip(Icons.phone_rounded,
                      '${sr.callContactIds.length} কন্টাক্ট', scheme),
                  _chip(
                      sr.uid.isNotEmpty
                          ? Icons.verified_user_rounded
                          : Icons.no_accounts_rounded,
                      sr.uid.isNotEmpty ? 'লগইন আছে' : 'লগইন নেই',
                      scheme,
                      color: sr.uid.isNotEmpty ? Colors.green : Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddEditDialog(context, ctrl, sr),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('সম্পাদনা'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () =>
                        _showPasswordResetDialog(context, ctrl, sr),
                    icon: const Icon(Icons.lock_reset_rounded, size: 16),
                    label: const Text('পাসওয়ার্ড'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.purple),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => ctrl.toggleActive(sr),
                    icon: Icon(
                        sr.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded,
                        size: 16),
                    label: Text(sr.isActive ? 'নিষ্ক্রিয়' : 'সক্রিয়'),
                    style: TextButton.styleFrom(
                      foregroundColor: sr.isActive
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () =>
                        _confirmDelete(context, ctrl, sr),
                    icon:
                        const Icon(Icons.delete_rounded, size: 16),
                    label: const Text('মুছুন'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme scheme,
      {Color? color}) {
    final c = color ?? scheme.onSurface.withAlpha(160);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? scheme.onSurface).withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: color != null
            ? Border.all(color: color.withAlpha(80))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: c,
                  fontWeight: color != null ? FontWeight.w600 : null)),
        ],
      ),
    );
  }

  Future<void> _showAddEditDialog(
      BuildContext context, SrManagementController ctrl, SrModel sr) async {
    final nameCtrl = TextEditingController(text: sr.name);
    final phoneCtrl = TextEditingController(text: sr.phone);
    final emailCtrl = TextEditingController(text: sr.email);
    final salaryCtrl = TextEditingController(
        text: sr.monthlyFixedSalary.toInt().toString());
    final commCtrl =
        TextEditingController(text: sr.commissionPercent.toString());
    final dueLimitCtrl =
        TextEditingController(text: sr.dueLimit.toInt().toString());
    final isActive = sr.isActive.obs;
    final formKey = GlobalKey<FormState>();

    await Get.dialog(
      AlertDialog(
        title: const Text('SR সম্পাদনা'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(nameCtrl, 'নাম *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'নাম লিখুন' : null),
                const SizedBox(height: 10),
                _formField(phoneCtrl, 'ফোন নং *',
                    keyboard: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty
                        ? 'ফোন নং লিখুন'
                        : null),
                const SizedBox(height: 10),
                // Email is read-only for existing SR
                _formField(emailCtrl, 'ইমেইল',
                    keyboard: TextInputType.emailAddress,
                    readOnly: true),
                const SizedBox(height: 10),
                _formField(salaryCtrl, 'মাসিক বেতন (৳) *',
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'বেতন লিখুন' : null),
                const SizedBox(height: 10),
                _formField(commCtrl, 'কমিশন % *',
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'লিখুন' : null),
                const SizedBox(height: 10),
                _formField(dueLimitCtrl, 'বাকি লিমিট (৳) *',
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'লিখুন' : null),
                const SizedBox(height: 12),
                Obx(() => SwitchListTile(
                      title: const Text('সক্রিয়'),
                      value: isActive.value,
                      onChanged: (v) => isActive.value = v,
                      contentPadding: EdgeInsets.zero,
                    )),
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
              if (!formKey.currentState!.validate()) return;
              Get.back();
              await ctrl.updateSr(sr.id, {
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'monthlyFixedSalary':
                    double.tryParse(salaryCtrl.text) ?? sr.monthlyFixedSalary,
                'commissionPercent':
                    double.tryParse(commCtrl.text) ?? sr.commissionPercent,
                'dueLimit': double.tryParse(dueLimitCtrl.text) ??
                    sr.dueLimit,
                'isActive': isActive.value,
              });
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPasswordResetDialog(
      BuildContext context, SrManagementController ctrl, SrModel sr) async {
    await Get.dialog(AlertDialog(
      title: Text('পাসওয়ার্ড রিসেট — ${sr.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sr.email} ঠিকানায় একটি পাসওয়ার্ড রিসেট লিংক পাঠানো হবে।\n\nSR সেই লিংক ব্যবহার করে নতুন পাসওয়ার্ড সেট করতে পারবে।',
            style: const TextStyle(fontSize: 14),
          ),
          if (sr.uid.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'এই SR এর Firebase অ্যাকাউন্ট এখনো তৈরি হয়নি।',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
        ElevatedButton.icon(
          onPressed: sr.uid.isEmpty || sr.email.isEmpty
              ? null
              : () async {
                  Get.back();
                  await ctrl.resetSrPassword(
                      sr: sr, newPassword: '');
                },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('লিংক পাঠান'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white),
        ),
      ],
    ));
  }

  Widget _formField(TextEditingController ctrl, String label,
      {TextInputType? keyboard,
      String? Function(String?)? validator,
      bool readOnly = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.withAlpha(30) : null,
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, SrManagementController ctrl, SrModel sr) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('SR মুছবেন?'),
      content: Text('${sr.name} — এই SR-এর সমস্ত তথ্য মুছে যাবে।'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('না')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('হ্যাঁ, মুছুন',
                style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) await ctrl.deleteSr(sr.id);
  }
}

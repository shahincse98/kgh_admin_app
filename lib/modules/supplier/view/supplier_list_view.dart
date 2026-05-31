import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/supplier_controller.dart';
import '../model/supplier_model.dart';
import '../../purchase/model/purchase_entry_model.dart';
import 'package:intl/intl.dart';

// ─── List View ───────────────────────────────────────────────────────────────

class SupplierListView extends GetView<SupplierController> {
  const SupplierListView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchCtrl = TextEditingController();
    final searchText = ''.obs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('সাপ্লাইয়ার'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: () => controller.fetchSuppliers(force: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('সাপ্লাইয়ার যোগ করুন'),
        onPressed: () => _showSupplierForm(context),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: searchCtrl,
              onChanged: (v) => searchText.value = v.toLowerCase(),
              decoration: InputDecoration(
                hintText: 'সাপ্লাইয়ার সার্চ করুন...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: Obx(() => searchText.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchCtrl.clear();
                          searchText.value = '';
                        },
                      )
                    : const SizedBox.shrink()),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // ── List ──
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final all = controller.suppliers;
              final query = searchText.value;
              final filtered = query.isEmpty
                  ? all
                  : all
                      .where((s) =>
                          s.shopName.toLowerCase().contains(query) ||
                          s.ownerName.toLowerCase().contains(query) ||
                          s.phone.contains(query))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_mall_directory_outlined,
                          size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      Text(
                        query.isEmpty
                            ? 'কোনো সাপ্লাইয়ার নেই'
                            : '"$query" পাওয়া যায়নি',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      if (query.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'নিচের + বোতাম চাপুন সাপ্লাইয়ার যোগ করতে',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => controller.fetchSuppliers(force: true),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _SupplierCard(supplier: filtered[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showSupplierForm(BuildContext context, [SupplierModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierForm(existing: existing),
    );
  }
}

// ─── Supplier Card ─────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = Get.find<SupplierController>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.toNamed('/suppliers/detail', arguments: supplier),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    supplier.shopName.isNotEmpty
                        ? supplier.shopName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.shopName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (supplier.ownerName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              supplier.ownerName,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (supplier.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              supplier.phone,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (supplier.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                supplier.address,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: cs.onSurfaceVariant),
                onSelected: (v) async {
                  if (v == 'edit') {
                    await Future.delayed(Duration.zero);
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20))),
                        builder: (_) =>
                            _SupplierForm(existing: supplier),
                      );
                    }
                  } else if (v == 'delete') {
                    final ok = await Get.dialog<bool>(AlertDialog(
                      title: const Text('সাপ্লাইয়ার মুছবেন?'),
                      content: Text(
                          '"${supplier.shopName}" কে স্থায়ীভাবে মুছে ফেলা হবে।'),
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
                    if (ok == true) {
                      await ctrl.deleteSupplier(supplier);
                      Get.snackbar(
                        'মুছে ফেলা হয়েছে',
                        '"${supplier.shopName}" সরিয়ে দেওয়া হয়েছে',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 17),
                      SizedBox(width: 10),
                      Text('সম্পাদনা'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 17, color: Colors.red.shade400),
                      const SizedBox(width: 10),
                      Text('মুছে ফেলুন',
                          style:
                              TextStyle(color: Colors.red.shade400)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add / Edit Form ────────────────────────────────────────────────────────

class _SupplierForm extends StatefulWidget {
  final SupplierModel? existing;
  const _SupplierForm({this.existing});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _shopCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _shopCtrl.text = widget.existing!.shopName;
      _ownerCtrl.text = widget.existing!.ownerName;
      _phoneCtrl.text = widget.existing!.phone;
      _addressCtrl.text = widget.existing!.address;
    }
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shopName = _shopCtrl.text.trim();
    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('দোকানের নাম আবশ্যিক')));
      return;
    }
    setState(() => _saving = true);
    final ctrl = Get.find<SupplierController>();
    try {
      if (_isEdit) {
        await ctrl.updateSupplier(
          widget.existing!,
          shopName: shopName,
          ownerName: _ownerCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
        Get.snackbar(
          'আপডেট হয়েছে',
          '"$shopName" সফলভাবে আপডেট করা হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        await ctrl.addSupplier(
          shopName: shopName,
          ownerName: _ownerCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
        Get.snackbar(
          'যোগ হয়েছে',
          '"$shopName" সফলভাবে যোগ করা হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('সংরক্ষণ করতে সমস্যা হয়েছে')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Icon(Icons.store_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isEdit ? 'সাপ্লাইয়ার সম্পাদনা' : 'নতুন সাপ্লাইয়ার',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fields
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _field(
                    controller: _shopCtrl,
                    label: 'দোকানের নাম *',
                    icon: Icons.storefront_rounded,
                    autofocus: !_isEdit,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _ownerCtrl,
                    label: 'মালিকের নাম',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _phoneCtrl,
                    label: 'ফোন নম্বর',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _addressCtrl,
                    label: 'ঠিকানা',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Icon(
                              _isEdit
                                  ? Icons.save_rounded
                                  : Icons.add_business_rounded,
                            ),
                      label: Text(_isEdit ? 'আপডেট করুন' : 'সংরক্ষণ করুন'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─── Supplier Picker Bottom Sheet (used in Purchase) ────────────────────────

class SupplierPickerSheet extends StatefulWidget {
  const SupplierPickerSheet({super.key});

  @override
  State<SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<SupplierPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SupplierController>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Icon(Icons.store_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('সাপ্লাইয়ার বেছে নিন',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'সার্চ করুন...',
              prefixIcon: const Icon(Icons.search_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Flexible(
          child: Obx(() {
            final all = ctrl.suppliers;
            final filtered = _query.isEmpty
                ? all
                : all
                    .where((s) =>
                        s.shopName.toLowerCase().contains(_query) ||
                        s.ownerName.toLowerCase().contains(_query))
                    .toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  all.isEmpty
                      ? 'কোনো সাপ্লাইয়ার নেই। আগে সাপ্লাইয়ার যোগ করুন।'
                      : '"$_query" পাওয়া যায়নি',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      s.shopName.isNotEmpty
                          ? s.shopName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  title: Text(s.shopName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: s.ownerName.isNotEmpty ? Text(s.ownerName) : null,
                  trailing: s.phone.isNotEmpty
                      ? Text(s.phone,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant))
                      : null,
                  onTap: () => Navigator.of(context).pop(s),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

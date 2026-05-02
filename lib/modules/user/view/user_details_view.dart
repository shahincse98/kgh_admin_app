import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kgh_admin_app/modules/user/controller/user_controller.dart';
import 'package:kgh_admin_app/modules/product/controller/product_controller.dart';
import 'package:kgh_admin_app/modules/product/model/product_model.dart';
import '../model/user_model.dart';
import '../model/user_order_model.dart';
import '../model/user_replace_model.dart';
import 'order_details_view.dart';

class UserDetailsView extends StatefulWidget {
  final UserModel user;

  const UserDetailsView({super.key, required this.user});

  @override
  State<UserDetailsView> createState() => _UserDetailsViewState();
}

class _UserDetailsViewState extends State<UserDetailsView>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<UserController>();
  List<UserOrderModel> orders = [];
  List<UserReplaceModel> replaces = [];
  bool loading = true;
  late TabController _tabs;
  late int _currentDue;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _currentDue = widget.user.totalDue;
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      controller.fetchUserOrders(widget.user.id),
      controller.fetchUserReplaces(widget.user.id),
    ]);
    if (mounted) {
      setState(() {
        orders = results[0] as List<UserOrderModel>;
        replaces = results[1] as List<UserReplaceModel>;
        loading = false;
      });
    }
  }

  String _fmt(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(u.shopName),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: 'Orders (${orders.length})',
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
            ),
            Tab(
              text: 'Replaces (${replaces.length})',
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          if (_tabs.index != 1) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showAddReplaceDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Replace যোগ করুন'),
          );
        },
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ordersTab(u),
                _replacesTab(),
              ],
            ),
    );
  }

  Widget _ordersTab(UserModel u) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoCard(u),
        const SizedBox(height: 14),
        Text(
          'Order History (${orders.length})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('কোনো order নেই', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...orders.map((o) {
            final date = o.createdAt?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text('Order: ${o.id}'),
                subtitle: Text(
                  '${date != null ? _fmt(date) : ''} | ${o.status} | ৳${o.totalAmount}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Get.to(() => OrderDetailsView(order: o)),
              ),
            );
          }),
      ],
    );
  }

  Widget _replacesTab() {
    if (replaces.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('কোনো replace নেই', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('নিচের + বাটনে ক্লিক করে যোগ করুন',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: replaces.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = replaces[i];
        return Card(
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.orange, size: 22),
            ),
            title: Text(r.productName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('পরিমাণ: ${r.quantity}টি'),
                if (r.note.isNotEmpty) Text(r.note),
                Text(_fmt(r.date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            isThreeLine: r.note.isNotEmpty,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteReplace(r),
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(UserModel u) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.shopName,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Owner: ${u.proprietorName}'),
            Text('Phone: ${u.phone}'),
            Text('Email: ${u.email}'),
            Text('Address: ${u.address}'),
            Text('Delivery: ${u.deliveryDay}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'বাকি পাওনা: ৳$_currentDue',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.red),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showEditDueDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(60)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text('এডিট',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReplace(UserReplaceModel r) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Replace মুছবেন?'),
      content: Text('${r.productName} — ${r.quantity}টি'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('না')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child:
                const Text('হ্যাঁ', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok != true) return;

    await controller.deleteUserReplace(
        widget.user.id, r.id, r.productId, r.quantity);
    setState(() => replaces.removeWhere((e) => e.id == r.id));
  }

  Future<void> _showEditDueDialog() async {
    final ctrl = TextEditingController(text: _currentDue.toString());
    final formKey = GlobalKey<FormState>();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('বাকি পাওনা সম্পাদনা'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'পরিমাণ',
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (int.tryParse(v?.trim() ?? '') == null)
                    ? 'সঠিক সংখ্যা লিখুন'
                    : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Get.back(result: true);
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final newAmt = int.parse(ctrl.text.trim());
    await controller.updateTotalDue(widget.user.id, newAmt);
    if (mounted) setState(() => _currentDue = newAmt);
  }

  Future<void> _showAddReplaceDialog(BuildContext context) async {
    final productCtrl = Get.find<ProductController>();
    final noteCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final searchCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dateObs = DateTime.now().obs;
    final selectedProduct = Rx<ProductModel?>(null);
    final searchQuery = ''.obs;
    final showSuggestions = false.obs;

    await Get.dialog(
      AlertDialog(
        title: const Text('Replace যোগ করুন'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product picker ──
                  const Text('প্রডাক্ট *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Obx(() {
                    if (selectedProduct.value != null) {
                      final p = selectedProduct.value!;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.green.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            if (p.images.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  p.images.first,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.inventory_2_rounded,
                                          size: 36),
                                ),
                              )
                            else
                              const Icon(Icons.inventory_2_rounded,
                                  size: 36, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Text(
                                      'স্টক: ${p.stock} | ৳${p.wholesalePrice}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 16, color: Colors.grey),
                              onPressed: () {
                                selectedProduct.value = null;
                                searchCtrl.clear();
                                searchQuery.value = '';
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    // Search + browse row
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'প্রডাক্ট খুঁজুন...',
                                  prefixIcon:
                                      Icon(Icons.search_rounded, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  searchQuery.value = v.toLowerCase();
                                  showSuggestions.value =
                                      v.trim().isNotEmpty;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Browse',
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showProductBrowseSheet(
                                        selectedProduct),
                                child:
                                    const Icon(Icons.grid_view_rounded),
                              ),
                            ),
                          ],
                        ),
                        // Autocomplete suggestions
                        Obx(() {
                          if (!showSuggestions.value) {
                            return const SizedBox.shrink();
                          }
                          final q = searchQuery.value;
                          final suggestions = productCtrl.products
                              .where((p) =>
                                  p.name
                                      .toLowerCase()
                                      .contains(q) ||
                                  p.brandName
                                      .toLowerCase()
                                      .contains(q) ||
                                  p.productCode
                                      .toLowerCase()
                                      .contains(q))
                              .take(6)
                              .toList();
                          if (suggestions.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: suggestions.map((p) {
                                return InkWell(
                                  onTap: () {
                                    selectedProduct.value = p;
                                    showSuggestions.value = false;
                                    searchCtrl.clear();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        if (p.images.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Image.network(
                                              p.images.first,
                                              width: 28,
                                              height: 28,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_,
                                                      __,
                                                      ___) =>
                                                  const Icon(
                                                      Icons
                                                          .inventory_2_rounded,
                                                      size: 28),
                                            ),
                                          )
                                        else
                                          const Icon(
                                              Icons.inventory_2_rounded,
                                              size: 28,
                                              color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(p.name,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ),
                                        Text(
                                          'স্টক: ${p.stock}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: p.stock > 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    );
                  }),

                  const SizedBox(height: 14),

                  // ── Qty + Note ──
                  TextFormField(
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'পরিমাণ *',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null ||
                                int.parse(v!) < 1)
                            ? 'সঠিক সংখ্যা লিখুন'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'বিবরণ (ঐচ্ছিক)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),

                  // ── Date ──
                  Obx(() => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: Text(_fmt(dateObs.value)),
                        subtitle: const Text('তারিখ'),
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
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (selectedProduct.value == null) {
                Get.snackbar(
                  'প্রডাক্ট নির্বাচন করুন',
                  'একটি প্রডাক্ট বেছে নিন',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              if (!formKey.currentState!.validate()) return;
              final sel = selectedProduct.value!;
              Get.back();
              await controller.addUserReplace(
                widget.user.id,
                shopName: widget.user.shopName,
                productName: sel.name,
                productId: sel.id,
                quantity: int.parse(quantityCtrl.text),
                note: noteCtrl.text.trim(),
                date: dateObs.value,
              );
              final fresh =
                  await controller.fetchUserReplaces(widget.user.id);
              if (mounted) setState(() => replaces = fresh);
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductBrowseSheet(
      Rx<ProductModel?> selectedProduct) async {
    final productCtrl = Get.find<ProductController>();
    final sheetSearch = ''.obs;

    await Get.bottomSheet(
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.white,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Text('প্রডাক্ট বেছে নিন',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Get.back()),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) =>
                        sheetSearch.value = v.toLowerCase(),
                    decoration: const InputDecoration(
                      hintText: 'খুঁজুন...',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final q = sheetSearch.value;
                    final list = productCtrl.products
                        .where((p) =>
                            q.isEmpty ||
                            p.name.toLowerCase().contains(q) ||
                            p.brandName.toLowerCase().contains(q) ||
                            p.productCategory
                                .toLowerCase()
                                .contains(q))
                        .toList();
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return ListTile(
                          leading: p.images.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child: Image.network(
                                    p.images.first,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                            Icons.inventory_2_rounded),
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_rounded),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${p.productCategory} | স্টক: ${p.stock}'),
                          trailing: Text('৳${p.wholesalePrice}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          onTap: () {
                            selectedProduct.value = p;
                            Get.back();
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

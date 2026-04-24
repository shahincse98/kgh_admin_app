import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kgh_admin_app/modules/user/controller/user_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
            Text('Total Due: ৳${u.totalDue}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
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

  Future<void> _showAddReplaceDialog(BuildContext context) async {
    final productNameCtrl = TextEditingController();
    final productIdCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    final dateObs = DateTime.now().obs;
    final formKey = GlobalKey<FormState>();

    await Get.dialog(AlertDialog(
      title: const Text('Replace যোগ করুন'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: productNameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name লিখুন' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: productIdCtrl,
                decoration: const InputDecoration(
                    labelText: 'Product ID (ঐচ্ছিক)',
                    hintText: 'Firestore product doc ID'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'পরিমাণ *'),
                validator: (v) =>
                    (int.tryParse(v ?? '') == null || int.parse(v!) < 1)
                        ? 'সঠিক সংখ্যা লিখুন'
                        : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'),
              ),
              const SizedBox(height: 10),
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
      actions: [
        TextButton(
            onPressed: () => Get.back(), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Get.back();
            await controller.addUserReplace(
              widget.user.id,
              productName: productNameCtrl.text.trim(),
              productId: productIdCtrl.text.trim(),
              quantity: int.parse(quantityCtrl.text),
              note: noteCtrl.text.trim(),
              date: dateObs.value,
            );
            // Reload replaces
            final fresh =
                await controller.fetchUserReplaces(widget.user.id);
            if (mounted) setState(() => replaces = fresh);
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    ));
  }
}

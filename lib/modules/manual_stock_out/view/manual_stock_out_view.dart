import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/manual_stock_out_controller.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../../widgets/responsive.dart';
import '../../../routes/app_routes.dart';

class ManualStockOutView extends StatefulWidget {
  const ManualStockOutView({super.key});

  @override
  State<ManualStockOutView> createState() => _ManualStockOutViewState();
}

class _ManualStockOutViewState extends State<ManualStockOutView> {
  final controller = Get.find<ManualStockOutController>();
  final pc = Get.find<ProductController>();
  final uc = Get.find<UserController>();

  final _dateCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##,##0');

  DateTime _selectedDate = DateTime.now();
  final _selectedItems = <_CartItem>[].obs;
  bool _submitting = false;
  String? _selectedUserId;
  String _selectedUserAddress = '';

  // Replace handling
  final _pendingReplaces = <Map<String, dynamic>>[].obs;
  final _replaceResolutions = <String, _ReplaceResolution>{}.obs;
  final _newReplaces = <_NewReplace>[].obs;
  bool _loadingReplaces = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd MMM yyyy').format(_selectedDate);
    _memoCtrl.text = '#M${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    if (pc.products.isEmpty) pc.fetchProducts();
    if (uc.users.isEmpty) uc.fetchUsers();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  int get _totalQty => _selectedItems.fold(0, (s, i) => s + i.quantity);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('ম্যানুয়াল স্টক আউট', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.manualStockOutHistory),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('ইতিহাস'),
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(scheme),
              const SizedBox(height: 14),
              _dateAndMemoCard(scheme),
              const SizedBox(height: 14),
              _customerCard(scheme),
              const SizedBox(height: 14),
              _productsCard(scheme),
              const SizedBox(height: 14),
              if (_selectedUserId != null) _replaceSection(scheme),
              const SizedBox(height: 20),
              _submitButton(scheme),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Info card ─────────────────────────────────────────────
  Widget _infoCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: const Color(0xFFD97706).withAlpha(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: const Color(0xFFD97706).withAlpha(60))),
      child: const Padding(padding: EdgeInsets.all(14), child: Row(children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
        SizedBox(width: 12),
        Expanded(child: Text('তারিখ, কাস্টমার ও প্রডাক্ট সিলেক্ট করে স্টক আউট করুন। রিপ্লেস প্রডাক্টও ম্যানেজ করতে পারবেন।', style: TextStyle(fontSize: 13, color: Color(0xFF92400E)))),
      ])),
    );
  }

  // ─── Date + Memo card ─────────────────────────────────────
  Widget _dateAndMemoCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('তারিখ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(
                controller: _dateCtrl, readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (picked != null) { setState(() { _selectedDate = picked; _dateCtrl.text = DateFormat('dd MMM yyyy').format(picked); }); }
                },
                decoration: InputDecoration(prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('মেমো নং', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(controller: _memoCtrl, decoration: InputDecoration(prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─── Customer card ────────────────────────────────────────
  Widget _customerCard(ColorScheme scheme) {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('কাস্টমার / দোকানের নাম *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          Autocomplete<UserModel>(
            initialValue: _customerCtrl.text.isNotEmpty ? TextEditingValue(text: _customerCtrl.text) : null,
            optionsBuilder: (v) {
              if (v.text.isEmpty) return uc.users;
              final q = v.text.toLowerCase();
              return uc.users.where((u) => u.shopName.toLowerCase().contains(q) || u.proprietorName.toLowerCase().contains(q) || u.phone.contains(q));
            },
            displayStringForOption: (u) => u.shopName,
            fieldViewBuilder: (context, textCtrl, focusNode, onSubmitted) {
              if (textCtrl.text != _customerCtrl.text && textCtrl.text.isEmpty) textCtrl.text = _customerCtrl.text;
              return TextField(
                controller: textCtrl, focusNode: focusNode,
                onChanged: (v) { _customerCtrl.text = v; if (_selectedUserId != null) { setState(() { _selectedUserId = null; _phoneCtrl.clear(); }); } },
                decoration: InputDecoration(
                  hintText: 'দোকানের নাম লিখে সার্চ করুন…',
                  prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_drop_down_rounded), tooltip: 'সব দোকান', onPressed: () => _showUserPicker(scheme)),
                  filled: true, fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              );
            },
            onSelected: (u) { setState(() { _customerCtrl.text = u.shopName; _phoneCtrl.text = u.phone; _selectedUserId = u.id; _selectedUserAddress = u.address; }); _fetchPendingReplaces(u.id); },
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(elevation: 4, borderRadius: BorderRadius.circular(10), clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) {
                    final u = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(u.shopName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('${u.phone}${u.address.isNotEmpty ? '\n${u.address}' : ''}${u.isBlocked ? ' | ব্লক' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: u.isBlocked ? Colors.red : null)),
                      trailing: u.isBlocked ? const Icon(Icons.block_rounded, size: 16, color: Colors.red) : null,
                      onTap: u.isBlocked ? () => Get.snackbar('ব্লক', '${u.shopName} ব্লক', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white) : () => onSelected(u),
                    );
                  }))),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('ফোন নাম্বার', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(width: 8),
            if (_selectedUserId != null) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF16A34A).withAlpha(20), borderRadius: BorderRadius.circular(6)), child: const Text('Auto', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 4),
          TextField(
            controller: _phoneCtrl, keyboardType: TextInputType.phone,
            decoration: InputDecoration(hintText: '01XXXXXXXXX', prefixIcon: const Icon(Icons.phone_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ),
          if (_selectedUserId != null) ...[
            const SizedBox(height: 4),
            Text('ইউজার: ${_customerCtrl.text}${_selectedUserAddress.isNotEmpty ? ' | ${_selectedUserAddress}' : ''}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  void _showUserPicker(ColorScheme scheme) {
    String query = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final displayed = query.isEmpty ? uc.users.toList() : uc.users.where((u) => u.shopName.toLowerCase().contains(query) || u.phone.contains(query)).toList()..sort((a, b) => a.shopName.compareTo(b.shopName));
        return DraggableScrollableSheet(initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('দোকান সিলেক্ট করুন', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'নাম বা ফোন দিয়ে খুঁজুন…', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14)))),
              const SizedBox(height: 8), const Divider(height: 1),
              Expanded(child: ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
                final u = displayed[i]; final isSelected = _selectedUserId == u.id;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: isSelected ? const Color(0xFFD97706) : scheme.primaryContainer, child: Icon(isSelected ? Icons.check_rounded : Icons.store_rounded, size: 18, color: isSelected ? Colors.white : scheme.primary)),
                  title: Text(u.shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${u.phone}${u.address.isNotEmpty ? '\n${u.address}' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(160))),
                  trailing: u.isBlocked ? const Icon(Icons.block_rounded, size: 18, color: Colors.red) : (isSelected ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFD97706)) : null),
                  onTap: u.isBlocked ? () => Get.snackbar('ব্লক', u.shopName, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white) : () { setState(() { _customerCtrl.text = u.shopName; _phoneCtrl.text = u.phone; _selectedUserId = u.id; _selectedUserAddress = u.address; }); _fetchPendingReplaces(u.id); Get.back(); },
                );
              })),
            ]),
          ));
      }),
    );
  }

  // ─── Products card ────────────────────────────────────────
  Widget _productsCard(ColorScheme scheme) {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('প্রডাক্ট সিলেক্ট করুন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            Obx(() => _selectedItems.isEmpty ? const SizedBox.shrink() : Text('${_selectedItems.length} টি | মোট $_totalQty pcs', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Obx(() {
            if (_selectedItems.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('কোনো প্রডাক্ট যোগ করা হয়নি', style: TextStyle(color: scheme.onSurface.withAlpha(100), fontSize: 13))));
            return Column(children: _selectedItems.asMap().entries.map((e) {
              final idx = e.key; final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh.withAlpha(120), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.image, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, e1, e2) => Container(width: 40, height: 40, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('স্টক: ${item.stock}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(Icons.remove_rounded, () { if (item.quantity > 1) { item.quantity--; _selectedItems.refresh(); } else { _selectedItems.removeAt(idx); } }),
                    SizedBox(width: 42, child: TextField(
                      controller: TextEditingController(text: '${item.quantity}'), keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                      onChanged: (v) { final q = int.tryParse(v); if (q != null && q > 0 && q <= item.stock) { item.quantity = q; _selectedItems.refresh(); } },
                      onSubmitted: (v) { final q = int.tryParse(v); if (q == null || q <= 0) { item.quantity = 1; } else if (q > item.stock) { item.quantity = item.stock; } _selectedItems.refresh(); },
                    )),
                    _qtyBtn(Icons.add_rounded, () { if (item.quantity < item.stock) { item.quantity++; _selectedItems.refresh(); } else { Get.snackbar('স্টক নেই', '${item.name} - স্টক: ${item.stock}', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); } }),
                  ]),
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), color: Colors.red.shade400, visualDensity: VisualDensity.compact, onPressed: () => _selectedItems.removeAt(idx)),
                ]),
              );
            }).toList());
          }),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _showProductPicker(scheme), icon: const Icon(Icons.add_rounded), label: const Text('প্রডাক্ট যোগ করুন'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
        ]),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(width: 30, height: 30, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD97706).withAlpha(80)), color: const Color(0xFFD97706).withAlpha(14)), child: Icon(icon, size: 16, color: const Color(0xFFD97706))));
  }

  void _showProductPicker(ColorScheme scheme) {
    String query = '';
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name));
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final displayed = query.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(query) || p.brandName.toLowerCase().contains(query) || p.productCode.toLowerCase().contains(query)).toList();
        return DraggableScrollableSheet(initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('প্রডাক্ট বেছে নিন', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'নাম বা কোড দিয়ে খুঁজুন…', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14)))),
              const SizedBox(height: 8), const Divider(height: 1),
              Expanded(child: ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
                final p = displayed[i]; final already = _selectedItems.any((e) => e.id == p.id);
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, e1, e2) => Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16))) : Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16))),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('স্টক: ${p.stock} | ৳${_fmt.format(p.wholesalePrice)}', style: TextStyle(fontSize: 11, color: p.stock <= 0 ? Colors.red : const Color(0xFF16A34A))),
                  trailing: already ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706)) : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD97706)),
                  onTap: p.stock <= 0 ? () => Get.snackbar('স্টক নেই', p.name, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white) : () { if (!already) { _selectedItems.add(_CartItem(id: p.id, name: p.name, image: p.images.isNotEmpty ? p.images.first : '', stock: p.stock, quantity: 1)); } Get.back(); },
                );
              })),
            ]),
          ));
      }),
    );
  }

  // ─── Replace section ──────────────────────────────────────
  void _fetchPendingReplaces(String userId) async {
    _loadingReplaces = true; _pendingReplaces.clear(); _replaceResolutions.clear();
    try {
      final snap = await FirebaseFirestore.instance.collection('admin_replace_entries').where('customerId', isEqualTo: userId).where('status', isEqualTo: 'at_shop').get();
      _pendingReplaces.assignAll(snap.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }));
    } catch (_) {}
    _loadingReplaces = false;
  }

  Widget _replaceSection(ColorScheme scheme) {
    if (_loadingReplaces) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));

    final hasPending = _pendingReplaces.isNotEmpty;
    final hasNew = _newReplaces.isNotEmpty;

    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF7C3AED), size: 18)),
            const SizedBox(width: 10),
            Text('রিপ্লেস (${_pendingReplaces.length + _newReplaces.length} টি)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            TextButton.icon(onPressed: () => _showNewReplaceDialog(scheme), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('নতুন রিপ্লেস', style: TextStyle(fontSize: 12)), style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)),
          ]),
          if (hasPending || hasNew) const SizedBox(height: 10),

          // Existing pending replaces
          if (hasPending) ..._pendingReplaces.map((doc) {
            final entryId = doc['id'] as String? ?? ''; final productName = doc['productName'] as String? ?? ''; final qty = (doc['quantity'] as num?)?.toInt() ?? 0; final defectiveProductId = doc['productId'] as String? ?? ''; final res = _replaceResolutions[entryId];
            return Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: scheme.surfaceContainerHigh.withAlpha(120), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF7C3AED)), const SizedBox(width: 6), Expanded(child: Text(productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('×$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF7C3AED))), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(20), borderRadius: BorderRadius.circular(6)), child: const Text('পুরনো', style: TextStyle(fontSize: 9, color: Color(0xFF7C3AED))))]),
                const SizedBox(height: 8),
                if (res == null)
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _showReplaceProductPicker(entryId, defectiveProductId, scheme), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), side: const BorderSide(color: Color(0xFF16A34A)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('প্রডাক্ট দেওয়া হয়েছে', style: TextStyle(fontSize: 12)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _setMoneyDeduct(entryId, scheme), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFDC2626)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('মূল্য বাদ', style: TextStyle(fontSize: 12)))),
                  ])
                else
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF16A34A).withAlpha(18), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(res.type == 'product_replace' ? Icons.inventory_2_rounded : Icons.money_off_rounded, size: 16, color: const Color(0xFF16A34A)), const SizedBox(width: 6), Expanded(child: Text(res.type == 'product_replace' ? 'প্রডাক্ট: ${res.productName} ×${res.qty}' : 'মূল্য বাদ: ৳${res.amount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)))), GestureDetector(onTap: () => _replaceResolutions.remove(entryId), child: const Icon(Icons.close_rounded, size: 16, color: Colors.red))])),
              ]),
            );
          }),

          // New replaces
          if (hasNew) ..._newReplaces.asMap().entries.map((e) {
            final idx = e.key; final nr = e.value; final res = nr.resolution;
            return Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: scheme.surfaceContainerHigh.withAlpha(120), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF7C3AED)), const SizedBox(width: 6), Expanded(child: Text(nr.defectiveProduct.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('×${nr.qty}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF7C3AED))), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD97706).withAlpha(20), borderRadius: BorderRadius.circular(6)), child: const Text('নতুন', style: TextStyle(fontSize: 9, color: Color(0xFFD97706)))), const Spacer(), GestureDetector(onTap: () => _newReplaces.removeAt(idx), child: const Icon(Icons.close_rounded, size: 16, color: Colors.red))]),
                const SizedBox(height: 8),
                if (res == null)
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _setNewReplaceResolution(idx, 'product_replace', scheme), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), side: const BorderSide(color: Color(0xFF16A34A)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('প্রডাক্ট দেওয়া হয়েছে', style: TextStyle(fontSize: 12)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _setNewReplaceMoneyDeduct(idx, scheme), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFDC2626)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('মূল্য বাদ', style: TextStyle(fontSize: 12)))),
                  ])
                else
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF16A34A).withAlpha(18), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(res.type == 'product_replace' ? Icons.inventory_2_rounded : Icons.money_off_rounded, size: 16, color: const Color(0xFF16A34A)), const SizedBox(width: 6), Expanded(child: Text(res.type == 'product_replace' ? 'প্রডাক্ট: ${res.productName} ×${res.qty}' : 'মূল্য বাদ: ৳${res.amount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)))), GestureDetector(onTap: () { _newReplaces[idx].resolution = null; _newReplaces.refresh(); }, child: const Icon(Icons.close_rounded, size: 16, color: Colors.red))])),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  // ─── Replace helpers ──────────────────────────────────────
  void _showNewReplaceDialog(ColorScheme scheme) {
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewReplaceDialogSheet(
        scheme: scheme,
        onAdd: (product, qty) {
          _newReplaces.add(_NewReplace(defectiveProduct: product, qty: qty));
        },
      ),
    );
  }

  void _setNewReplaceResolution(int idx, String type, ColorScheme scheme) {
    if (type == 'product_replace') _showReplaceProductPickerForNew(idx, scheme);
  }

  void _setNewReplaceMoneyDeduct(int idx, ColorScheme scheme) {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(title: const Text('মূল্য বাদ'), content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(prefixText: '৳ ', hintText: 'কত টাকা বাদ?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')), ElevatedButton(onPressed: () { final amt = num.tryParse(ctrl.text.trim()) ?? 0; if (amt <= 0) return; _newReplaces[idx].resolution = _ReplaceResolution(type: 'money_deduct', amount: amt); _newReplaces.refresh(); Get.back(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white), child: const Text('ঠিক আছে'))]));
    ctrl.dispose();
  }

  void _showReplaceProductPickerForNew(int idx, ColorScheme scheme) {
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name)); String query = '';
    showModalBottomSheet(context: Get.context!, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final displayed = query.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(query)).toList();
        return DraggableScrollableSheet(initialChildSize: 0.7, builder: (_, scrollCtrl) => Container(decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'রিপ্লেসমেন্ট প্রডাক্ট খুঁজুন…', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(height: 8), const Divider(height: 1),
            Expanded(child: ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
              final p = displayed[i];
              return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, e1, e2) => Container(width: 36, height: 36, color: scheme.surfaceContainerHighest)) : Container(width: 36, height: 36, color: scheme.surfaceContainerHighest)), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text('স্টক: ${p.stock}', style: TextStyle(fontSize: 11, color: p.stock > 0 ? const Color(0xFF16A34A) : Colors.red)), trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF7C3AED)), onTap: () { _newReplaces[idx].resolution = _ReplaceResolution(type: 'product_replace', defectiveProductId: _newReplaces[idx].defectiveProduct.id, productId: p.id, productName: p.name, qty: 1); _newReplaces.refresh(); Get.back(); });
            })),
          ])));
      }),
    );
  }

  void _setMoneyDeduct(String entryId, ColorScheme scheme) {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(title: const Text('মূল্য বাদ'), content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(prefixText: '৳ ', hintText: 'কত টাকা বাদ?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')), ElevatedButton(onPressed: () { final amt = num.tryParse(ctrl.text.trim()) ?? 0; if (amt <= 0) return; _replaceResolutions[entryId] = _ReplaceResolution(type: 'money_deduct', amount: amt); Get.back(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white), child: const Text('ঠিক আছে'))]));
    ctrl.dispose();
  }

  void _showReplaceProductPicker(String entryId, String defectiveProductId, ColorScheme scheme) {
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name)); String query = '';
    showModalBottomSheet(context: Get.context!, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final displayed = query.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(query)).toList();
        return DraggableScrollableSheet(initialChildSize: 0.7, builder: (_, scrollCtrl) => Container(decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'রিপ্লেসমেন্ট প্রডাক্ট খুঁজুন…', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(height: 8), const Divider(height: 1),
            Expanded(child: ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
              final p = displayed[i];
              return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, e1, e2) => Container(width: 36, height: 36, color: scheme.surfaceContainerHighest)) : Container(width: 36, height: 36, color: scheme.surfaceContainerHighest)), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text('স্টক: ${p.stock}', style: TextStyle(fontSize: 11, color: p.stock > 0 ? const Color(0xFF16A34A) : Colors.red)), trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF7C3AED)), onTap: () { _replaceResolutions[entryId] = _ReplaceResolution(type: 'product_replace', defectiveProductId: defectiveProductId, productId: p.id, productName: p.name, qty: 1); Get.back(); });
            })),
          ])));
      }),
    );
  }

  // ─── Submit ────────────────────────────────────────────────
  Widget _submitButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: Obx(() {
        final qty = _totalQty; final hasItems = _selectedItems.isNotEmpty;
        return ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.check_rounded, size: 22),
          label: Text(_submitting ? 'সাবমিট হচ্ছে…' : hasItems ? 'স্টক আউট করুন ($qty pcs)' : 'প্রডাক্ট যোগ করে স্টক আউট করুন', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB45309), disabledForegroundColor: Colors.white70, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
        );
      }),
    );
  }

  Future<void> _submit() async {
    final customer = _customerCtrl.text.trim();
    if (customer.isEmpty) { Get.snackbar('ত্রুটি', 'কাস্টমার নাম দিন', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }
    if (_selectedItems.isEmpty) { Get.snackbar('ত্রুটি', 'প্রডাক্ট সিলেক্ট করুন', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }

    setState(() => _submitting = true);
    try {
      // Build replace actions from existing
      final replaceActions = <Map<String, dynamic>>[];
      for (final e in _replaceResolutions.entries) {
        final map = <String, dynamic>{'replaceEntryId': e.key, 'resolutionType': e.value.type};
        if (e.value.type == 'product_replace') { map['replaceProductId'] = e.value.productId; map['replaceProductName'] = e.value.productName; map['replaceQty'] = e.value.qty; map['defectiveProductId'] = e.value.defectiveProductId; }
        else { map['deductionAmount'] = e.value.amount; }
        replaceActions.add(map);
      }
      // Build new replace actions
      for (final nr in _newReplaces) {
        if (nr.resolution == null) continue;
        final map = <String, dynamic>{'newReplace': true, 'defectiveProductId': nr.defectiveProduct.id, 'defectiveProductName': nr.defectiveProduct.name, 'defectiveQty': nr.qty, 'resolutionType': nr.resolution!.type};
        if (nr.resolution!.type == 'product_replace') { map['replaceProductId'] = nr.resolution!.productId; map['replaceProductName'] = nr.resolution!.productName; map['replaceQty'] = nr.resolution!.qty; }
        else { map['deductionAmount'] = nr.resolution!.amount; }
        replaceActions.add(map);
      }

      await controller.submitStockOut(
        stockOutDate: _selectedDate, customerName: customer, customerPhone: _phoneCtrl.text.trim(), customerAddress: _selectedUserAddress, customerId: _selectedUserId ?? '', memoNumber: _memoCtrl.text.trim(),
        items: _selectedItems.map((i) => {'productId': i.id, 'productName': i.name, 'image': i.image, 'quantity': i.quantity}).toList(),
        replaceActions: replaceActions,
      );

      Get.snackbar('সফল', 'স্টক আউট সম্পন্ন\nগ্রাহক: $customer', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);

      _selectedItems.clear(); _customerCtrl.clear(); _phoneCtrl.clear(); _selectedUserId = null; _selectedUserAddress = '';
      _pendingReplaces.clear(); _replaceResolutions.clear(); _newReplaces.clear();
      _memoCtrl.text = '#M${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _selectedDate = DateTime.now(); _dateCtrl.text = DateFormat('dd MMM yyyy').format(_selectedDate);
      pc.fetchProducts(forceRefresh: true);
    } catch (e) {
      Get.snackbar('ত্রুটি', 'স্টক আউট ব্যর্থ', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
    setState(() => _submitting = false);
  }
}

// ─── Helper classes ─────────────────────────────────────────
class _CartItem {
  final String id; final String name; final String image; final int stock; int quantity;
  _CartItem({required this.id, required this.name, required this.image, required this.stock, required this.quantity});
}

class _ReplaceResolution {
  final String type; final String defectiveProductId; String productId; String productName; int qty; num amount;
  _ReplaceResolution({required this.type, this.defectiveProductId = '', this.productId = '', this.productName = '', this.qty = 0, this.amount = 0});
}

class _NewReplace {
  final ProductModel defectiveProduct;
  final int qty;
  _ReplaceResolution? resolution;
  _NewReplace({required this.defectiveProduct, required this.qty, this.resolution});
}

class _NewReplaceDialogSheet extends StatefulWidget {
  final ColorScheme scheme;
  final void Function(ProductModel product, int qty) onAdd;
  const _NewReplaceDialogSheet({required this.scheme, required this.onAdd});

  @override
  State<_NewReplaceDialogSheet> createState() => _NewReplaceDialogSheetState();
}

class _NewReplaceDialogSheetState extends State<_NewReplaceDialogSheet> {
  ProductModel? _product;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final sc = widget.scheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: sc.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('নতুন রিপ্লেস যোগ করুন',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const Text('ডিফেক্টিভ প্রডাক্ট *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final p = await showModalBottomSheet<ProductModel>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _ProductPicker(),
                );
                if (p != null) setState(() => _product = p);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: _product != null ? sc.primary : sc.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                  color: _product != null ? sc.primaryContainer.withAlpha(50) : null,
                ),
                child: Row(children: [
                  Icon(Icons.broken_image_rounded, size: 18, color: _product != null ? sc.primary : sc.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_product?.name ?? 'প্রডাক্ট বেছে নিন', style: TextStyle(fontWeight: _product != null ? FontWeight.w700 : FontWeight.normal, color: _product != null ? sc.primary : sc.onSurfaceVariant))),
                  Icon(Icons.arrow_drop_down_rounded, color: sc.onSurfaceVariant),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Text('পরিমাণ:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: '1'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) { final q = int.tryParse(v); if (q != null && q > 0) _qty = q; },
                  decoration: InputDecoration(
                    filled: true, fillColor: sc.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _product != null
                  ? () {
                      widget.onAdd(_product!, _qty);
                      Get.back();
                    }
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('যোগ করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: sc.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme; final pc = Get.find<ProductController>();
    final all = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name)); String query = '';
    return DraggableScrollableSheet(initialChildSize: 0.7, builder: (_, scrollCtrl) => StatefulBuilder(builder: (ctx, setSheetState) {
      final displayed = query.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(query) || p.brandName.toLowerCase().contains(query) || p.productCode.toLowerCase().contains(query)).toList();
      return Container(decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [
        const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('প্রডাক্ট বেছে নিন', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'নাম বা কোড দিয়ে খুঁজুন…', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: scheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14)))),
        const SizedBox(height: 8), const Divider(height: 1),
        Expanded(child: ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
          final p = displayed[i];
          return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, e1, e2) => Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16))) : Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16))), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text('স্টক: ${p.stock}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))), onTap: () => Navigator.of(context).pop(p));
        })),
      ]));
    }));
  }
}

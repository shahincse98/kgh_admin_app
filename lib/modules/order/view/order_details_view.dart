import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../model/order_model.dart';
import '../controller/order_controller.dart';
import '../../product/model/product_model.dart';
import '../../product/controller/product_controller.dart';

// ─── Editable item state ────────────────────────────────────────
class _EditItem {
  final String productId;
  final String productName;
  final String image;
  int quantity;
  final num pricePerUnit;

  _EditItem({
    required this.productId,
    required this.productName,
    required this.image,
    required this.quantity,
    required this.pricePerUnit,
  });

  num get lineTotal => quantity * pricePerUnit;

  OrderItem toOrderItem() => OrderItem(
        productId: productId,
        productName: productName,
        image: image,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        totalPrice: lineTotal,
      );
}

// ─── Details View ────────────────────────────────────────────────
class OrderDetailsView extends StatefulWidget {
  final OrderModel order;
  /// If provided, marks this SR as deliverer when order status set to 'delivered'
  final String? srDocId;
  const OrderDetailsView({super.key, required this.order, this.srDocId});

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  late final OrderController controller;
  late final TextEditingController _paidCtrl;
  late String _currentStatus;
  late List<_EditItem> _editItems;
  // Mutable saved state so view mode reflects latest values without page reload
  late List<OrderItem> _savedItems;
  late num _savedTotal;
  bool _editMode = false;
  bool _saving = false;
  late num _currentPaid;
  DateTime? _scheduledDate;

  // Product search for adding new products in edit mode
  List<ProductModel> _allProducts = [];
  bool _loadingProducts = false;
  String _productQuery = '';
  final TextEditingController _productSearchCtrl = TextEditingController();
  List<ProductModel> get _productSuggestions => _productQuery.isEmpty
      ? []
      : _allProducts
          .where((p) =>
              p.name.toLowerCase().contains(_productQuery) ||
              p.brandName.toLowerCase().contains(_productQuery) ||
              p.productCode.toLowerCase().contains(_productQuery))
          .take(6)
          .toList();

  static const _statuses = ['pending', 'approved', 'delivered', 'cancelled'];
  static final _fmt = NumberFormat('#,##,##0');

  @override
  void initState() {
    super.initState();
    controller = Get.find<OrderController>();
    _currentPaid = widget.order.paidAmount;
    _paidCtrl =
        TextEditingController(text: widget.order.paidAmount.toStringAsFixed(0));
    _currentStatus = _statuses.contains(widget.order.status)
        ? widget.order.status
        : 'pending';
    _scheduledDate = widget.order.scheduledDeliveryDate;
    _savedItems = List<OrderItem>.from(widget.order.items);
    _savedTotal = widget.order.totalAmount;
    _initEditItems();
    _loadProducts();
  }

  void _initEditItems() {
    _editItems = widget.order.items
        .map((i) => _EditItem(
              productId: i.productId,
              productName: i.productName,
              image: i.image,
              quantity: i.quantity,
              pricePerUnit: i.pricePerUnit,
            ))
        .toList();
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  num get _editTotal =>
      _editItems.fold<num>(0, (s, e) => s + e.lineTotal);

  // ── Save edited items ─────────────────────────────────────────

  Future<void> _saveItems() async {
    if (_editItems.isEmpty) {
      final confirm = await _confirm(
        'সতর্কতা',
        'সব প্রডাক্ট রিমুভ করা হয়েছে। Order টি খালি সেভ করবেন?',
      );
      if (confirm != true) return;
    }
    setState(() => _saving = true);
    final newItems = _editItems.map((e) => e.toOrderItem()).toList();
    final newTotal = _editTotal;
    await controller.updateOrderItems(
      widget.order.id,
      newItems,
    );
    setState(() {
      _saving = false;
      _editMode = false;
      _savedItems = newItems;        // ← update view-mode state immediately
      _savedTotal = newTotal;        // ← so price shows without refresh
      _productSearchCtrl.clear();
      _productQuery = '';
    });
    Get.snackbar('সফল', 'প্রডাক্ট লিস্ট আপডেট হয়েছে',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white);
  }

  Future<bool?> _confirm(String title, String msg) => Get.dialog<bool>(
        AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('না')),
            ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('হ্যাঁ')),
          ],
        ),
      );

  // ── Load products from the permanently-loaded ProductController ─

  Future<void> _loadProducts() async {
    if (_allProducts.isNotEmpty || _loadingProducts) return;
    setState(() => _loadingProducts = true);
    try {
      final pc = Get.find<ProductController>();
      // Ensure products are loaded (fetched only once due to _loadedOnce guard)
      if (pc.products.isEmpty) await pc.fetchProducts();
      if (mounted) {
        setState(() {
          _allProducts = List<ProductModel>.from(pc.products)
            ..sort((a, b) => a.name.compareTo(b.name));
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(_currentStatus);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Order #${widget.order.id.length > 10 ? widget.order.id.substring(0, 10) : widget.order.id}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_editMode)
            TextButton.icon(
              onPressed: () => setState(() {
                _editMode = false;
                _initEditItems(); // discard changes
              }),
              icon: const Icon(Icons.close_rounded),
              label: const Text('বাতিল'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'প্রডাক্ট এডিট করুন',
              onPressed: () => setState(() => _editMode = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // ── Shop & order info ──────────────────────────────
          _shopCard(scheme, statusColor),
          const SizedBox(height: 12),
          // ── SR info + commission confirm (admin only) ──────
          if (widget.srDocId == null && widget.order.deliveredBySrId.isNotEmpty)
            _srInfoCard(scheme),
          if (widget.srDocId == null && widget.order.deliveredBySrId.isNotEmpty)
            const SizedBox(height: 12),
          // ── Scheduled delivery (admin can set, SR sees) ────
          _scheduledDeliveryCard(scheme),
          const SizedBox(height: 12),
          // ── Status change ──────────────────────────────────
          _statusCard(scheme),
          const SizedBox(height: 12),
          // ── Products ──────────────────────────────────────
          _itemsCard(scheme),
          const SizedBox(height: 12),
          // ── Payment ───────────────────────────────────────
          _paymentCard(scheme),
        ],
      ),
    );
  }

  // ── Shop card ────────────────────────────────────────────────

  Widget _shopCard(ColorScheme scheme, Color statusColor) {
    final date = DateFormat('dd MMMM yyyy').format(widget.order.createdAt);
    final time = DateFormat('h:mm a').format(widget.order.createdAt);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Coloured header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor.withAlpha(220), statusColor.withAlpha(160)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.shopName.isEmpty
                            ? 'Unknown Shop'
                            : widget.order.shopName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                      if (widget.order.shopPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Text(widget.order.shopPhone,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                      if (widget.order.userPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded,
                                color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Text('ক্রেতা: ${widget.order.userPhone}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _statusPill(_currentStatus, statusColor),
              ],
            ),
          ),
          // Info rows
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (widget.order.shopAddress.isNotEmpty) ...[  
                  _infoRow(Icons.location_on_outlined,
                      widget.order.shopAddress, scheme),
                  const SizedBox(height: 6),
                ],
                if (widget.order.shopPhone.isNotEmpty ||  
                    widget.order.userPhone.isNotEmpty) ...[  
                  _infoRow(
                    Icons.phone_android_rounded,
                    widget.order.shopPhone.isNotEmpty
                        ? widget.order.shopPhone
                        : widget.order.userPhone,
                    scheme,
                  ),
                  const SizedBox(height: 6),
                ],
                if (widget.order.userDue > 0) ...[  
                  _infoRow(
                    Icons.account_balance_wallet_outlined,
                    'বকেয়া: ৳ ${_fmt.format(widget.order.userDue)}',
                    scheme,
                    textColor: const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 6),
                ],
                _infoRow(Icons.calendar_today_outlined, '$date, $time', scheme),
                const SizedBox(height: 6),
                _infoRow(Icons.tag_rounded, widget.order.id, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ColorScheme scheme,
      {Color? textColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: textColor ?? scheme.onSurface.withAlpha(140)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: textColor != null
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: textColor ?? scheme.onSurface.withAlpha(180)),
          ),
        ),
      ],
    );
  }

  // ── Status card ───────────────────────────────────────────────

  Widget _statusCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('অর্ডার স্ট্যাটাস',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((s) {
                final selected = _currentStatus == s;
                final color = _statusColor(s);
                return GestureDetector(
                  onTap: () async {
                    if (s == _currentStatus) return;
                    if (s == 'delivered') {
                      await _showDeliveryPaymentDialog(_currentStatus);
                    } else {
                      final prev = _currentStatus;
                      setState(() => _currentStatus = s);
                      await controller.updateOrderStatus(
                        widget.order.id,
                        s,
                        previousStatus: prev,
                        items: widget.order.items
                            .map((i) => {
                                  'productId': i.productId,
                                  'quantity': i.quantity,
                                })
                            .toList(),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          selected ? color : color.withAlpha(14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? color
                              : color.withAlpha(60),
                          width: selected ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          _statusLabel(s),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Items / edit card ─────────────────────────────────────────

  Widget _itemsCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'প্রডাক্ট লিস্ট',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_editMode)
                  Text(
                    '${_editItems.length} টি পণ্য',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_editMode)
              ..._editItems.asMap().entries.map((e) =>
                  _editItemRow(e.key, e.value, scheme))
            else
              ..._savedItems.map((i) => _viewItemRow(i, scheme)),
            // Product add (edit mode only)
            if (_editMode) ...[
              const SizedBox(height: 10),
              _productAddSection(scheme),
            ],
            const Divider(height: 20),
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('মোট',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '৳ ${_fmt.format((_editMode ? _editTotal : _savedTotal).toInt())}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0891B2)),
                ),
              ],
            ),
            if (_editMode) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveItems,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                      _saving ? 'সেভ হচ্ছে…' : 'পরিবর্তন সেভ করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewItemRow(OrderItem i, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              i.image,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, e1, e2) => Container(
                width: 52,
                height: 52,
                color: scheme.surfaceContainerHigh,
                child: const Icon(Icons.image_not_supported_rounded,
                    size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  '${i.quantity} × ৳${_fmt.format(i.pricePerUnit.toInt())}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withAlpha(160)),
                ),
              ],
            ),
          ),
          Text(
            '৳ ${_fmt.format(i.totalPrice.toInt())}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0891B2)),
          ),
        ],
      ),
    );
  }

  Widget _editItemRow(int index, _EditItem item, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.image,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, e1, e2) => Container(
                width: 44,
                height: 44,
                color: scheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_rounded,
                    size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '৳${_fmt.format((item.quantity * item.pricePerUnit).toInt())}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF0891B2),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Qty stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepBtn(Icons.remove_rounded, () {
                setState(() {
                  if (item.quantity > 1) {
                    item.quantity--;
                  } else {
                    _editItems.removeAt(index);
                  }
                });
              }, color: item.quantity <= 1
                  ? Colors.red.shade400
                  : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _stepBtn(Icons.add_rounded, () {
                setState(() => item.quantity++);
              }),
            ],
          ),
          const SizedBox(width: 6),
          // Remove button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            iconSize: 20,
            color: Colors.red.shade400,
            visualDensity: VisualDensity.compact,
            tooltip: 'রিমুভ করুন',
            onPressed: () async {
              final ok = await _confirm(
                  'রিমুভ করবেন?',
                  '"${item.productName}" এই অর্ডার থেকে রিমুভ করতে চান?');
              if (ok == true) {
                setState(() => _editItems.removeAt(index));
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Product add section (edit mode) ──────────────────────────
  //   Row: [search field → inline autocomplete] [Browse-all btn]

  Widget _productAddSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─ Inline search ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _productSearchCtrl,
                    onChanged: (v) =>
                        setState(() => _productQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'প্রডাক্ট নাম দিয়ে খুঁজুন…',
                      prefixIcon: _loadingProducts
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: scheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 14),
                      suffixIcon: _productQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _productSearchCtrl.clear();
                                setState(() => _productQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                  // Inline suggestions dropdown
                  if (_productSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(22),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: _productSuggestions
                            .map((p) => _suggestionTile(p, scheme))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ─ Browse-All button ───────────────────────────────
            Tooltip(
              message: 'সব প্রডাক্ট দেখুন',
              child: InkWell(
                onTap: () => _showProductPickerSheet(scheme),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.grid_view_rounded,
                      color: scheme.onPrimaryContainer, size: 22),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Inline suggestion tile ────────────────────────────────────

  Widget _suggestionTile(ProductModel p, ColorScheme scheme) {
    final alreadyAdded = _editItems.any((e) => e.productId == p.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _addOrIncrementProduct(p),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: p.images.isNotEmpty
                  ? Image.network(p.images.first,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e1, e2) =>
                          _imgPlaceholder(40, scheme))
                  : _imgPlaceholder(40, scheme),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Row(
                    children: [
                      Text('৳${_fmt.format(p.wholesalePrice)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0891B2),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      _stockBadge(p.stock),
                    ],
                  ),
                ],
              ),
            ),
            if (alreadyAdded)
              _miniBtn(Icons.add_rounded, const Color(0xFF0891B2), '+1')
            else
              Icon(Icons.add_circle_rounded,
                  color: const Color(0xFF0891B2).withAlpha(200), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w800)),
      );

  Widget _stockBadge(int stock) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: stock > 0
              ? const Color(0xFF16A34A).withAlpha(20)
              : Colors.red.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('স্টক: $stock',
            style: TextStyle(
                fontSize: 10,
                color: stock > 0
                    ? const Color(0xFF16A34A)
                    : Colors.red,
                fontWeight: FontWeight.w600)),
      );

  void _addOrIncrementProduct(ProductModel p) {
    setState(() {
      final idx = _editItems.indexWhere((e) => e.productId == p.id);
      if (idx != -1) {
        _editItems[idx].quantity++;
      } else {
        _editItems.add(_EditItem(
          productId: p.id,
          productName: p.name,
          image: p.images.isNotEmpty ? p.images.first : '',
          quantity: 1,
          pricePerUnit: p.wholesalePrice,
        ));
      }
      _productSearchCtrl.clear();
      _productQuery = '';
    });
  }

  // ── Browse-All bottom sheet (multi-select) ────────────────────

  void _showProductPickerSheet(ColorScheme scheme) {
    final selected = <String>{
      ..._editItems.map((e) => e.productId)
    };
    String sheetQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displayed = sheetQuery.isEmpty
              ? _allProducts
              : _allProducts
                  .where((p) =>
                      p.name
                          .toLowerCase()
                          .contains(sheetQuery) ||
                      p.brandName
                          .toLowerCase()
                          .contains(sheetQuery) ||
                      p.productCode
                          .toLowerCase()
                          .contains(sheetQuery))
                  .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.96,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // ── Handle ────────────────────────────────
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Header ────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('প্রডাক্ট বেছে নিন',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w800)),
                        ),
                        if (selected.isNotEmpty)
                          Text('${selected.length} টি বেছেছেন',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0891B2),
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Search ───────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setSheetState(
                          () => sheetQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'নাম বা কোড দিয়ে ফিল্টার করুন…',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  // ── Product list ─────────────────────────
                  Expanded(
                    child: _loadingProducts
                        ? const Center(
                            child: CircularProgressIndicator())
                        : displayed.isEmpty
                            ? const Center(
                                child: Text('কোনো প্রডাক্ট পাওয়া যায়নি',
                                    style:
                                        TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                controller: scrollCtrl,
                                itemCount: displayed.length,
                                separatorBuilder: (_, idx2) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final p = displayed[i];
                                  final isSelected =
                                      selected.contains(p.id);
                                  return InkWell(
                                    onTap: () => setSheetState(() {
                                      if (isSelected) {
                                        selected.remove(p.id);
                                      } else {
                                        selected.add(p.id);
                                      }
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 10, 16, 10),
                                      child: Row(
                                        children: [
                                          // Checkbox
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF0891B2)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(
                                                        0xFF0891B2)
                                                    : scheme.outlineVariant,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    size: 16,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          // Thumbnail
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: p.images.isNotEmpty
                                                ? Image.network(
                                                    p.images.first,
                                                    width: 46,
                                                    height: 46,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, e1,
                                                            e2) =>
                                                        _imgPlaceholder(
                                                            46, scheme))
                                                : _imgPlaceholder(
                                                    46, scheme),
                                          ),
                                          const SizedBox(width: 12),
                                          // Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(p.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13)),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Text(
                                                        '৳${_fmt.format(p.wholesalePrice)}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                                0xFF0891B2),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    const SizedBox(width: 8),
                                                    _stockBadge(p.stock),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  // ── Confirm button ───────────────────────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _applyPickedProducts(selected);
                                },
                          icon: const Icon(Icons.done_all_rounded),
                          label: Text(selected.isEmpty
                              ? 'প্রডাক্ট বেছে নিন'
                              : '${selected.length} টি প্রডাক্ট যোগ করুন'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0891B2),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                scheme.surfaceContainerHigh,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyPickedProducts(Set<String> selectedIds) {
    setState(() {
      for (final id in selectedIds) {
        final p = _allProducts.firstWhere((p) => p.id == id,
            orElse: () => _allProducts.first);
        final idx = _editItems.indexWhere((e) => e.productId == id);
        if (idx != -1) {
          // Already in cart — leave existing qty (user can adjust via stepper)
        } else {
          _editItems.add(_EditItem(
            productId: p.id,
            productName: p.name,
            image: p.images.isNotEmpty ? p.images.first : '',
            quantity: 1,
            pricePerUnit: p.wholesalePrice,
          ));
        }
      }
    });
  }

  // ── Delivery confirmation + payment dialog ─────────────────

  Future<void> _showDeliveryPaymentDialog(String previousStatus) async {
    final scheme = Theme.of(context).colorScheme;
    final total = _savedTotal;
    final orderDue = total - _currentPaid;
    final payCtrl =
        TextEditingController(text: _currentPaid.toStringAsFixed(0));
    final totalDue = (widget.order.userDue + orderDue.toInt()).clamp(0, 9999999);
    final dueCtrl = TextEditingController(
        text: totalDue > 0 ? totalDue.toString() : '');

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded,
                color: Color(0xFF16A34A), size: 22),
            SizedBox(width: 8),
            Text('ডেলিভারি পেমেন্ট',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _dialogPayRow('অর্ডার আইডি',
                        '#${widget.order.id}',
                        const Color(0xFF0891B2)),
                    const SizedBox(height: 6),
                    _dialogPayRow('মোট অর্ডার',
                        '৳ ${_fmt.format(total.toInt())}',
                        const Color(0xFF0891B2)),
                    const SizedBox(height: 6),
                    _dialogPayRow('আগে দেওয়া',
                        '৳ ${_fmt.format(_currentPaid.toInt())}',
                        const Color(0xFF16A34A)),
                    const SizedBox(height: 6),
                    _dialogPayRow('এই অর্ডারে বাকি',
                        '৳ ${_fmt.format(orderDue.toInt())}',
                        orderDue > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A)),
                    if (widget.order.userDue > 0) ...[
                      const SizedBox(height: 6),
                      _dialogPayRow('কাস্টমারের মোট বাকি',
                          '৳ ${_fmt.format(widget.order.userDue)}',
                          const Color(0xFFDC2626)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(builder: (ctx, setSt) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('পেমেন্ট পাওয়া গেছে',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: payCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        hintText: 'পরিমাণ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('কাস্টমারের মোট বাকি আপডেট করুন',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: dueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        hintText: 'নতুন মোট বাকি (০ হলে খালি রাখুন)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('ডেলিভার্ড করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final amount =
          num.tryParse(payCtrl.text.trim()) ?? _currentPaid;
      final newDue = int.tryParse(dueCtrl.text.trim()) ?? totalDue;
      setState(() => _currentStatus = 'delivered');
      await controller.updateOrderStatus(
        widget.order.id,
        'delivered',
        previousStatus: previousStatus,
        deliveredBySrId: widget.srDocId,
        items: widget.order.items
            .map((i) => {
                  'productId': i.productId,
                  'quantity': i.quantity,
                })
            .toList(),
      );
      if (amount != _currentPaid) {
        await controller.updatePaidAmount(widget.order.id, amount);
        setState(() {
          _currentPaid = amount;
          _paidCtrl.text = amount.toStringAsFixed(0);
        });
      }
      if (widget.order.userId.isNotEmpty) {
        await controller.updateUserDue(widget.order.userId, newDue);
      }
      Get.snackbar(
        'সফল',
        'ডেলিভারি সম্পন্ন এবং পেমেন্ট আপডেট হয়েছে',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      payCtrl.dispose();
      dueCtrl.dispose();
    }
  }

  Widget _dialogPayRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  Widget _imgPlaceholder(double size, ColorScheme scheme) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported_rounded, size: 18),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap,
      {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: (color ?? const Color(0xFF0891B2)).withAlpha(80)),
          color: (color ?? const Color(0xFF0891B2)).withAlpha(14),
        ),
        child: Icon(icon,
            size: 18, color: color ?? const Color(0xFF0891B2)),
      ),
    );
  }

  // ── Scheduled delivery card ───────────────────────────────────

  Widget _scheduledDeliveryCard(ColorScheme scheme) {
    final date = _scheduledDate;
    final dateFmt = DateFormat('dd MMMM yyyy');
    final hasDate = date != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasDate
                    ? const Color(0xFF0891B2).withAlpha(20)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_shipping_rounded,
                  color: hasDate
                      ? const Color(0xFF0891B2)
                      : scheme.onSurface.withAlpha(120),
                  size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('নির্ধারিত ডেলিভারি তারিখ',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500)),
                  Text(
                    hasDate ? dateFmt.format(date) : 'তারিখ নির্ধারিত নেই',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: hasDate
                            ? const Color(0xFF0891B2)
                            : scheme.onSurface.withAlpha(160)),
                  ),
                ],
              ),
            ),
            // Both admin and SR can set/change the scheduled delivery date
            if (hasDate)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'তারিখ মুছুন',
                color: Colors.red.shade400,
                onPressed: () async {
                  await controller.setScheduledDelivery(widget.order.id, null);
                  setState(() => _scheduledDate = null);
                },
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                await controller.setScheduledDelivery(
                    widget.order.id, picked);
                setState(() => _scheduledDate = picked);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: Text(hasDate ? 'পরিবর্তন' : 'তারিখ দিন'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SR info + commission confirm card ─────────────────────

  Widget _srInfoCard(ColorScheme scheme) {
    final srId = widget.order.deliveredBySrId;
    final confirmed = widget.order.commissionConfirmed;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_rounded,
                      color: Color(0xFF7C3AED), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SR দ্বারা ডেলিভার করা হয়েছে',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500)),
                      Text(srId,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                if (confirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('কমিশন নিশ্চিত',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (!confirmed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final ok = await _confirm(
                            'কমিশন নিশ্চিত করুন',
                            'এই SR-এর কমিশন চূড়ান্ত করবেন? এটি SR-এর পেমেন্ট রেকর্ডে যুক্ত হবে।',
                          );
                          if (ok != true) return;
                          setState(() => _saving = true);
                          await controller.confirmDeliveryWithCommission(
                            orderId: widget.order.id,
                            srDocId: srId,
                            orderTotal: _savedTotal,
                          );
                          setState(() => _saving = false);
                          Get.snackbar(
                            'কমিশন নিশ্চিত হয়েছে',
                            'SR-এর কমিশন রেকর্ড আপডেট হয়েছে',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF7C3AED),
                            colorText: Colors.white,
                          );
                        },
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_rounded),
                  label:
                      Text(_saving ? 'প্রক্রিয়া চলছে…' : 'কমিশন নিশ্চিত করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Payment card ──────────────────────────────────────────────

  Widget _paymentCard(ColorScheme scheme) {
    final total = _editMode ? _editTotal : _savedTotal;
    final paid = _currentPaid;
    final due = total - paid;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('পেমেন্ট তথ্য',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _payRow('মোট টাকা', '৳ ${_fmt.format(total.toInt())}',
                const Color(0xFF0891B2)),
            const SizedBox(height: 6),
            _payRow('জমা দেওয়া হয়েছে',
                '৳ ${_fmt.format(paid.toInt())}', const Color(0xFF16A34A)),
            const SizedBox(height: 6),
            _payRow('বকেয়া', '৳ ${_fmt.format(due.toInt())}',
                due > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
            const Divider(height: 20),
            TextField(
              controller: _paidCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'নতুন জমার পরিমাণ আপডেট করুন',
                prefixText: '৳ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final amount = num.tryParse(_paidCtrl.text.trim()) ??
                      _currentPaid;
                  await controller.updatePaidAmount(
                      widget.order.id, amount);
                  setState(() => _currentPaid = amount);
                  Get.snackbar(
                    'আপডেট হয়েছে',
                    'পেমেন্ট তথ্য সেভ হয়েছে',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF16A34A),
                    colorText: Colors.white,
                  );
                },
                icon: const Icon(Icons.payments_rounded),
                label: const Text('পেমেন্ট আপডেট করুন'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(160))),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _statusPill(String status, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withAlpha(120), width: 1),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12),
      ),
    );
  }

  String _statusLabel(String s) => {
        'pending': 'Pending',
        'approved': 'Approved',
        'delivered': 'Delivered',
        'cancelled': 'বাতিল',
      }[s] ??
      (s.capitalizeFirst ?? s);

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}

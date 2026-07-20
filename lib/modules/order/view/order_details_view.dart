import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/order_model.dart';
import '../controller/order_controller.dart';
import '../../product/model/product_model.dart';
import '../../product/controller/product_controller.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';
import '../../replace/model/admin_replace_model.dart';
import '../../replace/controller/admin_replace_controller.dart';
import '../../stock_in/controller/stock_in_controller.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';
import '../../replace/model/admin_replace_model.dart';
import '../../replace/controller/admin_replace_controller.dart';
import '../../stock_in/controller/stock_in_controller.dart';
import '../../../widgets/call_button.dart';
import '../../../widgets/responsive.dart';

// ─── Editable item state ────────────────────────────────────────
class _EditItem {
  final String productId;
  final String productName;
  final String image;
  int quantity;
  num pricePerUnit;
  num purchasePrice;
  late final TextEditingController priceCtrl;

  _EditItem({
    required this.productId,
    required this.productName,
    required this.image,
    required this.quantity,
    required this.pricePerUnit,
    this.purchasePrice = 0,
  }) {
    priceCtrl = TextEditingController(text: pricePerUnit.toStringAsFixed(0));
  }

  num get lineTotal => quantity * pricePerUnit;

  OrderItem toOrderItem() => OrderItem(
        productId: productId,
        productName: productName,
        image: image,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        totalPrice: lineTotal,
        purchasePrice: purchasePrice,
      );

  void dispose() { priceCtrl.dispose(); }
}

// ─── Payment row state (delivery dialog) ──────────────────────
class _PaymentRow {
  final TextEditingController amountCtrl;
  String method;
  _PaymentRow({this.method = 'SR হাতে', String amount = ''})
      : amountCtrl = TextEditingController(text: amount);
  void dispose() => amountCtrl.dispose();
}

// ─── Details View ────────────────────────────────────────────────

// ─── Replace return item state (delivery dialog) ────────────────
class _ReplaceReturnItem {
  final ProductModel product;
  int quantity;
  String resolutionType;
  int deductionAmount;
  late final TextEditingController dedCtrl;
  _ReplaceReturnItem({required this.product, required this.quantity, required this.resolutionType, required this.deductionAmount}) {
    dedCtrl = TextEditingController(text: deductionAmount.toString());
  }
  void dispose() { dedCtrl.dispose(); }
}

// ─── Return item (sales return — goes back to stock) ─────────
class _ReturnItem {
  final ProductModel product;
  int quantity;
  num unitPrice;
  late final TextEditingController priceCtrl;
  _ReturnItem({required this.product, required this.quantity, num unitPrice = 0})
      : unitPrice = unitPrice > 0 ? unitPrice : product.wholesalePrice {
    priceCtrl = TextEditingController(text: unitPrice.toStringAsFixed(0));
  }
  num get totalPrice => quantity * unitPrice;
  void dispose() { priceCtrl.dispose(); }
}

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
  DateTime? _deliveredAt;
  DateTime? _dispatchedAt;
  String _assignedSrId = '';
  String _assignedSrName = '';
  List<Map<String, String>> _allSrs = [];
  bool _loadingSrs = false;

  // Customer state
  late String _currentShopName;
  late String _currentShopAddress;
  late String _currentShopPhone;
  late String _currentUserId;
  late String _currentUserPhone;
  late int _currentUserDue;
  late int _currentPreviousDue;
  late num _currentDeductionAmount;
  late num _currentReturnAmount;
  late num _currentDiscountAmount;
  late String _currentPaymentMethod;
  late List<Map<String, dynamic>> _currentPayments;
  late String _currentLocalMemo;
  late List<Map<String, dynamic>> _currentReplaceItems;

  List<UserModel> _allUsers = [];
  bool _loadingUsers = false;
  List<AdminReplaceModel> _customerReplaces = [];
  bool _replacesLoaded = false;

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

  static const _statuses = ['pending', 'approved', 'dispatched', 'delivered', 'cancelled'];
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
    _deliveredAt = widget.order.deliveredAt;
    _dispatchedAt = widget.order.dispatchedAt;
    _assignedSrId = widget.order.deliveryAssignedSrId;
    _assignedSrName = widget.order.deliveryAssignedSrName;
    if (widget.srDocId == null) _loadSrs();
    _savedItems = List<OrderItem>.from(widget.order.items);
    _savedTotal = widget.order.totalAmount;
    _currentShopName = widget.order.shopName;
    _currentShopAddress = widget.order.shopAddress;
    _currentShopPhone = widget.order.shopPhone;
    _currentUserId = widget.order.userId;
    _currentUserPhone = widget.order.userPhone;
    _currentUserDue = widget.order.userDue;
    _currentDeductionAmount = widget.order.deductionAmount;
    _currentReturnAmount = widget.order.returnAmount;
    _currentDiscountAmount = widget.order.discountAmount;
    _currentPaymentMethod = widget.order.paymentMethod.isNotEmpty ? widget.order.paymentMethod : 'SR হাতে';
    _currentPayments = widget.order.payments.isNotEmpty ? List<Map<String, dynamic>>.from(widget.order.payments) : [{'amount': widget.order.paidAmount > 0 ? (widget.order.paidAmount - widget.order.returnAmount - widget.order.deductionAmount).clamp(0, 9999999) : 0, 'method': _currentPaymentMethod}];
    _currentPreviousDue = widget.order.previousDue > 0 ? widget.order.previousDue : widget.order.userDue;
    _currentLocalMemo = widget.order.localMemo;
    _currentReplaceItems = widget.order.replaceItems.isNotEmpty ? List<Map<String, dynamic>>.from(widget.order.replaceItems) : [];
    _initEditItems();
    _loadProducts();
  }

  Future<void> _loadSrs() async {
    if (_allSrs.isNotEmpty || _loadingSrs) return;
    if (mounted) setState(() => _loadingSrs = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sr_staff')
          .where('isActive', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _allSrs = snap.docs
              .map((d) => {
                    'id': d.id,
                    'name': (d.data()['name'] ?? '') as String,
                    'phone': (d.data()['phone'] ?? '') as String,
                  })
              .toList();
          _loadingSrs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSrs = false);
    }
  }

  Future<void> _pickSrForDelivery(ColorScheme scheme) async {
    if (_allSrs.isEmpty && !_loadingSrs) await _loadSrs();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  const Icon(Icons.person_search_rounded),
                  const SizedBox(width: 10),
                  Text('SR নির্বাচন করুন',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: _allSrs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _allSrs.length,
                        itemBuilder: (_, i) {
                          final sr = _allSrs[i];
                          final isSelected = sr['id'] == _assignedSrId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  scheme.primaryContainer,
                              child: Text(
                                (sr['name'] ?? '').isNotEmpty
                                    ? sr['name']![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(sr['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(sr['phone'] ?? ''),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: scheme.primary)
                                : null,
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final srId = sr['id']!;
                              final srName = sr['name']!;
                              await controller.assignDelivery(
                                  widget.order.id, srId, srName,
                                  _scheduledDate);
                              if (mounted) {
                                setState(() {
                                  _assignedSrId = srId;
                                  _assignedSrName = srName;
                                });
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _initEditItems() {
    _editItems = widget.order.items
        .map((i) {
          num pp = i.purchasePrice;
          if (pp <= 0) {
            try {
              final pc = Get.find<ProductController>();
              final p = pc.products.firstWhereOrNull((p) => p.id == i.productId);
              if (p != null) pp = p.purchasePrice;
            } catch (_) {}
          }
          return _EditItem(
            productId: i.productId,
            productName: i.productName,
            image: i.image,
            quantity: i.quantity,
            pricePerUnit: i.pricePerUnit,
            purchasePrice: pp,
          );
        })
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
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
      body: SelectionArea(child: ResponsiveWrapper(child: ListView(
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
          // ── Customer change (admin only, pending orders) ────
          if (widget.srDocId == null && _currentStatus != 'delivered' && _currentStatus != 'cancelled') ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _changeCustomer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF2563EB).withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB), size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ক্রেতা', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      Text(_currentShopName.isNotEmpty ? _currentShopName : 'ক্রেতা নির্বাচিত নেই', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ]),
                ),
              ),
            ),
          ],
          // ── Dispatch info ──────────────────────────────────
          if (widget.order.memoNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            _dispatchInfoCard(scheme),
          ],
          // ── Delivery info ──────────────────────────────────
          if (_deliveredAt != null) ...[
            const SizedBox(height: 12),
            _deliveryInfoCard(scheme),
          ],
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
      ))),
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
                            CallButton(
                                phone: widget.order.shopPhone,
                                color: Colors.white70),
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
                            CallButton(
                                phone: widget.order.userPhone,
                                color: Colors.white70),
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
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded,
                          size: 15,
                          color: scheme.onSurface.withAlpha(140)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.order.shopPhone.isNotEmpty
                              ? widget.order.shopPhone
                              : widget.order.userPhone,
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurface.withAlpha(180)),
                        ),
                      ),
                      CallButton(
                        phone: widget.order.shopPhone.isNotEmpty
                            ? widget.order.shopPhone
                            : widget.order.userPhone,
                        size: 18,
                      ),
                    ],
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
                    } else if (s == 'dispatched') {
                      await _showDispatchDialog(_currentStatus);
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
              ..._savedItems.asMap().entries.map((e) =>
                  _viewItemRow(e.key, e.value, scheme)),
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
            if (!_editMode && _currentStatus != 'cancelled') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addReplaceFromDetailPage,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('রিপ্লেস প্রডাক্ট যোগ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewItemRow(int index, OrderItem i, ColorScheme scheme) {
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
                GestureDetector(
                  onTap: () => _editPurchasePriceViewMode(index, i),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ক্রয়: ৳${_fmt.format(i.purchasePrice.toInt())}',
                        style: TextStyle(
                            fontSize: 11,
                            color: i.purchasePrice > 0
                                ? const Color(0xFFDC2626)
                                : scheme.onSurface.withAlpha(120)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 12,
                          color: scheme.onSurface.withAlpha(140)),
                    ],
                  ),
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
                GestureDetector(
                  onTap: () => _editSellingPriceEditMode(item),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '৳${_fmt.format(item.pricePerUnit.toInt())} × ${item.quantity} = ৳${_fmt.format((item.quantity * item.pricePerUnit).toInt())}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF0891B2),
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 12,
                          color: scheme.onSurface.withAlpha(140)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _editPurchasePriceEditMode(item),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ক্রয়: ৳${_fmt.format(item.purchasePrice.toInt())}',
                        style: TextStyle(
                            fontSize: 11,
                            color: item.purchasePrice > 0
                                ? const Color(0xFFDC2626)
                                : scheme.onSurface.withAlpha(120)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 12,
                          color: scheme.onSurface.withAlpha(140)),
                    ],
                  ),
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
          purchasePrice: p.purchasePrice,
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
            purchasePrice: p.purchasePrice,
          ));
        }
      }
    });
  }

  // ── Dispatch dialog ──────────────────────────────────────────

  Future<void> _showDispatchDialog(String previousStatus) async {
    final scheme = Theme.of(context).colorScheme;
    final memoCtrl = TextEditingController(
      text: '#MEM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Text('স্টক আউট / Dispatch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                    _dialogPayRow('অর্ডার', '#${widget.order.id}', const Color(0xFF0891B2)),
                    const SizedBox(height: 6),
                    _dialogPayRow('কাস্টমার', widget.order.shopName, const Color(0xFF2563EB)),
                    const SizedBox(height: 6),
                    _dialogPayRow('প্রডাক্ট', '${widget.order.items.length} টি', const Color(0xFF7C3AED)),
                    const SizedBox(height: 6),
                    _dialogPayRow('টোটাল', '৳ ${_fmt.format(widget.order.totalAmount.toInt())}', const Color(0xFF0891B2)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('মেমো / চালান নাম্বার',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 4),
              TextField(
                controller: memoCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'মেমো নাম্বার লিখুন',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'সতর্কতা: Dispatch করলে স্টক কেটে যাবে। এটি undo করা যাবে না।',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Dispatch করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final memo = memoCtrl.text.trim();
      if (memo.isEmpty) {
        Get.snackbar('ত্রুটি', 'মেমো নাম্বার দিতে হবে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      setState(() => _currentStatus = 'dispatched');
      await controller.dispatchOrder(
        orderId: widget.order.id,
        items: widget.order.items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
        memoNumber: memo,
      );
      Get.snackbar('সফল', 'স্টক আউট সম্পন্ন হয়েছে\nমেমো: $memo', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFD97706), colorText: Colors.white);
    }
    memoCtrl.dispose();
  }

  // ── Delivery confirmation + payment dialog ─────────────────

  Future<void> _showDeliveryPaymentDialog(String previousStatus) async {
    final alreadyDelivered = previousStatus == 'delivered';
    final scheme = Theme.of(context).colorScheme;
    final total = _savedTotal;
    final orderDue = total - _currentPaid;
    final previousDue = alreadyDelivered && _currentPreviousDue > 0 ? _currentPreviousDue : _currentUserDue;
    final grandTotal = (orderDue.toInt() + previousDue).clamp(0, 9999999);

    final payCtrl = TextEditingController();
    List<_PaymentRow> paymentRows = [_PaymentRow()];
    final memoCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    DateTime deliveryDate = DateTime.now();

    List<AdminReplaceModel> pendingReplaces = [];
    final Set<String> selectedPendingIds = {};
    bool loadingPending = true;
    final List<_ReplaceReturnItem> returnItems = [];
    final List<_ReturnItem> _saleReturnItems = [];

    AdminReplaceController? _rc;
    try { _rc = Get.find<AdminReplaceController>(); } catch (_) { _rc = Get.put(AdminReplaceController()); }
    if (_currentUserId.isNotEmpty) { try { pendingReplaces = await _rc!.fetchPendingForCustomer(_currentUserId); } catch (_) {} }
    loadingPending = false;
    if (!mounted) { payCtrl.dispose(); memoCtrl.dispose(); discountCtrl.dispose(); for (final r in paymentRows) { r.dispose(); } return; }

    final confirmed = await Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 600 ? 480 : MediaQuery.of(context).size.width - 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: const Row(children: [Icon(Icons.local_shipping_rounded, color: Color(0xFF16A34A), size: 22), SizedBox(width: 8), Text('ডেলিভারি পেমেন্ট', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: StatefulBuilder(builder: (ctx, setSt) {
          final paidNow = paymentRows.fold<num>(0, (s, r) => s + (num.tryParse(r.amountCtrl.text.trim()) ?? 0));
          final saleReturnTotal = _saleReturnItems.fold<num>(0, (s, r) => s + r.totalPrice).toInt();
          final totalDeduction = returnItems.where((r) => r.resolutionType == 'money_deduct').fold<int>(0, (s, r) => s + r.deductionAmount);
          final discountAmount = num.tryParse(discountCtrl.text.trim()) ?? 0;
          final totalPaidNow = paidNow.toInt() + totalDeduction + saleReturnTotal;
          final newDue = (grandTotal - totalPaidNow - discountAmount.toInt()).clamp(0, 9999999);
          final totalPayable = grandTotal;
          return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant.withAlpha(80))), child: Column(children: [
              Row(children: [const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0891B2)), const SizedBox(width: 6), const Text('মেমো হিসাব', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0891B2)))]),
              const SizedBox(height: 8),
              _dialogPayRow('পূর্বের বাকি', '৳ ${_fmt.format(previousDue)}', const Color(0xFFDC2626)),
              const SizedBox(height: 4),
              _dialogPayRow('আজকের অর্ডার', '৳ ${_fmt.format(orderDue.toInt())}', const Color(0xFF0891B2)),
              if (saleReturnTotal > 0) ...[const SizedBox(height: 4), _dialogPayRow('ফেরত বাদ', '− ৳ ${_fmt.format(saleReturnTotal)}', const Color(0xFF8B5CF6))],
              const SizedBox(height: 4), Container(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 4),
              _dialogPayRow('দিতে হবে', '৳ ${_fmt.format(totalPayable)}', const Color(0xFF0891B2), bold: true),
              if (discountAmount > 0) ...[const SizedBox(height: 4), _dialogPayRow('ডিসকাউন্ট', '− ৳ ${_fmt.format(discountAmount.toInt())}', const Color(0xFFD97706))],
              if (paidNow > 0) ...[const SizedBox(height: 4), _dialogPayRow('আজকের জমা', '৳ ${_fmt.format(totalPaidNow.toInt())}', const Color(0xFF16A34A))],
              if (totalPaidNow > 0) ...[const SizedBox(height: 4), _dialogPayRow('আজকের বাকি', '৳ ${_fmt.format((total.toInt() - totalPaidNow.toInt() - discountAmount.toInt()).clamp(0, 9999999))}', const Color(0xFFDC2626))],
              if (totalDeduction > 0) Padding(padding: const EdgeInsets.only(top: 4), child: _dialogPayRow('  (রিপ্লেস জমা হিসাবে)', '৳ ${_fmt.format(totalDeduction)}', const Color(0xFF16A34A), small: true)),
              const SizedBox(height: 4), Container(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: newDue > 0 ? const Color(0xFFDC2626).withAlpha(15) : const Color(0xFF16A34A).withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: newDue > 0 ? const Color(0xFFDC2626).withAlpha(60) : const Color(0xFF16A34A).withAlpha(60))),
                child: Row(children: [Icon(Icons.account_balance_wallet_rounded, size: 18, color: newDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)), const SizedBox(width: 8), const Text('নতুন বাকি', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const Spacer(), Text('৳ ${_fmt.format(newDue)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: newDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)))]),
              ),
            ])),
            const SizedBox(height: 12),
            // ── রিপ্লেস প্রডাক্ট ──────────────────────────────
            Row(children: [
              const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              const Text('রিপ্লেস প্রডাক্ট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              if (pendingReplaces.isNotEmpty || returnItems.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Text('${selectedPendingIds.length + returnItems.length}টি', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showReplaceProductSheet(setSt, pendingReplaces, selectedPendingIds, returnItems, scheme),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('যোগ', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
              ),
            ]),
            if (pendingReplaces.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...pendingReplaces.where((r) => selectedPendingIds.contains(r.id)).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 24),
                child: Text('✓ ${r.productName}: ${r.quantity}টি হস্তান্তর', style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
              )),
            ],
            if (returnItems.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...returnItems.asMap().entries.map((e) {
                final item = e.value;
                final idx = e.key;
                String label;
                final qtyStr = item.quantity > 1 ? '${item.quantity}টি ' : '';
                if (item.resolutionType == 'money_deduct') {
                  label = '$qtyStr${item.product.name}: ৳${item.deductionAmount} টাকা কাটা';
                } else if (item.resolutionType == 'replace_given') {
                  label = '$qtyStr${item.product.name}: রিপ্লেস দেওয়া হল';
                } else {
                  label = '$qtyStr${item.product.name}: রিপ্লেস নেওয়া হল';
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    const SizedBox(width: 24),
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED)))),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 14), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, color: Colors.red.shade400, onPressed: () => setSt(() { item.dispose(); returnItems.removeAt(idx); })),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 12),
            // ── ফেরত প্রডাক্ট ──────────────────────────────────
            Row(children: [
              const Icon(Icons.keyboard_return_rounded, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              const Text('ফেরত প্রডাক্ট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              if (_saleReturnItems.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Text('${_saleReturnItems.length}টি', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showReturnProductSheet(setSt, _saleReturnItems, scheme),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('যোগ', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
              ),
            ]),
            if (_saleReturnItems.isNotEmpty)
              ..._saleReturnItems.asMap().entries.map((e) {
                final item = e.value;
                final idx = e.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    const SizedBox(width: 24),
                    Expanded(child: Text('${item.product.name}: ${item.quantity}টি × ৳${_fmt.format(item.unitPrice.toInt())} = ৳${_fmt.format(item.totalPrice.toInt())}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6)))),
                    Text('৳${_fmt.format(item.totalPrice.toInt())}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                    const SizedBox(width: 4),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 14), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, color: Colors.red.shade400, onPressed: () => setSt(() { item.dispose(); _saleReturnItems.removeAt(idx); })),
                  ]),
                );
              }),
            const SizedBox(height: 14),
            Row(children: [const Text('নগদ জমা', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)), const Spacer(), TextButton.icon(onPressed: () => setSt(() => paymentRows.add(_PaymentRow())), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('আরও মাধ্যম', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact))]),
            const SizedBox(height: 4),
            ...paymentRows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  SizedBox(width: 80, child: _paymentMethodDropdown2(setSt, r)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: r.amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(prefixText: '৳ ', hintText: 'টাকা', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), onChanged: (_) => setSt(() {}))),
                  if (paymentRows.length > 1)
                    Padding(padding: const EdgeInsets.only(left: 4), child: IconButton(icon: const Icon(Icons.close_rounded, size: 16), visualDensity: VisualDensity.compact, color: Colors.red.shade400, onPressed: () => setSt(() { r.dispose(); paymentRows.removeAt(i); }))),
                ]),
              );
            }),
            const SizedBox(height: 12),
            const Text('ডিসকাউন্ট (বাদ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)), const SizedBox(height: 4),
            TextField(controller: discountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(prefixText: '৳ ', hintText: 'যদি ডিসকাউন্ট দিতে চান', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onChanged: (_) => setSt(() {})),
            const SizedBox(height: 12),
            const Text('লোকাল মেমো নাম্বার', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)), const SizedBox(height: 4),
            TextField(controller: memoCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'যেমন: 233', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 12),
            const Text('ডেলিভারির তারিখ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)), const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: deliveryDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                if (picked != null) setSt(() => deliveryDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [Icon(Icons.calendar_today_rounded, size: 16, color: scheme.onSurfaceVariant), const SizedBox(width: 8), Text(DateFormat('dd/MM/yyyy').format(deliveryDate), style: const TextStyle(fontSize: 14)), const Spacer(), Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurfaceVariant)]),
              ),
            ),
          ]));
                }),
              ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(onPressed: () => Get.back(result: true), icon: const Icon(Icons.check_rounded, size: 16), label: const Text('ডেলিভার্ড করুন'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final paidNow = paymentRows.fold<num>(0, (s, r) => s + (num.tryParse(r.amountCtrl.text.trim()) ?? 0));
      final paymentEntries = paymentRows.where((r) => (num.tryParse(r.amountCtrl.text.trim()) ?? 0) > 0).map((r) => {
        'amount': num.tryParse(r.amountCtrl.text.trim()) ?? 0,
        'method': r.method,
      }).toList();
      final primaryMethod = paymentEntries.isNotEmpty ? paymentEntries.first['method'] as String : 'SR হাতে';
      final totalDeduction = returnItems.where((r) => r.resolutionType == 'money_deduct').fold<int>(0, (s, r) => s + r.deductionAmount);
      final saleReturnTotal = _saleReturnItems.fold<num>(0, (s, r) => s + r.totalPrice).toInt();
      final discountAmount = num.tryParse(discountCtrl.text.trim()) ?? 0;
      final memo = memoCtrl.text.trim();
      final totalPaidNow = paidNow.toInt() + totalDeduction + saleReturnTotal;
      final newDue = (grandTotal - totalPaidNow - discountAmount.toInt()).clamp(0, 9999999);
      final totalPaid = _currentPaid.toInt() + totalPaidNow;

      if (!alreadyDelivered) { setState(() { _currentStatus = 'delivered'; _deliveredAt = deliveryDate; }); await controller.updateOrderStatus(widget.order.id, 'delivered', previousStatus: previousStatus, deliveredBySrId: widget.srDocId, deliveryDate: deliveryDate, items: _savedItems.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList()); }
      if (totalPaid != _currentPaid) { await controller.updatePaidAmount(widget.order.id, totalPaid); setState(() { _currentPaid = totalPaid; _paidCtrl.text = totalPaid.toStringAsFixed(0); }); }
      if (discountAmount > 0) await controller.saveDiscountAmount(widget.order.id, discountAmount);
      if (paymentEntries.isNotEmpty) { try { await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'payments': paymentEntries, 'paymentMethod': primaryMethod}); } catch (_) {} }
      if (mounted) setState(() { _currentPayments = paymentEntries; _currentPaymentMethod = primaryMethod; });
      if (memo.isNotEmpty) { try { await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'localMemo': memo}); } catch (_) {} if (mounted) setState(() => _currentLocalMemo = memo); }
      if (_currentUserId.isNotEmpty) { if (mounted) setState(() => _currentPreviousDue = _currentUserDue); await controller.updateUserDue(_currentUserId, newDue); if (mounted) setState(() => _currentUserDue = newDue); try { await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'previousDue': _currentPreviousDue}); } catch (_) {} }
      if (!alreadyDelivered && _saleReturnItems.isNotEmpty) { try { final sc = Get.find<StockInController>(); await sc.addMultipleStockIn(date: deliveryDate, source: _currentShopName, note: 'অর্ডার #${widget.order.id} — ফেরত', updatePurchasePrice: false, items: _saleReturnItems.map((i) => {'productId': i.product.id, 'productName': i.product.name, 'image': i.product.images.isNotEmpty ? i.product.images.first : '', 'quantity': i.quantity, 'unitPrice': i.unitPrice}).toList()); for (final item in _saleReturnItems) { item.dispose(); } } catch (e) { print('স্টক ইন error: $e'); } await controller.saveReturnAmount(widget.order.id, saleReturnTotal); }
      if (totalDeduction > 0) await controller.saveDeductionAmount(widget.order.id, totalDeduction);
      if (mounted) setState(() { _currentDeductionAmount = totalDeduction; _currentReturnAmount = saleReturnTotal; _currentDiscountAmount = discountAmount; });
      if (!alreadyDelivered && selectedPendingIds.isNotEmpty) { try { for (final r in pendingReplaces) { if (selectedPendingIds.contains(r.id)) await _rc!.deliverToCustomer(entry: r, note: 'অর্ডার #${widget.order.id} এর সাথে ডেলিভারি'); } await _rc!.fetchEntries(force: true); } catch (_) {} }
      if (!alreadyDelivered && returnItems.isNotEmpty) { try { for (final item in returnItems.where((i) => i.resolutionType != 'replace_given')) { await _rc!.addCustomerIn(productId: item.product.id, productName: item.product.name, quantity: item.quantity, customerId: _currentUserId, customerName: _currentShopName, customerPhone: _currentShopPhone, customerAddress: _currentShopAddress, customerResolutionType: item.resolutionType, deductionAmount: item.deductionAmount, note: 'ডেলিভারি #${widget.order.id} এ ফেরত', date: DateTime.now()); } final stockBatch = FirebaseFirestore.instance.batch(); for (final item in returnItems.where((i) => i.resolutionType == 'product_replace' || i.resolutionType == 'replace_given')) { stockBatch.update(FirebaseFirestore.instance.collection('products').doc(item.product.id), {'stock': FieldValue.increment(-item.quantity)}); } await stockBatch.commit(); try { Get.find<ProductController>().fetchProducts(forceRefresh: true); } catch (_) {} final replaceItemsData = returnItems.map((i) => {'productId': i.product.id, 'productName': i.product.name, 'quantity': i.quantity, 'resolutionType': i.resolutionType, 'deductionAmount': i.deductionAmount}).toList(); await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'replaceItems': replaceItemsData}); setState(() => _currentReplaceItems = replaceItemsData); await _rc!.fetchEntries(force: true); } catch (_) {} }
      final msgParts = <String>['ডেলিভারি সম্পন্ন ও পেমেন্ট আপডেট হয়েছে'];
      if (selectedPendingIds.isNotEmpty) msgParts.add('${selectedPendingIds.length} টি রিপ্লেস ডেলিভারি');
      if (returnItems.isNotEmpty) msgParts.add('${returnItems.length} টি ফেরত রিপ্লেস');
      Get.snackbar('সফল', msgParts.join(' • '), snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
    }
    payCtrl.dispose(); memoCtrl.dispose(); discountCtrl.dispose(); for (final r in paymentRows) { r.dispose(); }
  }

  Widget _dialogPayRow(String label, String value, Color valueColor, {bool bold = false, bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: small ? 11.0 : (bold ? 14.0 : 13.0), color: Colors.black54)),
        Text(value, style: TextStyle(fontSize: bold ? 15.0 : 14.0, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _paymentMethodDropdown(StateSetter setSt) {
    const methods = ['SR হাতে', 'বিকাশ', 'নগদ অ্যাপ', 'রকেট', 'ব্যাংক'];
    return DropdownButtonFormField<String>(
      value: methods.contains(_currentPaymentMethod) ? _currentPaymentMethod : 'SR হাতে',
      isDense: true,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (v) { if (v != null) { _currentPaymentMethod = v; setSt(() {}); } },
    );
  }

  // ── Replace product bottom sheet ──────────────────────────
  void _showReplaceProductSheet(StateSetter setSt, List<AdminReplaceModel> pendingReplaces, Set<String> selectedPendingIds, List<_ReplaceReturnItem> returnItems, ColorScheme scheme) {
    String q = '';
    ProductModel? sel;
    String res = 'money_deduct';
    final dedC = TextEditingController();
    int qty = 1;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, sheetSt) {
        final displayed = q.isEmpty
            ? _allProducts
            : _allProducts
                .where((p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.brandName.toLowerCase().contains(q) ||
                    p.productCode.toLowerCase().contains(q))
                .toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.96,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Text('রিপ্লেস প্রডাক্ট যোগ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  if (sel != null)
                    TextButton.icon(
                      onPressed: () => sheetSt(() { sel = null; res = 'money_deduct'; qty = 1; dedC.clear(); }),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('তালিকায় ফিরুন', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              if (sel == null) ...[
                // ── Search ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => sheetSt(() => q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'নাম বা কোড দিয়ে খুঁজুন…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true, fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                // ── Pending replaces ──────────────────────
                if (pendingReplaces.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text('হস্তান্তরযোগ্য রিপ্লেস', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  ),
                  ...pendingReplaces.map((r) => InkWell(
                    onTap: () => sheetSt(() { if (selectedPendingIds.contains(r.id)) selectedPendingIds.remove(r.id); else selectedPendingIds.add(r.id); }),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180), width: 24, height: 24,
                          decoration: BoxDecoration(color: selectedPendingIds.contains(r.id) ? const Color(0xFF7C3AED) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: selectedPendingIds.contains(r.id) ? const Color(0xFF7C3AED) : scheme.outlineVariant, width: 2)),
                          child: selectedPendingIds.contains(r.id) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${r.quantity}টি • ${r.customerName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ])),
                      ]),
                    ),
                  )),
                  const Divider(height: 1),
                ],
                // ── Product list ─────────────────────────
                Expanded(
                  child: _loadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : displayed.isEmpty
                          ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              controller: scrollCtrl, itemCount: displayed.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = displayed[i];
                                return InkWell(
                                  onTap: () => sheetSt(() {
                                    sel = p;
                                    res = 'money_deduct';
                                    qty = 1;
                                    dedC.text = p.wholesalePrice.toStringAsFixed(0);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                    child: Row(children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(46, scheme)) : _imgPlaceholder(46, scheme)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          Text('৳${_fmt.format(p.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0891B2))),
                                          if (p.brandName.isNotEmpty) ...[const SizedBox(width: 8), Text(p.brandName, style: const TextStyle(fontSize: 11, color: Colors.grey))],
                                        ]),
                                      ])),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
              ] else ...[
                // ── Selected product detail + resolution ──
                Expanded(child: SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Product card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant.withAlpha(80))),
                    child: Row(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: sel!.images.isNotEmpty ? Image.network(sel!.images.first, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(56, scheme)) : _imgPlaceholder(56, scheme)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sel!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('৳${_fmt.format(sel!.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF7C3AED))),
                          if (sel!.brandName.isNotEmpty) ...[const SizedBox(width: 8), Text(sel!.brandName, style: const TextStyle(fontSize: 11, color: Colors.grey))],
                        ]),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Quantity
                  Text('পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _qtyBtnPurple(Icons.remove_rounded, () { if (qty > 1) sheetSt(() => qty--); }),
                    const SizedBox(width: 4),
                    Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 4),
                    _qtyBtnPurple(Icons.add_rounded, () => sheetSt(() => qty++)),
                  ]),
                  const SizedBox(height: 20),
                  // Resolution type
                  Text('রিপ্লেস স্ট্যাটাস', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: res,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    items: const [
                      DropdownMenuItem(value: 'money_deduct', child: Text('টাকা কাটা', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'product_replace', child: Text('রিপ্লেস নেওয়া হল', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'replace_given', child: Text('রিপ্লেস দেওয়া হল', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => sheetSt(() {
                      res = v!;
                      if (res == 'money_deduct') dedC.text = sel!.wholesalePrice.toStringAsFixed(0);
                    }),
                  ),
                  if (res == 'money_deduct') ...[
                    const SizedBox(height: 16),
                    Text('টাকার পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dedC, keyboardType: TextInputType.number,
                      decoration: InputDecoration(prefixText: '৳ ', hintText: 'টাকার পরিমাণ লিখুন', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    ),
                    const SizedBox(height: 6),
                    Text('এই টাকা কাস্টমারের জমা হিসাবে যোগ হবে', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: () {
                      final ded = res == 'money_deduct' ? (int.tryParse(dedC.text.trim()) ?? sel!.wholesalePrice.toInt()) : 0;
                      setSt(() { returnItems.add(_ReplaceReturnItem(product: sel!, quantity: qty, resolutionType: res, deductionAmount: ded * qty)); });
                      dedC.dispose();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.add_rounded), label: const Text('যোগ করুন'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                  const SizedBox(height: 16),
                ]))),
              ],
            ]),
          ),
        );
      }),
    );
  }

  // ── Return product bottom sheet ─────────────────────────────
  void _showReturnProductSheet(StateSetter setSt, List<_ReturnItem> saleReturnItems, ColorScheme scheme) {
    String q = '';
    ProductModel? sel;
    int qt = 1;
    final priceC = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, sheetSt) {
        final displayed = q.isEmpty
            ? _allProducts
            : _allProducts
                .where((p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.brandName.toLowerCase().contains(q) ||
                    p.productCode.toLowerCase().contains(q))
                .toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.96,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Text('ফেরত প্রডাক্ট যোগ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  if (sel != null)
                    TextButton.icon(
                      onPressed: () => sheetSt(() { sel = null; qt = 1; priceC.clear(); }),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('তালিকায় ফিরুন', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              if (sel == null) ...[
                // ── Search ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => sheetSt(() => q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'নাম বা কোড দিয়ে খুঁজুন…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true, fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                // ── Product list ─────────────────────────
                Expanded(
                  child: _loadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : displayed.isEmpty
                          ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              controller: scrollCtrl, itemCount: displayed.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = displayed[i];
                                return InkWell(
                                  onTap: () => sheetSt(() {
                                    sel = p;
                                    qt = 1;
                                    priceC.text = p.wholesalePrice.toStringAsFixed(0);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                    child: Row(children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(46, scheme)) : _imgPlaceholder(46, scheme)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          Text('৳${_fmt.format(p.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF8B5CF6))),
                                          if (p.brandName.isNotEmpty) ...[const SizedBox(width: 8), Text(p.brandName, style: const TextStyle(fontSize: 11, color: Colors.grey))],
                                        ]),
                                      ])),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
              ] else ...[
                // ── Selected product detail ───────────────
                Expanded(child: SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Product card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant.withAlpha(80))),
                    child: Row(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: sel!.images.isNotEmpty ? Image.network(sel!.images.first, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(56, scheme)) : _imgPlaceholder(56, scheme)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sel!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('৳${_fmt.format(sel!.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF8B5CF6))),
                          if (sel!.brandName.isNotEmpty) ...[const SizedBox(width: 8), Text(sel!.brandName, style: const TextStyle(fontSize: 11, color: Colors.grey))],
                        ]),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Quantity
                  Text('পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _qtyBtnPurple(Icons.remove_rounded, () { if (qt > 1) sheetSt(() => qt--); }),
                    const SizedBox(width: 4),
                    Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('$qt', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 4),
                    _qtyBtnPurple(Icons.add_rounded, () => sheetSt(() => qt++)),
                  ]),
                  const SizedBox(height: 20),
                  // Price
                  Text('মূল্য (প্রতি পিস)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceC, keyboardType: TextInputType.number,
                    decoration: InputDecoration(prefixText: '৳ ', hintText: 'মূল্য লিখুন', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    onChanged: (_) => sheetSt(() {}),
                  ),
                  const SizedBox(height: 8),
                  // Total preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withAlpha(15), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Text('মোট ফেরত মূল্য', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                      const Spacer(),
                      Text('৳${_fmt.format((qt * (num.tryParse(priceC.text.trim()) ?? 0)).toInt())}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6))),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('এই টাকা কাস্টমারের জমা হিসাবে যোগ হবে', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: () {
                      final price = num.tryParse(priceC.text.trim()) ?? sel!.wholesalePrice;
                      setSt(() { saleReturnItems.add(_ReturnItem(product: sel!, quantity: qt, unitPrice: price)); });
                      priceC.dispose();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.add_rounded), label: const Text('যোগ করুন'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                  const SizedBox(height: 16),
                ]))),
              ],
            ]),
          ),
        );
      }),
    );
  }

  Widget _paymentMethodDropdown2(StateSetter setSt, _PaymentRow row) {
    const methods = ['SR হাতে', 'বিকাশ', 'নগদ', 'রকেট', 'ব্যাংক'];
    return DropdownButtonFormField<String>(
      value: methods.contains(row.method) ? row.method : 'SR হাতে',
      isDense: true,
      isExpanded: false,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
      items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 10)))).toList(),
      onChanged: (v) { if (v != null) { row.method = v; setSt(() {}); } },
    );
  }

  Widget _qtyBtnPurple(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7C3AED).withAlpha(80)),
          color: const Color(0xFF7C3AED).withAlpha(14),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
      ),
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

  // ── Dispatch info card ───────────────────────────────────────

  Widget _dispatchInfoCard(ColorScheme scheme) {
    final hasInfo = widget.order.memoNumber.isNotEmpty;
    if (!hasInfo) return const SizedBox.shrink();
    final dateFmt = DateFormat('dd MMMM yyyy, h:mm a');
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
                    color: const Color(0xFFD97706).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706), size: 18),
                ),
                const SizedBox(width: 12),
                const Text('স্টক আউট / Dispatch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.tag_rounded, 'মেমো: ${widget.order.memoNumber}', scheme, textColor: const Color(0xFFD97706)),
            if (_dispatchedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 15, color: scheme.onSurface.withAlpha(140)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(dateFmt.format(_dispatchedAt!),
                        style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(180))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'তারিখ সম্পাদন',
                    onPressed: () => _editDispatchedAt(),
                  ),
                ],
              ),
            ],
            if (widget.order.dispatchedBy.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.person_rounded, 'Dispatched by: ${widget.order.dispatchedBy}', scheme),
            ],
          ],
        ),
      ),
    );
  }

  // ── Delivery info card ──────────────────────────────────────

  Widget _deliveryInfoCard(ColorScheme scheme) {
    final deliveredAt = _deliveredAt;
    if (deliveredAt == null) return const SizedBox.shrink();
    final dateFmt = DateFormat('dd MMMM yyyy, h:mm a');
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
                    color: const Color(0xFF16A34A).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                ),
                const SizedBox(width: 12),
                const Text('ডেলিভারি সম্পন্ন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 15, color: scheme.onSurface.withAlpha(140)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(dateFmt.format(deliveredAt),
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(180))),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'তারিখ সম্পাদন',
                  onPressed: () => _editDeliveredAt(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Scheduled delivery card ───────────────────────────────────

  Widget _scheduledDeliveryCard(ColorScheme scheme) {
    final date = _scheduledDate;
    final dateFmt = DateFormat('dd MMMM yyyy');
    final hasDate = date != null;
    final isAdmin = widget.srDocId == null;
    final hasAssignedSr = _assignedSrId.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── Date row ──────────────────────────────────────
            Row(
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
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked == null) return;
                    await controller.setScheduledDelivery(widget.order.id, picked);
                    setState(() => _scheduledDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(hasDate ? 'পরিবর্তন' : 'তারিখ দিন'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            // ── SR assignment row (admin only) ─────────────────
            if (isAdmin) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasAssignedSr
                          ? const Color(0xFF7C3AED).withAlpha(20)
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_pin_rounded,
                        color: hasAssignedSr
                            ? const Color(0xFF7C3AED)
                            : scheme.onSurface.withAlpha(120),
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ডেলিভারি SR',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        Text(
                          hasAssignedSr ? _assignedSrName : 'SR নির্বাচিত নেই',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: hasAssignedSr
                                  ? const Color(0xFF7C3AED)
                                  : scheme.onSurface.withAlpha(160)),
                        ),
                      ],
                    ),
                  ),
                  if (hasAssignedSr)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: 'SR সরান',
                      color: Colors.red.shade400,
                      onPressed: () async {
                        await controller.assignDelivery(
                            widget.order.id, '', '', null);
                        setState(() {
                          _assignedSrId = '';
                          _assignedSrName = '';
                        });
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _pickSrForDelivery(scheme),
                    icon: Icon(_loadingSrs
                        ? Icons.hourglass_top_rounded
                        : Icons.person_search_rounded,
                        size: 16),
                    label: Text(hasAssignedSr ? 'পরিবর্তন' : 'SR দিন'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('পেমেন্ট তথ্য', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _payRow('মোট অর্ডার', '৳ ${_fmt.format(total.toInt())}', const Color(0xFF0891B2)),
          const SizedBox(height: 4),
          _payRow('পূর্বের বাকি (ডেলিভারির সময়)', '৳ ${_fmt.format(_currentPreviousDue)}', _currentPreviousDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          const SizedBox(height: 4),
          Container(height: 1, color: scheme.outlineVariant.withAlpha(60)),
          const SizedBox(height: 4),
          _payRow('মোট দেনা', '৳ ${_fmt.format((total.toInt() + _currentPreviousDue))}', const Color(0xFF0891B2), bold: true),
          if (_currentDeductionAmount > 0) ...[const SizedBox(height: 4), _payRow('রিপ্লেস বাবদ বাদ', '− ৳ ${_fmt.format(_currentDeductionAmount.toInt())}', const Color(0xFFDC2626))],
          if (_currentReturnAmount > 0) ...[const SizedBox(height: 4), _payRow('ফেরত বাদ', '− ৳ ${_fmt.format(_currentReturnAmount.toInt())}', const Color(0xFF8B5CF6))],
          if (_currentDiscountAmount > 0) ...[const SizedBox(height: 4), Row(children: [Expanded(child: _payRow('ডিসকাউন্ট', '− ৳ ${_fmt.format(_currentDiscountAmount.toInt())}', const Color(0xFFD97706))), IconButton(icon: const Icon(Icons.edit_rounded, size: 14), visualDensity: VisualDensity.compact, tooltip: 'ডিসকাউন্ট সম্পাদন', onPressed: _editDiscount)])] else Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _editDiscount, icon: const Icon(Icons.add_rounded, size: 14), label: const Text('ডিসকাউন্ট যোগ', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)))),
          const SizedBox(height: 4),
          Container(height: 1, color: scheme.outlineVariant.withAlpha(60)),
          const SizedBox(height: 4),
          Builder(builder: (_) {
            final cashPaid = (paid.toInt() - _currentDeductionAmount.toInt() - _currentReturnAmount.toInt()).clamp(0, 9999999);
            return Column(children: [
              if (_currentDeductionAmount > 0) _payRow('জমা: রিপ্লেস বাবদ', '৳ ${_fmt.format(_currentDeductionAmount.toInt())}', const Color(0xFF7C3AED)),
              if (_currentReturnAmount > 0) _payRow('জমা: ফেরত বাবদ', '৳ ${_fmt.format(_currentReturnAmount.toInt())}', const Color(0xFF8B5CF6)),
              if (_currentPayments.isNotEmpty)
                ..._currentPayments.where((p) => ((p['amount'] as num?)?.toInt() ?? 0) > 0).map((p) => _payRow('জমা: ${p['method'] ?? 'নগদ'}', '৳ ${_fmt.format((p['amount'] as num?)?.toInt() ?? 0)}', const Color(0xFF16A34A)))
              else
                _payRow('জমা: নগদ (${_currentPaymentMethod.isNotEmpty ? _currentPaymentMethod : "SR হাতে"})', '৳ ${_fmt.format(cashPaid)}', const Color(0xFF16A34A)),
              const SizedBox(height: 4),
              Container(height: 1, color: scheme.outlineVariant.withAlpha(60)),
              const SizedBox(height: 4),
              _payRow('মোট জমা', '৳ ${_fmt.format(paid.toInt())}', const Color(0xFF16A34A), bold: true),
            ]);
          }),
          Builder(builder: (_) {
            final paidInt = paid.toInt();
            final totalInt = total.toInt();
            final disc = _currentDiscountAmount.toInt();
            final todayDue = (totalInt - paidInt - disc).clamp(0, 9999999);
            return Column(children: [
              if (todayDue > 0) ...[
                const SizedBox(height: 4),
                _payRow('আজকের বাকি', '৳ ${_fmt.format(todayDue)}', const Color(0xFFDC2626)),
              ] else if (paidInt + disc > totalInt) ...[
                const SizedBox(height: 4),
                _payRow('আজকের বাকি কালেকশন', '৳ ${_fmt.format((paidInt + disc - totalInt).clamp(0, 9999999))}', const Color(0xFF16A34A)),
              ],
            ]);
          }),
          const SizedBox(height: 4),
          Builder(builder: (_) {
            final nd = (_currentPreviousDue + total.toInt() - paid.toInt() - _currentDiscountAmount.toInt()).clamp(0, 9999999);
            return _payRow('নতুন বাকি', '৳ ${_fmt.format(nd)}', nd > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A));
          }),
          const SizedBox(height: 4),
          if (_currentPayments.isNotEmpty)
            _payRow('পেমেন্ট মাধ্যম', _currentPayments.where((p) => ((p['amount'] as num?)?.toInt() ?? 0) > 0).map((p) => '${p['method']} (৳${_fmt.format((p['amount'] as num?)?.toInt() ?? 0)})').join(', '), const Color(0xFF7C3AED))
          else
            Row(children: [Expanded(child: _payRow('পেমেন্ট মাধ্যম', _currentPaymentMethod.isNotEmpty ? _currentPaymentMethod : '—', const Color(0xFF7C3AED))), IconButton(icon: const Icon(Icons.edit_rounded, size: 14), visualDensity: VisualDensity.compact, tooltip: 'মাধ্যম পরিবর্তন', onPressed: _editPaymentMethod)]),
          if (_currentLocalMemo.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Expanded(child: _payRow('লোকাল মেমো', '#$_currentLocalMemo', const Color(0xFF0891B2))), IconButton(icon: const Icon(Icons.edit_rounded, size: 16), visualDensity: VisualDensity.compact, tooltip: 'লোকাল মেমো আপডেট', onPressed: _editLocalMemo)])] else Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _editLocalMemo, icon: const Icon(Icons.add_rounded, size: 14), label: const Text('লোকাল মেমো যোগ', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)))),
          if (_currentReplaceItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(12), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF7C3AED).withAlpha(40))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF7C3AED)), const SizedBox(width: 6), Text('রিপ্লেস প্রডাক্ট (${_currentReplaceItems.length}টি)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)))]),
                const SizedBox(height: 6),
                ..._currentReplaceItems.map((item) {
                  final name = item['productName'] ?? '';
                  final qty = item['quantity'] ?? 0;
                  final type = item['resolutionType'] ?? '';
                  final ded = item['deductionAmount'] ?? 0;
                  final label = type == 'money_deduct' ? '$name × $qty — ৳${_fmt.format(ded)} টাকা কাটা' : type == 'replace_given' ? '$name × $qty — রিপ্লেস দেওয়া হল' : '$name × $qty — রিপ্লেস নেওয়া হল';
                  return Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('• $label', style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED))));
                }),
              ]),
            ),
          ],
          if (_currentStatus == 'delivered' && !widget.order.isDueCollection) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _editPaidAmount, icon: const Icon(Icons.edit_rounded, size: 14), label: const Text('জমা সম্পাদন', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)))),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _editPreviousDue, icon: const Icon(Icons.edit_rounded, size: 14), label: const Text('বাকি সম্পাদন', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)))),
            const Divider(height: 20),
            _profitSection(scheme),
          ],
          if (_currentStatus != 'delivered') ...[const Divider(height: 20), TextField(controller: _paidCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'নতুন জমার পরিমাণ আপডেট করুন', prefixText: '৳ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))), const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async { final amount = num.tryParse(_paidCtrl.text.trim()) ?? _currentPaid; await controller.updatePaidAmount(widget.order.id, amount); setState(() => _currentPaid = amount); Get.snackbar('আপডেট হয়েছে', 'পেমেন্ট তথ্য সেভ হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white); }, icon: const Icon(Icons.payments_rounded), label: const Text('পেমেন্ট আপডেট করুন'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))],
        ]),
      ),
    );
  }

  Widget _profitSection(ColorScheme scheme) {
    final tot = _editMode ? _editTotal : _savedTotal;
    final ded = _currentDeductionAmount.toInt();
    final ret = _currentReturnAmount.toInt();
    final disc = _currentDiscountAmount.toInt();
    final netSales = (tot - ded - ret - disc).clamp(0, 9999999).toInt();
    num cost = 0;
    try { final pc = Get.find<ProductController>(); for (final item in _savedItems) { num c = item.purchasePrice; if (c <= 0) { final p = pc.products.firstWhereOrNull((p) => p.id == item.productId); if (p != null) c = p.purchasePrice; } cost += c * item.quantity; } } catch (_) {}
    final hasSr = _assignedSrId.isNotEmpty || widget.order.deliveredBySrId.isNotEmpty;
    final comm = (netSales * 0.06).round();
    final profitWithSr = (netSales - cost.toInt() - comm).clamp(0, 9999999);
    final profitWithoutSr = (netSales - cost.toInt()).clamp(0, 9999999);
    final profit = hasSr ? profitWithSr : profitWithoutSr;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('লাভের হিসাব', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
      _payRow('মোট অর্ডার', '৳ ${_fmt.format(tot.toInt())}', const Color(0xFF0891B2)),
       if (ded > 0) _payRow('  − রিপ্লেস বাবদ বাদ', '− ৳ ${_fmt.format(ded)}', const Color(0xFFDC2626)),
      if (ret > 0) _payRow('  − ফেরত বাদ', '− ৳ ${_fmt.format(ret)}', const Color(0xFF8B5CF6)),
      if (disc > 0) _payRow('  − ডিসকাউন্ট', '− ৳ ${_fmt.format(disc)}', const Color(0xFFD97706)),
      const SizedBox(height: 6),
      _payRow('নেট বিক্রি', '৳ ${_fmt.format(netSales)}', netSales > 0 ? const Color(0xFF0891B2) : Colors.grey),
      if (cost > 0) ...[const SizedBox(height: 4), _payRow('ক্রয় মূল্য', '− ৳ ${_fmt.format(cost.toInt())}', const Color(0xFFDC2626))],
      if (hasSr) ...[const SizedBox(height: 2), _payRow('SR কমিশন (৬%)', '− ৳ ${_fmt.format(comm)}', const Color(0xFF7C3AED))],
      const SizedBox(height: 6),
      _payRow('নিট লাভ', '৳ ${_fmt.format(profit)}', profit > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
      if (cost > 0 && hasSr) ...[const SizedBox(height: 4), Builder(builder: (_) { final gpct = cost > 0 ? (profitWithoutSr / cost * 100).toStringAsFixed(2) : '0.00'; final npct = cost > 0 ? (profitWithSr / cost * 100).toStringAsFixed(2) : '0.00'; return Column(children: [ _payRow('লাভের হার (SR বাদে)', '$gpct%', profitWithoutSr > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)), const SizedBox(height: 2), _payRow('লাভের হার (SR সহ)', '$npct%', profitWithSr > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)) ]); })],
    ]);
  }

  void _editPurchasePriceViewMode(int index, OrderItem item) async {
    num defaultPP = 0;
    try { final pc = Get.find<ProductController>(); final p = pc.products.firstWhereOrNull((p) => p.id == item.productId); if (p != null) defaultPP = p.purchasePrice; } catch (_) {}
    final ctrl = TextEditingController(text: item.purchasePrice > 0 ? item.purchasePrice.toStringAsFixed(0) : '');
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('ক্রয়মূল্য সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        if (defaultPP > 0) ...[
          const SizedBox(height: 6),
          Text('ডিফল্ট ক্রয়মূল্য: ৳${_fmt.format(defaultPP.toInt())}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: '৳ ',
            hintText: 'ক্রয়মূল্য লিখুন',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
        ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('আপডেট'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white)),
      ],
    ));
    if (ok == true) {
      final pp = num.tryParse(ctrl.text.trim()) ?? 0;
      await controller.updateItemPurchasePrice(widget.order.id, index, pp);
      final updated = _savedItems.toList();
      updated[index] = OrderItem(
        productId: item.productId,
        productName: item.productName,
        image: item.image,
        quantity: item.quantity,
        pricePerUnit: item.pricePerUnit,
        totalPrice: item.totalPrice,
        purchasePrice: pp,
      );
      setState(() { _savedItems = updated; });
    }
    ctrl.dispose();
  }

  void _editSellingPriceEditMode(_EditItem item) async {
    final ctrl = TextEditingController(text: item.pricePerUnit.toStringAsFixed(0));
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('বিক্রয়মূল্য সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: '৳ ',
            hintText: 'বিক্রয়মূল্য লিখুন',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
        ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('সেভ'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white)),
      ],
    ));
    if (ok == true) {
      final pp = num.tryParse(ctrl.text.trim()) ?? item.pricePerUnit;
      if (pp > 0) {
        setState(() {
          item.pricePerUnit = pp;
          item.priceCtrl.text = pp.toStringAsFixed(0);
        });
      }
    }
    ctrl.dispose();
  }

  void _editPurchasePriceEditMode(_EditItem item) async {
    num defaultPP = 0;
    try { final pc = Get.find<ProductController>(); final p = pc.products.firstWhereOrNull((p) => p.id == item.productId); if (p != null) defaultPP = p.purchasePrice; } catch (_) {}
    final ctrl = TextEditingController(text: item.purchasePrice > 0 ? item.purchasePrice.toStringAsFixed(0) : '');
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('ক্রয়মূল্য সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        if (defaultPP > 0) ...[
          const SizedBox(height: 6),
          Text('ডিফল্ট ক্রয়মূল্য: ৳${_fmt.format(defaultPP.toInt())}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: '৳ ',
            hintText: 'ক্রয়মূল্য লিখুন',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
        ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('সেভ'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white)),
      ],
    ));
    if (ok == true) {
      final pp = num.tryParse(ctrl.text.trim()) ?? 0;
      setState(() { item.purchasePrice = pp; });
    }
    ctrl.dispose();
  }

  void _editPaidAmount() async {
    final ctrl = TextEditingController(text: _currentPaid.toStringAsFixed(0));
    final ok = await Get.dialog<bool>(AlertDialog(title: const Text('জমা সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)), content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true, decoration: InputDecoration(prefixText: '৳ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')), ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('আপডেট'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white))]));
    if (ok == true) { final amt = num.tryParse(ctrl.text.trim()) ?? _currentPaid; await controller.updatePaidAmount(widget.order.id, amt); final nd = (_currentPreviousDue + _savedTotal.toInt() - amt.toInt() - _currentDiscountAmount.toInt()).clamp(0, 9999999); if (_currentUserId.isNotEmpty) await controller.updateUserDue(_currentUserId, nd); setState(() { _currentPaid = amt; _paidCtrl.text = amt.toStringAsFixed(0); _currentUserDue = nd; }); }
    ctrl.dispose();
  }

  void _editPreviousDue() async {
    final ctrl = TextEditingController(text: _currentPreviousDue.toString());
    final ok = await Get.dialog<bool>(AlertDialog(title: const Text('পূর্বের বাকি সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)), content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(prefixText: '৳ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')), ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('সেভ'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white))]));
    if (ok == true) { final v = int.tryParse(ctrl.text.trim()) ?? _currentPreviousDue; await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'previousDue': v}); final nd = (v + _savedTotal.toInt() - _currentPaid.toInt() - _currentDiscountAmount.toInt()).clamp(0, 9999999); if (_currentUserId.isNotEmpty) await controller.updateUserDue(_currentUserId, nd); setState(() { _currentPreviousDue = v; _currentUserDue = nd; }); }
    ctrl.dispose();
  }

  void _editDiscount() async {
    final ctrl = TextEditingController(text: _currentDiscountAmount.toStringAsFixed(0));
    final ok = await Get.dialog<bool>(AlertDialog(title: const Text('ডিসকাউন্ট সম্পাদন', style: TextStyle(fontWeight: FontWeight.w800)), content: TextField(controller: ctrl, keyboardType: TextInputType.numberWithOptions(decimal: true), autofocus: true, decoration: InputDecoration(prefixText: '৳ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')), ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('আপডেট'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white))]));
    if (ok == true) { final v = num.tryParse(ctrl.text.trim()) ?? _currentDiscountAmount; await controller.saveDiscountAmount(widget.order.id, v); final nd = (_currentPreviousDue + _savedTotal.toInt() - _currentPaid.toInt() - v.toInt()).clamp(0, 9999999); if (_currentUserId.isNotEmpty) await controller.updateUserDue(_currentUserId, nd); setState(() { _currentDiscountAmount = v; _currentUserDue = nd; }); }
    ctrl.dispose();
  }

  void _editLocalMemo() async {
    final ctrl = TextEditingController(text: _currentLocalMemo);
    final ok = await Get.dialog<bool>(AlertDialog(title: const Text('লোকাল মেমো', style: TextStyle(fontWeight: FontWeight.w800)), content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: 'যেমন: 233', prefixText: '#', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')), ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('সেভ'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white))]));
    if (ok == true) { final val = ctrl.text.trim(); await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'localMemo': val.isNotEmpty ? val : FieldValue.delete()}); setState(() => _currentLocalMemo = val); }
    ctrl.dispose();
  }

  void _editPaymentMethod() async {
    const methods = ['SR হাতে', 'বিকাশ', 'নগদ অ্যাপ', 'রকেট', 'ব্যাংক'];
    final cur = _currentPaymentMethod.isNotEmpty ? _currentPaymentMethod : 'SR হাতে';
    final result = await showModalBottomSheet<String>(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [...methods.map((m) => ListTile(leading: Icon(m == cur ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: m == cur ? const Color(0xFF7C3AED) : Colors.grey), title: Text(m), onTap: () => Navigator.pop(ctx, m))), const SizedBox(height: 8)])));
    if (result != null && result != cur) { await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'paymentMethod': result}); setState(() { _currentPaymentMethod = result; }); }
  }

  Widget _payRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.normal, color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: valueColor)),
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

  void _editDispatchedAt() async {
    final current = _dispatchedAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final newDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await controller.updateDispatchedAt(widget.order.id, newDate);
    setState(() { _dispatchedAt = newDate; });
  }

  void _editDeliveredAt() async {
    final current = _deliveredAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final newDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await controller.updateDeliveredAt(widget.order.id, newDate);
    setState(() { _deliveredAt = newDate; });
  }

  void _addReplaceFromDetailPage() async {
    String q = '';
    ProductModel? sel;
    String res = 'replace_given';
    final dedC = TextEditingController();
    int qty = 1;

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, sheetSt) {
        final displayed = q.isEmpty ? _allProducts : _allProducts.where((p) => p.name.toLowerCase().contains(q) || p.brandName.toLowerCase().contains(q) || p.productCode.toLowerCase().contains(q)).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.96,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
                Expanded(child: Text('রিপ্লেস প্রডাক্ট যোগ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (sel != null) TextButton.icon(onPressed: () => sheetSt(() { sel = null; res = 'replace_given'; qty = 1; dedC.clear(); }), icon: const Icon(Icons.arrow_back_rounded, size: 16), label: const Text('তালিকায় ফিরুন', style: TextStyle(fontSize: 12)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact)),
              ])),
              const SizedBox(height: 10),
              if (sel == null) ...[
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => sheetSt(() => q = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'নাম বা কোড দিয়ে খুঁজুন...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14)))),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(child: _loadingProducts ? const Center(child: CircularProgressIndicator()) : displayed.isEmpty ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি')) : ListView.separated(controller: scrollCtrl, itemCount: displayed.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
                  final p = displayed[i];
                  return InkWell(onTap: () => sheetSt(() { sel = p; res = 'replace_given'; qty = 1; dedC.text = p.wholesalePrice.toStringAsFixed(0); }), child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: p.images.isNotEmpty ? Image.network(p.images.first, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(46, Theme.of(context).colorScheme)) : _imgPlaceholder(46, Theme.of(context).colorScheme)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('৳${_fmt.format(p.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0891B2))),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ])));
                })),
              ] else ...[
                Expanded(child: SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80))), child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: sel!.images.isNotEmpty ? Image.network(sel!.images.first, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(56, Theme.of(context).colorScheme)) : _imgPlaceholder(56, Theme.of(context).colorScheme)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sel!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('৳${_fmt.format(sel!.wholesalePrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF7C3AED))),
                    ])),
                  ])),
                  const SizedBox(height: 20),
                  Text('পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _qtyBtnPurple(Icons.remove_rounded, () { if (qty > 1) sheetSt(() => qty--); }),
                    const SizedBox(width: 4),
                    Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 4),
                    _qtyBtnPurple(Icons.add_rounded, () => sheetSt(() => qty++)),
                  ]),
                  const SizedBox(height: 20),
                  Text('রিপ্লেস স্ট্যাটাস', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: res,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    items: const [
                      DropdownMenuItem(value: 'replace_given', child: Text('রিপ্লেস দিতে হবে', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'product_replace', child: Text('রিপ্লেস নেওয়া হল', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'money_deduct', child: Text('টাকা কাটা', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => sheetSt(() { res = v!; if (res == 'money_deduct') dedC.text = sel!.wholesalePrice.toStringAsFixed(0); }),
                  ),
                  if (res == 'money_deduct') ...[
                    const SizedBox(height: 16),
                    Text('টাকার পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    TextField(controller: dedC, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: '৳ ', hintText: 'টাকার পরিমাণ লিখুন', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_currentUserId.isEmpty) {
                        Get.snackbar('ত্রুটি', 'আগে ক্রেতা নির্বাচন করুন', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                        return;
                      }
                      final ded = res == 'money_deduct' ? (int.tryParse(dedC.text.trim()) ?? sel!.wholesalePrice.toInt()) : 0;
                      final replaceItem = {'productId': sel!.id, 'productName': sel!.name, 'quantity': qty, 'resolutionType': res, 'deductionAmount': ded * qty};
                      try {
                        if (res == 'replace_given' || res == 'product_replace') {
                          await FirebaseFirestore.instance.collection('products').doc(sel!.id).update({'stock': FieldValue.increment(-qty)});
                          try { Get.find<ProductController>().fetchProducts(forceRefresh: true); } catch (_) {}
                        }
                        if (res != 'replace_given') {
                          AdminReplaceController rc;
                          try { rc = Get.find<AdminReplaceController>(); } catch (_) { rc = Get.put(AdminReplaceController()); }
                          await rc.addCustomerIn(productId: sel!.id, productName: sel!.name, quantity: qty, customerId: _currentUserId, customerName: _currentShopName, customerPhone: _currentShopPhone, customerAddress: _currentShopAddress, customerResolutionType: res, deductionAmount: ded * qty, note: 'অর্ডার #${widget.order.id} — রিপ্লেস', date: DateTime.now());
                          await rc.fetchEntries(force: true);
                        }
                        final newList = [..._currentReplaceItems, replaceItem];
                        await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'replaceItems': newList});
                        setState(() => _currentReplaceItems = newList);
                        Navigator.pop(ctx);
                        Get.snackbar('সফল', 'রিপ্লেস প্রডাক্ট যোগ হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
                      } catch (e) {
                        Get.snackbar('ত্রুটি', 'যোগ হয়নি: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                      }
                    },
                    icon: const Icon(Icons.add_rounded), label: const Text('যোগ করুন'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                  const SizedBox(height: 16),
                ]))),
              ],
            ]),
          ),
        );
      }),
    );
    dedC.dispose();
  }

  void _changeCustomer() async {
    String q = '';
    List<Map<String, dynamic>> users = [];
    bool loading = true;

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, sheetSt) {
        if (loading) {
          FirebaseFirestore.instance.collection('users').orderBy('shopName').limit(200).get().then((snap) {
            sheetSt(() {
              users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
              loading = false;
            });
          });
        }
        final filtered = q.isEmpty ? users : users.where((u) {
          final name = (u['shopName'] ?? '').toString().toLowerCase();
          final phone = (u['phone'] ?? '').toString().toLowerCase();
          return name.contains(q) || phone.contains(q);
        }).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ক্রেতা পরিবর্তন', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(onChanged: (v) => sheetSt(() => q = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'নাম বা ফোন দিয়ে খুঁজুন...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14)))),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty ? const Center(child: Text('কোনো ক্রেতা পাওয়া যায়নি')) : ListView.separated(controller: scrollCtrl, itemCount: filtered.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
                final u = filtered[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFF2563EB).withAlpha(20), child: Text((u['shopName'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700))),
                  title: Text(u['shopName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${u['proprietorName'] ?? ''} • ${u['phone'] ?? ''}${(u['address'] ?? '').toString().isNotEmpty ? '\n${u['address']}' : ''}', style: const TextStyle(fontSize: 11)),
                  onTap: () async {
                    final orderId = widget.order.id;
                    final newUserId = u['id'] as String;
                    final newShopName = u['shopName'] ?? '';
                    final newShopPhone = u['phone'] ?? '';
                      final newShopAddress = u['address'] ?? '';
                      final newDue = (u['due'] as num?)?.toInt() ?? 0;
                      try {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                          'userId': newUserId,
                          'shopName': newShopName,
                          'phone': newShopPhone,
                          'shopAddress': newShopAddress,
                          'previousDue': newDue,
                        });
                        setState(() {
                          _currentUserId = newUserId;
                          _currentShopName = newShopName;
                          _currentShopPhone = newShopPhone;
                          _currentShopAddress = newShopAddress;
                          _currentPreviousDue = newDue;
                          _currentUserDue = newDue;
                        });
                      Navigator.pop(ctx);
                      Get.snackbar('সফল', 'ক্রেতা পরিবর্তন হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
                    } catch (e) {
                      Get.snackbar('ত্রুটি', 'ক্রেতা পরিবর্তন হয়নি', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
                    }
                  },
                );
              })),
            ]),
          ),
        );
      }),
    );
  }

  String _statusLabel(String s) => {
        'pending': 'Pending',
        'approved': 'Approved',
        'dispatched': 'Dispatched',
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
      case 'dispatched':
        return const Color(0xFFD97706);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}

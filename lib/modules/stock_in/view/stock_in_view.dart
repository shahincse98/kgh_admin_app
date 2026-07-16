import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/stock_in_controller.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';
import '../../../routes/app_routes.dart';

class StockInView extends StatefulWidget {
  const StockInView({super.key});

  @override
  State<StockInView> createState() => _StockInViewState();
}

class _StockInViewState extends State<StockInView> {
  final controller = Get.find<StockInController>();
  final pc = Get.find<ProductController>();

  final _dateCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##,##0');

  DateTime _selectedDate = DateTime.now();
  final _selectedItems = <_CartItem>[].obs;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd MMM yyyy').format(_selectedDate);
    if (pc.products.isEmpty) pc.fetchProducts();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _sourceCtrl.dispose();
    _noteCtrl.dispose();
    for (final item in _selectedItems) {
      item.dispose();
    }
    super.dispose();
  }

  int get _totalQty => _selectedItems.fold(0, (s, i) => s + i.quantity);
  num get _totalValue => _selectedItems.fold(0, (s, i) => s + i.totalPrice);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('স্টক ইন', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.stockInHistory),
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
              _dateSourceCard(scheme),
              const SizedBox(height: 14),
              _productsCard(scheme),
              const SizedBox(height: 20),
              _submitButton(scheme),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: const Color(0xFF16A34A).withAlpha(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFF16A34A).withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'প্রডাক্ট স্টক ইন করার ফর্ম। তারিখ, সোর্স ও একাধিক প্রডাক্ট সিলেক্ট করুন।',
                style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSourceCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('তারিখ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _dateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('সোর্স (কোথা থেকে)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _sourceCtrl,
                        decoration: InputDecoration(
                          hintText: 'যেমন: ঢাকা, চট্টগ্রাম',
                          prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('নোট (ঐচ্ছিক)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'কোনো নোট থাকলে লিখুন',
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('প্রডাক্ট সিলেক্ট করুন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                Obx(() => _selectedItems.isEmpty
                    ? const SizedBox.shrink()
                    : Text('${_selectedItems.length} টি | $_totalQty pcs | ৳${_fmt.format(_totalValue.toInt())}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (_selectedItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('কোনো প্রডাক্ট যোগ করা হয়নি',
                        style: TextStyle(color: scheme.onSurface.withAlpha(100), fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: _selectedItems.asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withAlpha(120),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: image, name, delete
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                item.image,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e1, e2) => Container(
                                  width: 40, height: 40,
                                  color: scheme.surfaceContainerHighest,
                                  child: const Icon(Icons.image_not_supported_rounded, size: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('স্টক: ${item.stock}', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              color: Colors.red.shade400,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                item.dispose();
                                _selectedItems.removeAt(idx);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 2: qty stepper, price field, line total
                        Row(
                          children: [
                            // Qty stepper
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyBtn(Icons.remove_rounded, () {
                                  if (item.quantity > 1) {
                                    item.quantity--;
                                    _selectedItems.refresh();
                                  } else {
                                    item.dispose();
                                    _selectedItems.removeAt(idx);
                                  }
                                }),
                                SizedBox(
                                  width: 42,
                                  child: TextField(
                                    controller: TextEditingController(text: '${item.quantity}'),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      final q = int.tryParse(v);
                                      if (q != null && q > 0) {
                                        item.quantity = q;
                                        _selectedItems.refresh();
                                      }
                                    },
                                  ),
                                ),
                                _qtyBtn(Icons.add_rounded, () {
                                  item.quantity++;
                                  _selectedItems.refresh();
                                }),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // Price field
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: item.priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  prefixText: '৳',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (v) {
                                  final p = num.tryParse(v);
                                  if (p != null && p >= 0) {
                                    item.unitPrice = p;
                                    _selectedItems.refresh();
                                  }
                                },
                              ),
                            ),
                            const Spacer(),
                            // Line total
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('মোট', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  '৳${_fmt.format(item.totalPrice.toInt())}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showProductPicker(scheme),
                icon: const Icon(Icons.add_rounded),
                label: const Text('প্রডাক্ট যোগ করুন'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF16A34A).withAlpha(80)),
          color: const Color(0xFF16A34A).withAlpha(14),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
      ),
    );
  }

  void _showProductPicker(ColorScheme scheme) {
    String query = '';
    final allProducts = List<ProductModel>.from(pc.products)..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displayed = query.isEmpty
              ? allProducts
              : allProducts.where((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.brandName.toLowerCase().contains(query) ||
                  p.productCode.toLowerCase().contains(query)).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('প্রডাক্ট বেছে নিন',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setSheetState(() => query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'নাম বা কোড দিয়ে খুঁজুন…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: displayed.isEmpty
                        ? const Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = displayed[i];
                              final already = _selectedItems.any((e) => e.id == p.id);
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.images.isNotEmpty
                                      ? Image.network(p.images.first, width: 42, height: 42, fit: BoxFit.cover,
                                          errorBuilder: (_, e1, e2) => Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16)))
                                      : Container(width: 42, height: 42, color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_rounded, size: 16)),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                subtitle: Text('স্টক: ${p.stock} | ৳${_fmt.format(p.wholesalePrice)}',
                                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                                trailing: already
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A))
                                    : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                                onTap: () {
                                  if (!already) {
                                    _selectedItems.add(_CartItem(
                                      id: p.id,
                                      name: p.name,
                                      image: p.images.isNotEmpty ? p.images.first : '',
                                      stock: p.stock,
                                      quantity: 1,
                                      unitPrice: p.purchasePrice,
                                    ));
                                  }
                                  Get.back();
                                },
                              );
                            },
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

  Widget _submitButton(ColorScheme scheme) {
    return Obx(() {
      final canSubmit = _selectedItems.isNotEmpty && !_submitting;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canSubmit ? _submit : null,
          icon: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded),
          label: Text(_submitting ? 'সাবমিট হচ্ছে…' : 'স্টক ইন করুন ($_totalQty pcs | ৳${_fmt.format(_totalValue.toInt())})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: scheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      Get.snackbar('ত্রুটি', 'অন্তত একটি প্রডাক্ট সিলেক্ট করতে হবে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _submitting = true);

    try {
      await controller.addMultipleStockIn(
        date: _selectedDate,
        source: _sourceCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        items: _selectedItems.map((i) => {
          'productId': i.id,
          'productName': i.name,
          'image': i.image,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
        }).toList(),
      );

      Get.snackbar('সফল', '${_selectedItems.length} টি প্রডাক্ট, $_totalQty pcs | ৳${_fmt.format(_totalValue.toInt())} স্টক ইন হয়েছে',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);

      for (final item in _selectedItems) {
        item.dispose();
      }
      _selectedItems.clear();
      _noteCtrl.clear();
    } catch (e) {
      Get.snackbar('ত্রুটি', 'স্টক ইন ব্যর্থ হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }

    setState(() => _submitting = false);
  }
}

class _CartItem {
  final String id;
  final String name;
  final String image;
  final int stock;
  int quantity;
  num unitPrice;
  late final TextEditingController priceCtrl;

  _CartItem({required this.id, required this.name, required this.image, required this.stock, required this.quantity, required this.unitPrice}) {
    priceCtrl = TextEditingController(text: unitPrice.toStringAsFixed(0));
  }

  num get totalPrice => quantity * unitPrice;

  void dispose() {
    priceCtrl.dispose();
  }
}

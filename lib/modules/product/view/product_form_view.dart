import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';

/// Full-screen form for adding or editing a product.
/// Pass [product] for edit mode; omit (null) for add mode.
class ProductFormView extends StatefulWidget {
  final ProductModel? product;
  const ProductFormView({super.key, this.product});

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  late final ProductController _ctrl;

  // ── Basic text controllers ───────────────────────────────────────────────
  late final TextEditingController _name;
  late final TextEditingController _cat;
  late final TextEditingController _brand;
  late final TextEditingController _code;
  late final TextEditingController _model;
  late final TextEditingController _unit;
  late final TextEditingController _warranty;
  late final TextEditingController _video;

  // ── Pricing / stock ─────────────────────────────────────────────────────
  late final TextEditingController _buyPrice;
  late final TextEditingController _wholesale;
  late final TextEditingController _retail;
  late final TextEditingController _stock;

  // ── Lists (mutable) ─────────────────────────────────────────────────────
  late List<String> _images;
  late List<String> _details;

  // ── Toggles ─────────────────────────────────────────────────────────────
  late bool _isAvailable;
  late bool _isHot;
  late bool _isNew;

  // ── Add-item controllers ─────────────────────────────────────────────────
  final _imgInput = TextEditingController();
  final _detailInput = TextEditingController();

  final _saving = false.obs;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ProductController>();
    final p = widget.product;

    _name = TextEditingController(text: p?.name ?? '');
    _cat = TextEditingController(text: p?.productCategory ?? '');
    _brand = TextEditingController(text: p?.brandName ?? '');
    _code = TextEditingController(text: p?.productCode ?? '');
    _model = TextEditingController(text: p?.productModel ?? '');
    _unit = TextEditingController(text: p?.unit ?? '');
    _warranty = TextEditingController(text: p?.warranty ?? '');
    _video = TextEditingController(text: p?.productVideo ?? '');
    _buyPrice =
        TextEditingController(text: (p?.purchasePrice ?? 0).toString());
    _wholesale =
        TextEditingController(text: (p?.wholesalePrice ?? 0).toString());
    _retail =
        TextEditingController(text: (p?.retailPrice ?? 0).toString());
    _stock = TextEditingController(text: (p?.stock ?? 0).toString());

    _images = List<String>.from(p?.images ?? []);
    _details = List<String>.from(p?.productDetails ?? []);

    _isAvailable = p?.isAvailable ?? true;
    _isHot = p?.isHot ?? false;
    _isNew = p?.isNew ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _cat, _brand, _code, _model, _unit, _warranty, _video,
      _buyPrice, _wholesale, _retail, _stock, _imgInput, _detailInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? widget.product!.name : 'নতুন Product যোগ করুন',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400),
              tooltip: 'Delete product',
              onPressed: _confirmDelete,
            ),
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  icon: _saving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Save'),
                  onPressed: _saving.value ? null : _save,
                ),
              )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── মৌলিক তথ্য ─────────────────────────────────────────────
            _sectionHeader('মৌলিক তথ্য', cs),
            _tf(_name, 'Product Name *'),
            _tf(_cat, 'Category *'),
            _tf(_brand, 'Brand'),
            _tf(_code, 'Product Code'),
            _tf(_model, 'Model'),

            // ── মূল্য ──────────────────────────────────────────────────
            _sectionHeader('মূল্য', cs),
            Row(children: [
              Expanded(child: _tf(_buyPrice, 'ক্রয় মূল্য', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _tf(_wholesale, 'পাইকারি', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _tf(_retail, 'খুচরা', number: true)),
            ]),

            // ── স্টক ───────────────────────────────────────────────────
            _sectionHeader('স্টক ও বিবরণ', cs),
            Row(children: [
              Expanded(child: _tf(_stock, 'Stock', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _tf(_unit, 'Unit (pcs/box/set)')),
              const SizedBox(width: 10),
              Expanded(child: _tf(_warranty, 'Warranty')),
            ]),

            // ── লেবেল ──────────────────────────────────────────────────
            _sectionHeader('লেবেল', cs),
            _switchRow('Available (বিক্রয়যোগ্য)', _isAvailable,
                (v) => setState(() => _isAvailable = v), cs),
            _switchRow('Hot (🔥 Featured)', _isHot,
                (v) => setState(() => _isHot = v), cs),
            _switchRow('New (✨ New Arrival)', _isNew,
                (v) => setState(() => _isNew = v), cs),

            // ── ছবি ─────────────────────────────────────────────────────
            _sectionHeader('ছবি (Image URLs)', cs),
            _imageSection(cs),

            // ── Product Details ─────────────────────────────────────────
            _sectionHeader('Product Details / বৈশিষ্ট্য', cs),
            _detailsSection(cs),

            // ── Video Link ──────────────────────────────────────────────
            _sectionHeader('Video Link', cs),
            _tf(_video, 'YouTube / অন্য video URL'),

            // ── Delete (edit only) ──────────────────────────────────────
            if (_isEdit) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400),
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Product ডিলেট করুন'),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: cs.primary),
      ),
    );
  }

  // ── Text field ───────────────────────────────────────────────────────────

  Widget _tf(TextEditingController c, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Switch row ───────────────────────────────────────────────────────────

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChange,
      ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        value: value,
        onChanged: onChange,
      ),
    );
  }

  // ── Image section ────────────────────────────────────────────────────────

  Widget _imageSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._images.asMap().entries.map((e) => _imageRow(e.key, e.value, cs)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _imgInput,
                decoration: InputDecoration(
                  hintText: 'Image URL paste করুন...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addImage,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14)),
              child: const Text('যোগ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imageRow(int index, String url, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              bottomLeft: Radius.circular(9),
            ),
            child: Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_rounded, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(url,
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade400, size: 20),
            tooltip: 'Remove image',
            onPressed: () => setState(() => _images.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _addImage() {
    final url = _imgInput.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _images.add(url);
      _imgInput.clear();
    });
  }

  // ── Product details section ──────────────────────────────────────────────

  Widget _detailsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._details.asMap().entries
            .map((e) => _detailRow(e.key, e.value, cs)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _detailInput,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'যেমন: Color: Black, Power: 20W...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addDetail,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14)),
              child: const Text('যোগ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(int index, String detail, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, size: 7, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
              child: Text(detail, style: const TextStyle(fontSize: 13))),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: Colors.red.shade400, size: 18),
            onPressed: () => setState(() => _details.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _addDetail() {
    final text = _detailInput.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _details.add(text);
      _detailInput.clear();
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _cat.text.trim().isEmpty) {
      Get.snackbar('ত্রুটি', 'Name ও Category আবশ্যক',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    _saving.value = true;
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'productCategory': _cat.text.trim(),
        'brandName': _brand.text.trim(),
        'productCode': _code.text.trim(),
        'productModel': _model.text.trim(),
        'unit': _unit.text.trim(),
        'warranty': _warranty.text.trim(),
        'productVideo': _video.text.trim(),
        'purchasePrice': int.tryParse(_buyPrice.text) ?? 0,
        'wholesalePrice': int.tryParse(_wholesale.text) ?? 0,
        'retailPrice': int.tryParse(_retail.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 0,
        'images': _images,
        'productDetails': _details,
        'isAvailable': _isAvailable,
        'isHot': _isHot,
        'isNew': _isNew,
      };

      if (_isEdit) {
        await _ctrl.updateProduct(widget.product!.id, data);
        Get.back();
        Get.snackbar(
          'সেভ হয়েছে',
          '${_name.text.trim()} আপডেট হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        await _ctrl.addProduct({
          ...data,
          'isInternal': false,
          'pendingStock': 0,
          'totalSold': 0,
          'totalOrders': 0,
          'monthlySold': 0,
          'replaceCount': 0,
          'quantityDiscount': {},
        });
        Get.back();
        Get.snackbar(
          'সফল',
          '${_name.text.trim()} যোগ হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } finally {
      _saving.value = false;
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        title: const Text('Product ডিলেট করবেন?'),
        content:
            Text('"${widget.product!.name}" স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await _ctrl.deleteProduct(widget.product!.id);
              Get.back(); // close form
              Get.snackbar(
                'ডিলেট হয়েছে',
                '"${widget.product!.name}" মুছে ফেলা হয়েছে',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.shade700,
                colorText: Colors.white,
              );
            },
            child: const Text('ডিলেট করুন',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../../../widgets/responsive.dart';

/// Stock list for the SR: how many of each product are in stock, with the
/// selling price. Purchase price is never shown here.
class SrStockView extends StatefulWidget {
  const SrStockView({super.key});

  @override
  State<SrStockView> createState() => _SrStockViewState();
}

class _SrStockViewState extends State<SrStockView> {
  static const _lowStock = 5;
  final _fmt = NumberFormat('#,##,##0');
  final _searchCtrl = TextEditingController();
  late final ProductController _pc;
  String _query = '';
  String _filter = 'all'; // all | in | low | out

  @override
  void initState() {
    super.initState();
    _pc = Get.find<ProductController>();
    if (_pc.products.isEmpty) _pc.fetchProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> _visible(List<ProductModel> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((p) {
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.brandName.toLowerCase().contains(q) &&
          !p.productCode.toLowerCase().contains(q) &&
          !p.productModel.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case 'in':
          return p.stock > 0;
        case 'low':
          return p.stock > 0 && p.stock <= _lowStock;
        case 'out':
          return p.stock <= 0;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Color _stockColor(int stock) {
    if (stock <= 0) return const Color(0xFFDC2626);
    if (stock <= _lowStock) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('স্টক'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ'.tr,
            onPressed: () => _pc.fetchProducts(forceRefresh: true),
          ),
        ],
      ),
      body: ResponsiveWrapper(child: Obx(() {
        final all = _pc.products.toList();
        final visible = _visible(all);
        final inStock = all.where((p) => p.stock > 0).length;
        final low = all.where((p) => p.stock > 0 && p.stock <= _lowStock).length;
        final out = all.where((p) => p.stock <= 0).length;

        return RefreshIndicator(
          onRefresh: () => _pc.fetchProducts(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'নাম, ব্র্যান্ড বা কোড দিয়ে খুঁজুন'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                        ),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _filterChip('all', '${'সব'.tr} (${all.length})', scheme.primary),
                _filterChip('in', '${'স্টকে আছে'.tr} ($inStock)', const Color(0xFF16A34A)),
                _filterChip('low', '${'কম স্টক'.tr} ($low)', const Color(0xFFD97706)),
                _filterChip('out', '${'স্টক শেষ'.tr} ($out)', const Color(0xFFDC2626)),
              ]),
              const SizedBox(height: 12),
              if (_pc.loading.value && all.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Text('কোনো প্রডাক্ট পাওয়া যায়নি'.tr, style: const TextStyle(color: Colors.grey))),
                )
              else
                ...visible.map((p) => _productTile(p, scheme)),
            ],
          ),
        );
      })),
    );
  }

  Widget _filterChip(String key, String label, Color color) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : color)),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withAlpha(18),
      side: BorderSide(color: color.withAlpha(80)),
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _productTile(ProductModel p, ColorScheme scheme) {
    final color = _stockColor(p.stock);
    final sub = [
      if (p.brandName.isNotEmpty) p.brandName,
      if (p.productCode.isNotEmpty) p.productCode,
    ].join(' • ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.images.isNotEmpty
                ? Image.network(p.images.first, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(scheme))
                : _placeholder(scheme),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (sub.isNotEmpty)
                Text(sub, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(140))),
              const SizedBox(height: 2),
              Text('${'বিক্রয় মূল্য'.tr}: ৳${_fmt.format(p.wholesalePrice.round())}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0891B2))),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(p.stock == 0 ? 'শেষ'.tr : '${p.stock}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              Text(p.unit.isNotEmpty ? p.unit : 'পিস'.tr, style: TextStyle(fontSize: 10, color: color)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        width: 48,
        height: 48,
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.inventory_2_rounded, size: 20, color: Colors.grey),
      );
}

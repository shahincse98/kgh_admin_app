import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';

// ── Visit status helpers ─────────────────────────────────────────────────────

const _poVisitStatuses = [
  ('pending', 'অপেক্ষারত', Icons.hourglass_empty_rounded),
  ('visited', 'ভিজিট সম্পন্ন', Icons.check_circle_rounded),
  ('ordered', 'অর্ডার সম্পন্ন', Icons.shopping_bag_rounded),
  ('order_later', 'অর্ডার পরে দিবে', Icons.schedule_rounded),
  ('shop_closed', 'দোকান বন্ধ', Icons.store_mall_directory_outlined),
  ('no_order', 'অর্ডার দিবেনা', Icons.remove_shopping_cart_rounded),
];

Color _poVisitColor(String s) {
  switch (s) {
    case 'visited': return const Color(0xFF16A34A);
    case 'ordered': return const Color(0xFF7C3AED);
    case 'order_later': return const Color(0xFFF59E0B);
    case 'shop_closed': return const Color(0xFF64748B);
    case 'no_order': return const Color(0xFFDC2626);
    default: return const Color(0xFF0891B2);
  }
}

String _poVisitLabel(String s) =>
    _poVisitStatuses.firstWhere((e) => e.$1 == s, orElse: () => _poVisitStatuses.first).$2;

IconData _poVisitIcon(String s) =>
    _poVisitStatuses.firstWhere((e) => e.$1 == s, orElse: () => _poVisitStatuses.first).$3;

class SrPlaceOrderView extends StatelessWidget {
  const SrPlaceOrderView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SrPanelController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Obx(() {
          const titles = [
            'কাস্টমার নির্বাচন',
            'পণ্য নির্বাচন',
            'অর্ডার নিশ্চিত করুন',
          ];
          return Text(titles[ctrl.orderStep.value],
              style: const TextStyle(fontWeight: FontWeight.w800));
        }),
        actions: [
          // Cart badge icon — only visible on product step
          Obx(() {
            if (ctrl.orderStep.value != 1) {
              return ctrl.orderStep.value > 0
                  ? TextButton(
                      onPressed: ctrl.resetOrder,
                      child: const Text('বাতিল'),
                    )
                  : const SizedBox();
            }
            final count = ctrl.cartCount;
            return Row(
              children: [
                if (count > 0)
                  TextButton(
                    onPressed: ctrl.resetOrder,
                    child: const Text('বাতিল'),
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'কার্ট',
                      icon: const Icon(Icons.shopping_cart_rounded),
                      onPressed: () => _showCartSheet(context, ctrl, scheme),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: scheme.onError,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            );
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Obx(() => LinearProgressIndicator(
                value: (ctrl.orderStep.value + 1) / 3,
                backgroundColor: scheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              )),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _fab(ctrl, scheme, context),
      body: Obx(() {
        switch (ctrl.orderStep.value) {
          case 0:
            return _CustomerStep(ctrl: ctrl, scheme: scheme);
          case 1:
            return _ProductStep(ctrl: ctrl, scheme: scheme, fmt: _fmt);
          case 2:
            return _ReviewStep(ctrl: ctrl, scheme: scheme, fmt: _fmt);
          default:
            return const SizedBox();
        }
      }),
    );
  }

  Widget _fab(SrPanelController ctrl, ColorScheme scheme, BuildContext context) {
    return Obx(() {
      if (ctrl.orderStep.value != 1) return const SizedBox();
      final count = ctrl.cartCount;
      if (count == 0) return const SizedBox();
      return FloatingActionButton.extended(
        onPressed: () => _showCartSheet(context, ctrl, scheme),
        icon: const Icon(Icons.shopping_cart_rounded),
        label: Text(
          '৳ ${NumberFormat('#,##,##0').format(ctrl.cartTotal)} — কার্ট ($count)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      );
    });
  }

  void _showCartSheet(
      BuildContext context, SrPanelController ctrl, ColorScheme scheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _CartSheet(ctrl: ctrl, scheme: scheme),
    );
  }
}

// ── Cart Bottom Sheet ─────────────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  final SrPanelController ctrl;
  final ColorScheme scheme;

  const _CartSheet({required this.ctrl, required this.scheme});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Text('কার্ট',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Obx(() => Text(
                      '${ctrl.cartCount} টি পণ্য',
                      style: TextStyle(
                          color: scheme.onSurface.withAlpha(160),
                          fontSize: 13),
                    )),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          // Items
          Expanded(
            child: Obx(() {
              if (ctrl.cart.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 56, color: scheme.onSurface.withAlpha(60)),
                      const SizedBox(height: 12),
                      Text('কার্ট খালি',
                          style: TextStyle(color: scheme.onSurface.withAlpha(120))),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: ctrl.cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = ctrl.cart[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.product.images.isNotEmpty
                              ? Image.network(
                                  item.product.images.first,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imgPlaceholder(scheme),
                                )
                              : _imgPlaceholder(scheme),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '৳ ${_fmt.format(item.product.wholesalePrice)} × ${item.quantity} = ৳ ${_fmt.format(item.total)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Qty controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _qtyBtn(
                              icon: Icons.remove_rounded,
                              onTap: () =>
                                  ctrl.updateQty(item.product.id, item.quantity - 1),
                              scheme: scheme,
                              isDestructive: item.quantity == 1,
                            ),
                            Container(
                              width: 36,
                              alignment: Alignment.center,
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: scheme.primary),
                              ),
                            ),
                            _qtyBtn(
                              icon: Icons.add_rounded,
                              onTap: () =>
                                  ctrl.updateQty(item.product.id, item.quantity + 1),
                              scheme: scheme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          // Footer: total + proceed button
          Obx(() {
            if (ctrl.cart.isEmpty) return const SizedBox();
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                    top: BorderSide(color: scheme.outlineVariant, width: 1)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('মোট (${ctrl.cartCount} পণ্য)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        '৳ ${_fmt.format(ctrl.cartTotal)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ctrl.orderStep.value = 2;
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('অর্ডার কনফার্মে যান',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(ColorScheme scheme) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_rounded,
            color: scheme.onSurface.withAlpha(80), size: 22),
      );

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDestructive
              ? scheme.errorContainer
              : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: isDestructive
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer),
      ),
    );
  }
}

// ── Step 1: Customer ──────────────────────────────────────────────────────────

class _CustomerStep extends StatefulWidget {
  final SrPanelController ctrl;
  final ColorScheme scheme;

  const _CustomerStep({required this.ctrl, required this.scheme});

  @override
  State<_CustomerStep> createState() => _CustomerStepState();
}

class _CustomerStepState extends State<_CustomerStep> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(UserModel u, String q) =>
      q.isEmpty ||
      u.shopName.toLowerCase().contains(q) ||
      u.proprietorName.toLowerCase().contains(q) ||
      u.phone.contains(q);

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final ctrl = widget.ctrl;
    final scheme = widget.scheme;

    return Obx(() {
      final q = _query;
      final assignedIds = ctrl.assignedShops.map((u) => u.id).toSet();
      final callIds = ctrl.callContacts.map((u) => u.id).toSet();

      // Assigned shops (নির্ধারিত দোকান)
      final assigned = ctrl.assignedShops
          .where((u) => _matches(u, q))
          .toList();

      // Call contacts not already in assigned
      final calls = ctrl.callContacts
          .where((u) => !assignedIds.contains(u.id) && _matches(u, q))
          .toList();

      // All other users
      final others = userCtrl.users
          .where((u) =>
              !assignedIds.contains(u.id) &&
              !callIds.contains(u.id) &&
              _matches(u, q))
          .toList();

      // Build a flat list of sections for ListView
      final List<_ShopListItem> items = [];
      if (assigned.isNotEmpty) {
        items.add(_ShopListItem.header('নির্ধারিত দোকান', assigned.length));
        for (final u in assigned) {
          items.add(_ShopListItem.shop(u, isAssigned: true));
        }
      }
      if (calls.isNotEmpty) {
        items.add(_ShopListItem.header('কল পরিচিতি', calls.length));
        for (final u in calls) {
          items.add(_ShopListItem.shop(u, isAssigned: false));
        }
      }
      // Show 'অন্যান্য দোকান' header only when there are also assigned/call shops
      final hasGrouped = assigned.isNotEmpty || calls.isNotEmpty;
      if (others.isNotEmpty) {
        if (hasGrouped) {
          items.add(_ShopListItem.header('অন্যান্য দোকান', others.length));
        }
        for (final u in others) {
          items.add(_ShopListItem.shop(u, isAssigned: false));
        }
      }

      return Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'নাম / ফোন দিয়ে খুঁজুন…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
              ),
            ),
          ),
          if (userCtrl.loading.value)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded,
                        size: 56, color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('কোনো কাস্টমার পাওয়া যায়নি',
                        style: TextStyle(
                            color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                itemCount: items.length + (assigned.isEmpty && calls.isEmpty ? 1 : 0),
                itemBuilder: (_, i) {
                  // Show "no assigned shops" notice at top
                  if (assigned.isEmpty && calls.isEmpty && i == 0) {
                    return Container(
                      margin: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: scheme.primary.withAlpha(60), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: scheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'এই SR-এর কোনো নির্ধারিত দোকান নেই। Admin থেকে দোকান নির্ধারিত করলে এখানে আলাদা সেকশনে দেখাবে।',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final idx = (assigned.isEmpty && calls.isEmpty) ? i - 1 : i;
                  final item = items[idx];
                  if (item.isHeader) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                      child: Row(
                        children: [
                          if (item.isAssigned) ...[
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.assignment_turned_in_rounded,
                                  size: 14, color: scheme.primary),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(item.headerLabel!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: item.isAssigned
                                      ? scheme.primary
                                      : scheme.onSurface.withAlpha(160))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isAssigned
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${item.headerCount}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: item.isAssigned
                                        ? scheme.primary
                                        : scheme.onSurface.withAlpha(140))),
                          ),
                        ],
                      ),
                    );
                  }
                  final u = item.user!;
                  final selected =
                      ctrl.selectedCustomer.value?.id == u.id;
                  final isAssigned = item.isAssigned;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : isAssigned
                                ? scheme.primaryContainer.withAlpha(60)
                                : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: selected
                            ? Border.all(color: scheme.primary, width: 2)
                            : isAssigned
                                ? Border.all(
                                    color: scheme.primary.withAlpha(60),
                                    width: 1)
                                : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        onTap: () {
                          ctrl.selectedCustomer.value = u;
                          ctrl.orderStep.value = 1;
                        },
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: selected
                              ? scheme.primary
                              : isAssigned
                                  ? scheme.primary.withAlpha(40)
                                  : scheme.secondaryContainer,
                          child: Icon(Icons.store_rounded,
                              color: selected
                                  ? scheme.onPrimary
                                  : isAssigned
                                      ? scheme.primary
                                      : scheme.onSecondaryContainer),
                        ),
                        title: Text(
                            u.shopName.isNotEmpty
                                ? u.shopName
                                : u.proprietorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${u.proprietorName}  •  ${u.phone}',
                                  style: const TextStyle(fontSize: 12)),
                              if (u.address.isNotEmpty) ...[  
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 11,
                                        color: scheme.onSurface.withAlpha(130)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(u.address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: scheme.onSurface
                                                  .withAlpha(150))),
                                    ),
                                  ],
                                ),
                              ],
                              if (isAssigned) ...() {
                                final vs = ctrl.visitLogs[u.id];
                                if (vs == null ||
                                    vs.isEmpty ||
                                    vs == 'pending') return <Widget>[];
                                final c = _poVisitColor(vs);
                                return [
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.withAlpha(22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: c.withAlpha(80), width: 1),
                                    ),
                                    child: Text(_poVisitLabel(vs),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: c)),
                                  ),
                                ];
                              }(),
                              if (u.deliveryDay.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withAlpha(18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(u.deliveryDay,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle_rounded,
                                color: scheme.primary)
                            : const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

// Helper for grouped list items
class _ShopListItem {
  final bool isHeader;
  final bool isAssigned;
  final String? headerLabel;
  final int headerCount;
  final UserModel? user;

  const _ShopListItem._({
    required this.isHeader,
    required this.isAssigned,
    this.headerLabel,
    this.headerCount = 0,
    this.user,
  });

  factory _ShopListItem.header(String label, int count,
          {bool assigned = false}) =>
      _ShopListItem._(
          isHeader: true,
          isAssigned: label == 'নির্ধারিত দোকান',
          headerLabel: label,
          headerCount: count);

  factory _ShopListItem.shop(UserModel u, {required bool isAssigned}) =>
      _ShopListItem._(isHeader: false, isAssigned: isAssigned, user: u);
}

// ── Step 2: Products ──────────────────────────────────────────────────────────

class _ProductStep extends StatefulWidget {
  final SrPanelController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ProductStep(
      {required this.ctrl, required this.scheme, required this.fmt});

  @override
  State<_ProductStep> createState() => _ProductStepState();
}

class _ProductStepState extends State<_ProductStep> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'all';

  void _showVisitPicker(BuildContext context, String shopId) {
    final ctrl = widget.ctrl;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ভিজিট স্ট্যাটাস',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ..._poVisitStatuses.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _poVisitColor(s.$1).withAlpha(30),
                      child:
                          Icon(s.$3, color: _poVisitColor(s.$1), size: 20),
                    ),
                    title: Text(s.$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await ctrl.setVisitStatus(shopId, s.$1);
                    },
                  )),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<ProductController>();
    final ctrl = widget.ctrl;
    final scheme = widget.scheme;
    final fmt = widget.fmt;

    return Column(
      children: [
        // ── Customer bar ───────────────────────────────────────────
        Obx(() {
          final cust = ctrl.selectedCustomer.value;
          if (cust == null) return const SizedBox();
          final isAssigned =
              ctrl.assignedShops.any((s) => s.id == cust.id);
          final vstatus =
              isAssigned ? ctrl.visitLogs[cust.id] : null;
          final hasVStatus = vstatus != null &&
              vstatus.isNotEmpty &&
              vstatus != 'pending';
          return Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_pin_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cust.shopName.isNotEmpty
                                ? cust.shopName
                                : cust.proprietorName,
                            style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                          if (cust.phone.isNotEmpty)
                            Text(cust.phone,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onPrimaryContainer
                                        .withAlpha(180))),
                          if (cust.address.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 11,
                                    color: scheme.onPrimaryContainer
                                        .withAlpha(160)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    cust.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onPrimaryContainer
                                            .withAlpha(170)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => ctrl.orderStep.value = 0,
                      child: const Text('পরিবর্তন'),
                    ),
                  ],
                ),
                if (isAssigned) ...[  
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showVisitPicker(context, cust.id),
                    child: hasVStatus
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _poVisitColor(vstatus!)
                                      .withAlpha(22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _poVisitColor(vstatus)
                                          .withAlpha(90)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_poVisitIcon(vstatus),
                                        size: 12,
                                        color: _poVisitColor(vstatus)),
                                    const SizedBox(width: 5),
                                    Text(_poVisitLabel(vstatus),
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                _poVisitColor(vstatus))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit_rounded,
                                  size: 12,
                                  color:
                                      scheme.primary.withAlpha(160)),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(Icons.add_task_rounded,
                                  size: 13,
                                  color:
                                      scheme.primary.withAlpha(200)),
                              const SizedBox(width: 4),
                              Text('ভিজিট স্ট্যাটাস দিন',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          );
        }),
        // ── Search ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) =>
                setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'পণ্যের নাম বা কোড দিয়ে খুঁজুন…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
            ),
          ),
        ),
        // ── Category chips ────────────────────────────────────────
        Obx(() {
          final categories = ['all'] +
              pc.products
                  .where((p) => p.isAvailable && p.stock > 0)
                  .map((p) => p.productCategory)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          return SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final selected = _category == cat;
                final color = selected
                    ? scheme.primary
                    : scheme.surfaceContainerHigh;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? null
                          : Border.all(
                              color: scheme.outlineVariant, width: 1),
                    ),
                    child: Text(
                      cat == 'all' ? 'সব পণ্য' : cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 4),
        // ── Product grid ──────────────────────────────────────────
        Expanded(
          child: Obx(() {
            final allProducts = pc.products
                .where((p) => p.isAvailable && p.stock > 0)
                .where((p) =>
                    _category == 'all' ||
                    p.productCategory == _category)
                .where((p) =>
                    _query.isEmpty ||
                    p.name.toLowerCase().contains(_query) ||
                    p.productCode.toLowerCase().contains(_query))
                .toList();

            if (pc.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (allProducts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56,
                        color: scheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('কোনো পণ্য পাওয়া যায়নি',
                        style: TextStyle(
                            color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding:
                  const EdgeInsets.fromLTRB(12, 6, 12, 120),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: allProducts.length,
              itemBuilder: (_, i) => _ProductCard(
                product: allProducts[i],
                ctrl: ctrl,
                scheme: scheme,
                fmt: fmt,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final SrPanelController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ProductCard({
    required this.product,
    required this.ctrl,
    required this.scheme,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final idx =
          ctrl.cart.indexWhere((c) => c.product.id == product.id);
      final inCart = idx != -1;
      final qty = inCart ? ctrl.cart[idx].quantity : 0;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: inCart
              ? scheme.secondaryContainer.withAlpha(140)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: inCart
              ? Border.all(
                  color: scheme.secondary.withAlpha(200), width: 1.5)
              : Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(scheme),
                          )
                        : _placeholder(scheme),
                    if (inCart)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$qty',
                            style: TextStyle(
                                color: scheme.onSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    if (product.isHot)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Hot',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '৳ ${fmt.format(product.wholesalePrice)}',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                    Text(
                      'স্টক: ${product.stock} ${product.unit}',
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withAlpha(140)),
                    ),
                  ],
                ),
              ),
              // Add / Qty control
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: inCart
                    ? Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _qtyBtn(
                            icon: qty == 1
                                ? Icons.delete_outline_rounded
                                : Icons.remove_rounded,
                            onTap: () =>
                                ctrl.updateQty(product.id, qty - 1),
                            scheme: scheme,
                            isDestructive: qty == 1,
                          ),
                          GestureDetector(
                            onTap: () => _editQty(context, ctrl, scheme),
                            child: Text(
                              '$qty',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: scheme.primary),
                            ),
                          ),
                          _qtyBtn(
                            icon: Icons.add_rounded,
                            onTap: () =>
                                ctrl.updateQty(product.id, qty + 1),
                            scheme: scheme,
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => ctrl.addToCart(product),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('যোগ করুন',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _editQty(
      BuildContext context, SrPanelController ctrl, ColorScheme scheme) {
    final idx = ctrl.cart.indexWhere((c) => c.product.id == product.id);
    if (idx == -1) return;
    final currentQty = ctrl.cart[idx].quantity;
    final controller =
        TextEditingController(text: '$currentQty');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(product.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'পরিমাণ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text.trim()) ?? 0;
              ctrl.updateQty(product.id, qty);
              Navigator.pop(context);
            },
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.inventory_2_rounded,
            color: scheme.onSurface.withAlpha(80), size: 28),
      );

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDestructive
              ? scheme.errorContainer
              : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: isDestructive
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer),
      ),
    );
  }
}

// ── Step 3: Review ────────────────────────────────────────────────────────────

class _ReviewStep extends StatefulWidget {
  final SrPanelController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ReviewStep(
      {required this.ctrl, required this.scheme, required this.fmt});

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  final _paidCtrl = TextEditingController();
  DateTime? _scheduledDate;
  final _dateFmt = DateFormat('dd MMMM yyyy');

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final scheme = widget.scheme;
    final fmt = widget.fmt;

    return Obx(() {
      final cust = ctrl.selectedCustomer.value;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer
            _sectionLabel('কাস্টমার', scheme),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.store_rounded,
                      color: scheme.onPrimaryContainer),
                ),
                title: Text(
                    cust?.shopName.isNotEmpty == true
                        ? cust!.shopName
                        : cust?.proprietorName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${cust?.proprietorName ?? ''}  •  ${cust?.phone ?? ''}'),
                trailing: TextButton(
                  onPressed: () => ctrl.orderStep.value = 0,
                  child: const Text('পরিবর্তন'),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('পণ্য তালিকা', scheme),
                TextButton.icon(
                  onPressed: () => ctrl.orderStep.value = 1,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('সম্পাদনা'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ctrl.cart.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: scheme.outlineVariant),
                itemBuilder: (_, i) {
                  final c = ctrl.cart[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: c.product.images.isNotEmpty
                          ? Image.network(c.product.images.first,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color: scheme.surfaceContainerHighest,
                                    child: const Icon(
                                        Icons.inventory_2_rounded,
                                        size: 18),
                                  ))
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  size: 18),
                            ),
                    ),
                    title: Text(c.product.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '৳ ${fmt.format(c.product.wholesalePrice)} × ${c.quantity}'),
                    trailing: Text('৳ ${fmt.format(c.total)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            fontSize: 14)),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Scheduled delivery date (optional)
            _sectionLabel('নির্ধারিত ডেলিভারি তারিখ (ঐচ্ছিক)', scheme),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _scheduledDate != null
                            ? const Color(0xFF0891B2).withAlpha(20)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_rounded,
                          color: _scheduledDate != null
                              ? const Color(0xFF0891B2)
                              : scheme.onSurface.withAlpha(120),
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scheduledDate != null
                                ? _dateFmt.format(_scheduledDate!)
                                : 'তারিখ নির্ধারিত নেই',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _scheduledDate != null
                                    ? const Color(0xFF0891B2)
                                    : scheme.onSurface.withAlpha(160)),
                          ),
                        ],
                      ),
                    ),
                    if (_scheduledDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: Colors.red.shade400,
                        tooltip: 'তারিখ মুছুন',
                        onPressed: () =>
                            setState(() => _scheduledDate = null),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _scheduledDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _scheduledDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded,
                          size: 16),
                      label: Text(
                          _scheduledDate != null ? 'পরিবর্তন' : 'তারিখ দিন'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Payment
            _sectionLabel('পেমেন্ট', scheme),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('মোট',
                            style: TextStyle(fontSize: 15)),
                        Text('৳ ${fmt.format(ctrl.cartTotal)}',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _paidCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'নগদ প্রদান (ঐচ্ছিক)',
                        prefixText: '৳ ',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (ctrl.orderError.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(ctrl.orderError.value,
                            style: TextStyle(
                                color: scheme.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ctrl.submitting.value
                    ? null
                    : () async {
                        final paid =
                            num.tryParse(_paidCtrl.text.trim()) ?? 0;
                        final ok = await ctrl.submitOrder(paid,
                            scheduledDate: _scheduledDate);
                        if (ok) {
                          Get.snackbar(
                            'সফল!',
                            'অর্ডার সফলভাবে তৈরি হয়েছে',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                          );
                        }
                      },
                icon: ctrl.submitting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(ctrl.submitting.value
                    ? 'সাবমিট হচ্ছে…'
                    : 'অর্ডার কনফার্ম করুন'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _sectionLabel(String label, ColorScheme scheme) {
    return Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withAlpha(160)));
  }
}

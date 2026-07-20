import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../product/controller/product_controller.dart';
import '../../product/model/product_model.dart';
import '../controller/create_order_controller.dart';
import '../controller/order_controller.dart';
import '../../../widgets/responsive.dart';

class CreateOrderView extends StatelessWidget {
  const CreateOrderView({super.key});

  static final _fmt = NumberFormat('#,##,##0');

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CreateOrderController());
    final scheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        ctrl.reset();
        return true;
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Obx(() {
            const titles = [
              'কাস্টমার নির্বাচন করুন',
              'পণ্য যোগ করুন',
              'অর্ডার নিশ্চিত করুন',
            ];
            return Text(
              titles[ctrl.currentStep.value],
              style: const TextStyle(fontWeight: FontWeight.w800),
            );
          }),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ctrl.reset();
              Get.back();
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Obx(() => LinearProgressIndicator(
                  value: (ctrl.currentStep.value + 1) / 3,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(scheme.primary),
                )),
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
        floatingActionButton: CreateOrderFab(ctrl: ctrl),
        body: ResponsiveWrapper(child: Obx(() {
          switch (ctrl.currentStep.value) {
            case 0:
              return _CustomerStep(ctrl: ctrl, scheme: scheme, fmt: _fmt);
            case 1:
              return _ProductStep(ctrl: ctrl, scheme: scheme, fmt: _fmt);
            case 2:
              return _ReviewStep(ctrl: ctrl, scheme: scheme, fmt: _fmt);
            default:
              return const SizedBox();
          }
        })),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Customer Selection
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerStep extends StatelessWidget {
  final CreateOrderController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _CustomerStep(
      {required this.ctrl, required this.scheme, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final uc = Get.find<UserController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: TextField(
            onChanged: (v) => ctrl.customerSearch.value = v,
            decoration: InputDecoration(
              hintText: 'Shop নাম, মালিক বা ফোন দিয়ে খুঁজুন…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final q = ctrl.customerSearch.value.trim().toLowerCase();
            final users = q.isEmpty
                ? uc.users
                : uc.users.where((u) {
                    return u.shopName.toLowerCase().contains(q) ||
                        u.proprietorName.toLowerCase().contains(q) ||
                        u.phone.contains(q);
                  }).toList();

            if (uc.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (users.isEmpty) {
              return Center(
                child: Text('কোনো কাস্টমার পাওয়া যায়নি',
                    style: TextStyle(
                        color: scheme.onSurface.withAlpha(120))),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final user = users[i];
                return Obx(() {
                  final selected =
                      ctrl.selectedCustomer.value?.id == user.id;
                  return _CustomerTile(
                    user: user,
                    selected: selected,
                    scheme: scheme,
                    onTap: () {
                      ctrl.selectedCustomer.value = user;
                      ctrl.currentStep.value = 1;
                    },
                  );
                });
              },
            );
          }),
        ),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.user,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? Border.all(color: scheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              selected ? scheme.primary : scheme.secondaryContainer,
          child: Icon(Icons.store_rounded,
              color:
                  selected ? scheme.onPrimary : scheme.onSecondaryContainer),
        ),
        title: Text(
          user.shopName.isNotEmpty ? user.shopName : user.proprietorName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${user.proprietorName}  •  ${user.phone}',
          style: TextStyle(
              color: scheme.onSurface.withAlpha(160), fontSize: 12),
        ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — Product Selection
// ─────────────────────────────────────────────────────────────────────────────

class _ProductStep extends StatelessWidget {
  final CreateOrderController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ProductStep(
      {required this.ctrl, required this.scheme, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<ProductController>();

    return Column(
      children: [
        // Selected customer info bar
        Obx(() {
          final cust = ctrl.selectedCustomer.value;
          if (cust == null) return const SizedBox();
          return Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.person_pin_rounded,
                    color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'কাস্টমার: ${cust.shopName.isNotEmpty ? cust.shopName : cust.proprietorName}',
                    style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => ctrl.currentStep.value = 0,
                  child: const Text('পরিবর্তন'),
                )
              ],
            ),
          );
        }),

        // Due collection toggle
        Obx(() {
          final cust = ctrl.selectedCustomer.value;
          if (cust == null) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ctrl.isDueCollection.value = false,
                    icon: Icon(Icons.shopping_cart_rounded, size: 16, color: !ctrl.isDueCollection.value ? scheme.primary : scheme.onSurfaceVariant),
                    label: Text('পণ্য যোগ', style: TextStyle(fontSize: 12, color: !ctrl.isDueCollection.value ? scheme.primary : scheme.onSurfaceVariant)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: !ctrl.isDueCollection.value ? scheme.primary : scheme.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ctrl.isDueCollection.value = true,
                    icon: Icon(Icons.account_balance_wallet_rounded, size: 16, color: ctrl.isDueCollection.value ? const Color(0xFF16A34A) : scheme.onSurfaceVariant),
                    label: Text('বাকি জমা', style: TextStyle(fontSize: 12, color: ctrl.isDueCollection.value ? const Color(0xFF16A34A) : scheme.onSurfaceVariant)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: ctrl.isDueCollection.value ? const Color(0xFF16A34A) : scheme.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Search bar or Due collection form
        Obx(() {
          if (ctrl.isDueCollection.value) {
            // ── Due Collection Form ──
            return Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withAlpha(12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF16A34A).withAlpha(40)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 20),
                            const SizedBox(width: 8),
                            const Text('বাকি জমা', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                          ]),
                          const SizedBox(height: 6),
                          Obx(() {
                            final cust = ctrl.selectedCustomer.value;
                            final due = cust?.totalDue ?? 0;
                            return Text('বর্তমান বাকি: ৳${fmt.format(due)}', style: TextStyle(fontSize: 13, color: due > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A), fontWeight: FontWeight.w600));
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('জমা পরিমাণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl.dueCollectionAmountCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        hintText: 'টাকার পরিমাণ লিখুন',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('পেমেন্ট মাধ্যম', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Obx(() {
                      return DropdownButtonFormField<String>(
                        value: ctrl.dueCollectionMethod.value,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'SR হাতে', child: Text('SR হাতে', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'বিকাশ', child: Text('বিকাশ', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'রকেট', child: Text('রকেট', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'নগদ', child: Text('নগদ', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'ব্যাংক', child: Text('ব্যাংক', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (v) { if (v != null) ctrl.dueCollectionMethod.value = v; },
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text('তারিখ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Obx(() {
                      return InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: ctrl.dueCollectionDate.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) ctrl.dueCollectionDate.value = picked;
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Text(DateFormat('dd/MM/yyyy').format(ctrl.dueCollectionDate.value), style: const TextStyle(fontSize: 14)),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurfaceVariant),
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    // Submit button
                    Obx(() {
                      final cust = ctrl.selectedCustomer.value;
                      final due = cust?.totalDue ?? 0;
                      final amount = num.tryParse(ctrl.dueCollectionAmountCtrl.text.trim()) ?? 0;
                      final canSubmit = amount > 0 && amount <= due;
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: ctrl.submitting.value || !canSubmit ? null : () async {
                                final success = await ctrl.submitOrder();
                                if (success) {
                                  Get.find<OrderController>().fetchOrders();
                                  ctrl.reset();
                                  Get.back();
                                  Get.snackbar('সফল', 'বাকি জমা হয়েছে', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF16A34A), colorText: Colors.white);
                                }
                              },
                              icon: ctrl.submitting.value
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_rounded),
                              label: Text(ctrl.submitting.value ? 'সাবমিট হচ্ছে…' : 'বাকি জমা করুন'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (amount > due && due > 0) ...[
                            const SizedBox(height: 8),
                            Text('বাকির চেয়ে বেশি টাকা দেওয়া যাবে না', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          }

          // ── Normal Product Selection ──
          return Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: TextField(
                    onChanged: (v) => ctrl.productSearch.value = v,
                    decoration: InputDecoration(
                      hintText: 'পণ্যের নাম বা কোড দিয়ে খুঁজুন…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final q = ctrl.productSearch.value.trim().toLowerCase();
                    final products = q.isEmpty
                        ? pc.products
                            .where((p) => p.isAvailable && p.stock > 0)
                            .toList()
                        : pc.products
                            .where((p) =>
                                p.isAvailable &&
                                p.stock > 0 &&
                                (p.name.toLowerCase().contains(q) ||
                                    p.productCode.toLowerCase().contains(q)))
                            .toList();

                    if (pc.loading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (products.isEmpty) {
                      return Center(
                        child: Text('কোনো পণ্য পাওয়া যায়নি',
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(120))),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _ProductTile(
                              product: products[i],
                              ctrl: ctrl,
                              scheme: scheme,
                              fmt: fmt),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final CreateOrderController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ProductTile({
    required this.product,
    required this.ctrl,
    required this.scheme,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cartIdx =
          ctrl.cart.indexWhere((c) => c.product.id == product.id);
      final inCart = cartIdx != -1;
      final qty = inCart ? ctrl.cart[cartIdx].quantity : 0;

      return Container(
        decoration: BoxDecoration(
          color: inCart
              ? scheme.secondaryContainer.withAlpha(120)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: inCart
              ? Border.all(
                  color: scheme.secondary.withAlpha(160), width: 1.5)
              : null,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.images.isNotEmpty
                ? Image.network(
                    product.images.first,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderIcon(scheme),
                  )
                : _placeholderIcon(scheme),
          ),
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '৳ ${fmt.format(product.wholesalePrice)}  •  Stock: ${product.stock}',
                style: TextStyle(
                    color: scheme.onSurface.withAlpha(160), fontSize: 12),
              ),
            ],
          ),
          trailing: inCart
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(
                      icon: Icons.remove_rounded,
                      onTap: () =>
                          ctrl.updateQuantity(product.id, qty - 1),
                      scheme: scheme,
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$qty',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: scheme.primary),
                      ),
                    ),
                    _qtyBtn(
                      icon: Icons.add_rounded,
                      onTap: () =>
                          ctrl.updateQuantity(product.id, qty + 1),
                      scheme: scheme,
                    ),
                  ],
                )
              : IconButton(
                  onPressed: () => ctrl.addToCart(product),
                  icon: Icon(Icons.add_shopping_cart_rounded,
                      color: scheme.primary),
                  tooltip: 'কার্টে যোগ করুন',
                ),
        ),
      );
    });
  }

  Widget _placeholderIcon(ColorScheme scheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2_rounded,
          color: scheme.onSurface.withAlpha(80), size: 24),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Review & Confirm
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  final CreateOrderController ctrl;
  final ColorScheme scheme;
  final NumberFormat fmt;

  const _ReviewStep(
      {required this.ctrl, required this.scheme, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cust = ctrl.selectedCustomer.value;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Customer card ────────────────────────────────────────────────

            _sectionTitle('কাস্টমার তথ্য', scheme),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.store_rounded,
                      color: scheme.onPrimaryContainer),
                ),
                title: Text(
                  cust?.shopName.isNotEmpty == true
                      ? cust!.shopName
                      : cust?.proprietorName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                    '${cust?.proprietorName ?? ''}  •  ${cust?.phone ?? ''}'),
                trailing: TextButton(
                  onPressed: () => ctrl.currentStep.value = 0,
                  child: const Text('পরিবর্তন'),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Order items ──────────────────────────────────────────────────

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('পণ্যের তালিকা', scheme),
                TextButton.icon(
                  onPressed: () => ctrl.currentStep.value = 1,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('সম্পাদনা'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ctrl.cart.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: scheme.outlineVariant),
                itemBuilder: (_, i) {
                  final item = ctrl.cart[i];
                  return ListTile(
                    dense: true,
                    title: Text(item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '৳ ${fmt.format(item.product.wholesalePrice)} × ${item.quantity}'),
                    trailing: Text(
                      '৳ ${fmt.format(item.total)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // ── Payment ──────────────────────────────────────────────────────

            _sectionTitle('পেমেন্ট', scheme),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('মোট পরিমাণ',
                            style: TextStyle(fontSize: 15)),
                        Text(
                          '৳ ${fmt.format(ctrl.cartTotal)}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl.paidAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'নগদ প্রদান (ঐচ্ছিক)',
                        prefixText: '৳ ',
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
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

            const SizedBox(height: 8),

            // ── Error message ────────────────────────────────────────────────

            if (ctrl.error.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(ctrl.error.value,
                    style: TextStyle(color: scheme.error)),
              ),

            const SizedBox(height: 24),

            // ── Submit button ────────────────────────────────────────────────

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ctrl.submitting.value
                    ? null
                    : () async {
                        final ok = await ctrl.submitOrder();
                        if (ok) {
                          // Refresh orders list
                          try {
                            final oc = Get.find<OrderController>();
                            oc.lastDoc = null;
                            oc.hasMore.value = true;
                            await oc.fetchOrders();
                          } catch (_) {}
                          ctrl.reset();
                          Get.back();
                          Get.snackbar(
                            'সফল!',
                            'অর্ডার সফলভাবে তৈরি হয়েছে',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                          );
                        }
                      },
                icon: ctrl.submitting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
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

  Widget _sectionTitle(String title, ColorScheme scheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface.withAlpha(160),
        letterSpacing: 0.4,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB cart badge shown in Step 2
// ─────────────────────────────────────────────────────────────────────────────

class CreateOrderFab extends StatelessWidget {
  final CreateOrderController ctrl;

  const CreateOrderFab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.currentStep.value != 1 || ctrl.isDueCollection.value) return const SizedBox();
      final count = ctrl.cartCount;
      final total = ctrl.cartTotal;
      final fmt = NumberFormat('#,##,##0');
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: count == 0
              ? null
              : () => ctrl.currentStep.value = 2,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_checkout_rounded),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          label: Text(
            count == 0 ? 'কোনো পণ্য নেই' : '৳ ${fmt.format(total)} — পরবর্তী',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: count == 0
              ? Colors.grey
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    });
  }
}

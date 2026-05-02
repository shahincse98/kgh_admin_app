import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../user/model/user_model.dart';
import '../../product/model/product_model.dart';
import '../model/order_model.dart';

/// Represents a single item in the SR/admin created cart
class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  num get total => product.wholesalePrice * quantity;
}

class CreateOrderController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // ── Stepper state ───────────────────────────────────────────────────────────
  final currentStep = 0.obs; // 0=customer, 1=products, 2=review

  // ── Step 1: Customer selection ──────────────────────────────────────────────
  final Rxn<UserModel> selectedCustomer = Rxn<UserModel>();
  final customerSearch = ''.obs;

  // ── Step 2: Product / cart ──────────────────────────────────────────────────
  final productSearch = ''.obs;
  final cart = <CartItem>[].obs;

  // ── Step 3: Review / payment ────────────────────────────────────────────────
  final paidAmountCtrl = TextEditingController();

  // ── Submission state ────────────────────────────────────────────────────────
  final submitting = false.obs;
  final error = ''.obs;

  @override
  void onClose() {
    paidAmountCtrl.dispose();
    super.onClose();
  }

  // ── Cart helpers ────────────────────────────────────────────────────────────

  void addToCart(ProductModel product) {
    final idx = cart.indexWhere((c) => c.product.id == product.id);
    if (idx != -1) {
      cart[idx].quantity += 1;
      cart.refresh();
    } else {
      cart.add(CartItem(product: product, quantity: 1));
    }
  }

  void removeFromCart(String productId) {
    cart.removeWhere((c) => c.product.id == productId);
  }

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) {
      removeFromCart(productId);
      return;
    }
    final idx = cart.indexWhere((c) => c.product.id == productId);
    if (idx != -1) {
      cart[idx].quantity = qty;
      cart.refresh();
    }
  }

  num get cartTotal =>
      cart.fold<num>(0, (sum, c) => sum + c.total);

  int get cartCount =>
      cart.fold<int>(0, (sum, c) => sum + c.quantity);

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<bool> submitOrder() async {
    final customer = selectedCustomer.value;
    if (customer == null) {
      error.value = 'কাস্টমার নির্বাচন করুন';
      return false;
    }
    if (cart.isEmpty) {
      error.value = 'কমপক্ষে একটি পণ্য যোগ করুন';
      return false;
    }

    submitting.value = true;
    error.value = '';

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final orderedBy = currentUser?.uid ?? '';
      final orderedByEmail = currentUser?.email ?? '';

      final paid =
          num.tryParse(paidAmountCtrl.text.trim()) ?? 0;

      final items = cart
          .map((c) => OrderItem(
                productId: c.product.id,
                productName: c.product.name,
                image: c.product.images.isNotEmpty
                    ? c.product.images.first
                    : '',
                quantity: c.quantity,
                pricePerUnit: c.product.wholesalePrice,
                totalPrice: c.total,
              ).toMap())
          .toList();

      await _db.collection('orders').add({
        'userId': customer.id,
        'shopName': customer.shopName,
        'shopAddress': customer.address,
        'shopPhone': customer.phone,
        'items': items,
        'totalAmount': cartTotal,
        'paidAmount': paid,
        'status': 'pending',
        'orderedBy': orderedBy,
        'orderedByEmail': orderedByEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      error.value = 'অর্ডার সাবমিট করতে ব্যর্থ: $e';
      return false;
    } finally {
      submitting.value = false;
    }
  }

  // ── Reset for reuse ─────────────────────────────────────────────────────────

  void reset() {
    currentStep.value = 0;
    selectedCustomer.value = null;
    customerSearch.value = '';
    productSearch.value = '';
    cart.clear();
    paidAmountCtrl.clear();
    error.value = '';
  }
}

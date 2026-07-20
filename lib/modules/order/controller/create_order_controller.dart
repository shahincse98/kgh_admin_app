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

  // ── Due collection mode ────────────────────────────────────────────────────
  final isDueCollection = false.obs;
  final dueCollectionAmountCtrl = TextEditingController();
  final dueCollectionMethod = 'SR হাতে'.obs;
  final dueCollectionDate = DateTime.now().obs;

  // ── Submission state ────────────────────────────────────────────────────────
  final submitting = false.obs;
  final error = ''.obs;

  @override
  void onClose() {
    paidAmountCtrl.dispose();
    dueCollectionAmountCtrl.dispose();
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

    // Due collection mode
    if (isDueCollection.value) {
      final dueAmount = num.tryParse(dueCollectionAmountCtrl.text.trim()) ?? 0;
      if (dueAmount <= 0) {
        error.value = 'জমা পরিমাণ লিখুন';
        return false;
      }

      submitting.value = true;
      error.value = '';

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final orderedBy = currentUser?.uid ?? '';
        final orderedByEmail = currentUser?.email ?? '';

        await _db.collection('orders').add({
          'userId': customer.id,
          'shopName': customer.shopName,
          'shopAddress': customer.address,
          'shopPhone': customer.phone,
          'userPhone': customer.phone,
          'userDue': customer.totalDue,
          'items': <Map<String, dynamic>>[],
          'totalAmount': 0,
          'paidAmount': dueAmount,
          'status': 'delivered',
          'isDueCollection': true,
          'paymentMethod': dueCollectionMethod.value,
          'payments': [{'amount': dueAmount, 'method': dueCollectionMethod.value}],
          'deliveredAt': Timestamp.fromDate(dueCollectionDate.value),
          'orderedBy': orderedBy,
          'orderedByEmail': orderedByEmail,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update user's due
        final newDue = (customer.totalDue - dueAmount.toInt()).clamp(0, 9999999);
        await _db.collection('users').doc(customer.id).update({'totalDue': newDue});

        return true;
      } catch (e) {
        error.value = 'সাবমিট করতে ব্যর্থ: $e';
        return false;
      } finally {
        submitting.value = false;
      }
    }

    // Normal order mode
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
                purchasePrice: c.product.purchasePrice,
              ).toMap())
          .toList();

      await _db.collection('orders').add({
        'userId': customer.id,
        'shopName': customer.shopName,
        'shopAddress': customer.address,
        'shopPhone': customer.phone,
        'userPhone': customer.phone,
        'userDue': customer.totalDue,
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
    isDueCollection.value = false;
    dueCollectionAmountCtrl.clear();
    dueCollectionMethod.value = 'SR হাতে';
    dueCollectionDate.value = DateTime.now();
  }
}

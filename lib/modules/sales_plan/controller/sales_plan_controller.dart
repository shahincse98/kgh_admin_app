import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../model/sales_plan_model.dart';

class SrEntry {
  final String id;
  final String name;
  const SrEntry({required this.id, required this.name});
}

class SalesPlanController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // ── Month navigation ─────────────────────────────────────────────────────
  final selectedMonth = DateTime(
          DateTime.now().year, DateTime.now().month)
      .obs;

  // ── Loaded plan for the selected month ───────────────────────────────────
  final planItems = <CustomerPlanItem>[].obs;
  final planLoading = false.obs;

  // ── Actuals: userId -> totalAmount delivered this month ──────────────────
  final actuals = <String, double>{}.obs;
  final actualsLoading = false.obs;

  // ── SR list for form picker ──────────────────────────────────────────────
  final srLoading = false.obs;
  final srList = <SrEntry>[].obs;

  // ── Available months (current + next 5 + past 6) ─────────────────────────
  List<DateTime> get months {
    final now = DateTime.now();
    return List.generate(12, (i) => DateTime(now.year, now.month + 2 - i));
  }

  String get _monthKey {
    final m = selectedMonth.value;
    return '${m.year}-${m.month.toString().padLeft(2, '0')}';
  }

  @override
  void onInit() {
    super.onInit();
    fetchPlan();
    _loadSrList();
  }

  void selectMonth(DateTime m) {
    selectedMonth.value = m;
    fetchPlan();
  }

  // ── Load SR list ─────────────────────────────────────────────────────────

  Future<void> _loadSrList() async {
    srLoading.value = true;
    try {
      final snap = await _db.collection('sr_staff').get();
      srList.assignAll(snap.docs.map((doc) {
        final data = doc.data();
        return SrEntry(
          id: doc.id,
          name: (data['name'] ?? '').toString(),
        );
      }).toList());
    } catch (_) {
      srList.clear();
    } finally {
      srLoading.value = false;
    }
  }

  // ── Load plan ─────────────────────────────────────────────────────────────

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    fetchPlan();
  }

  void nextMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month + 1);
    fetchPlan();
  }

  Future<void> fetchPlan() async {
    planLoading.value = true;
    actuals.clear();
    try {
      final doc = await _db
          .collection('customer_sales_plans')
          .doc(_monthKey)
          .get();
      if (doc.exists) {
        final plan = CustomerSalesPlan.fromFirestore(doc);
        planItems.assignAll(plan.items);
      } else {
        planItems.clear();
      }
      await _loadActuals();
    } catch (e) {
      planItems.clear();
      Get.snackbar(
        'ত্রুটি',
        'ডেটা লোড হয়নি। পুনরায় চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } finally {
      planLoading.value = false;
    }
  }

  // ── Load actuals from delivered orders ───────────────────────────────────

  Future<void> _loadActuals() async {
    actualsLoading.value = true;
    try {
      final m = selectedMonth.value;
      final start = DateTime(m.year, m.month);
      final end = DateTime(m.year, m.month + 1);

      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();

      final result = <String, double>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = (data['userId'] ?? data['uid'] ?? '').toString();
        final phone = (data['shopPhone'] ?? data['phone'] ?? '').toString();
        final amount =
            (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final key = uid.isNotEmpty ? uid : phone;
        if (key.isNotEmpty) {
          result[key] = (result[key] ?? 0) + amount;
        }
      }
      actuals.assignAll(result);
    } catch (_) {
      // Silently ignore actuals error (e.g. index not yet built)
      actuals.clear();
    } finally {
      actualsLoading.value = false;
    }
  }

  /// Public wrapper for detail view to reload actuals.
  Future<Map<String, double>> loadActuals(SalesPlanModel plan) async {
    await _loadActuals();
    return Map.from(actuals);
  }

  /// Clears the cached actuals (triggers refresh on next load).
  void clearActualsCache(String planId) {
    actuals.clear();
  }

  /// Returns the actual amount for a plan item.
  double actualFor(CustomerPlanItem item) {
    if (item.userId.isNotEmpty && actuals.containsKey(item.userId)) {
      return actuals[item.userId]!;
    }
    // fallback: match by phone
    if (item.phone.isNotEmpty && actuals.containsKey(item.phone)) {
      return actuals[item.phone]!;
    }
    return 0;
  }

  // ── Save full plan ────────────────────────────────────────────────────────

  Future<void> savePlan([SalesPlanModel? plan]) async {
    if (plan != null) {
      await _db
          .collection('customer_sales_plans')
          .doc(plan.id.isEmpty ? plan.period : plan.id)
          .set(plan.toFirestore());
    } else {
      final p = CustomerSalesPlan(
        month: _monthKey,
        items: List.from(planItems),
      );
      await _db
          .collection('customer_sales_plans')
          .doc(_monthKey)
          .set(p.toFirestore());
    }
  }

  // ── Delete plan ───────────────────────────────────────────────────────────

  Future<void> deletePlan(String planId) async {
    if (planId.isEmpty) return;
    await _db.collection('customer_sales_plans').doc(planId).delete();
  }

  // ── Add / update item ─────────────────────────────────────────────────────

  Future<void> upsertItem(CustomerPlanItem item) async {
    final idx = planItems.indexWhere((i) => i.userId == item.userId);
    if (idx >= 0) {
      planItems[idx] = item;
    } else {
      planItems.add(item);
    }
    await savePlan();
  }

  Future<void> removeItem(String userId) async {
    planItems.removeWhere((i) => i.userId == userId);
    await savePlan();
  }

  Future<void> refreshActuals() async {
    await _loadActuals();
  }
}

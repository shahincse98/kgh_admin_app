import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';

class SrDueView extends StatefulWidget {
  const SrDueView({super.key});

  @override
  State<SrDueView> createState() => _SrDueViewState();
}

class _SrDueViewState extends State<SrDueView> {
  static final _fmt = NumberFormat('#,##,##0');
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SrPanelController>();
    final userCtrl = Get.find<UserController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('কাস্টমার বাকি',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: () {
              userCtrl.fetchUsers();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (userCtrl.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = ctrl.srProfile.value;
        final dueLimit = (profile?.dueLimit ?? 0).toDouble();

        // All users with dues
        final allWithDue = _query.isEmpty
            ? userCtrl.users.where((u) => u.totalDue > 0).toList()
            : userCtrl.users
                .where((u) =>
                    u.totalDue > 0 &&
                    (u.shopName.toLowerCase().contains(_query) ||
                        u.proprietorName.toLowerCase().contains(_query) ||
                        u.phone.contains(_query)))
                .toList();

        allWithDue.sort((a, b) => b.totalDue.compareTo(a.totalDue));

        final totalDue =
            userCtrl.users.fold<num>(0, (s, u) => s + u.totalDue);
        final overLimit =
            (totalDue - dueLimit).clamp(0, double.infinity);
        final isFrozen = dueLimit > 0 && overLimit > 0;

        // Progress ratio (0–1) — how full the limit is
        final ratio = dueLimit > 0
            ? (totalDue / dueLimit).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          children: [
            // ── Summary header ──────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isFrozen
                    ? scheme.errorContainer
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _summaryTile(
                          'মোট বাকি',
                          '৳ ${_fmt.format(totalDue)}',
                          isFrozen
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer),
                      _summaryTile(
                          'বাকি সীমা',
                          dueLimit > 0
                              ? '৳ ${_fmt.format(dueLimit)}'
                              : 'সীমা নেই',
                          isFrozen
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer),
                      _summaryTile(
                          'গ্রাহক সংখ্যা',
                          '${allWithDue.length} জন',
                          isFrozen
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer),
                    ],
                  ),
                  if (dueLimit > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: isFrozen
                            ? scheme.onErrorContainer.withAlpha(30)
                            : scheme.onPrimaryContainer.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFrozen
                              ? scheme.error
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFrozen
                          ? 'সীমা অতিক্রম! অতিরিক্ত: ৳ ${_fmt.format(overLimit)} — বেতন আটকে আছে'
                          : 'সীমার ${(ratio * 100).toStringAsFixed(0)}% ব্যবহার হয়েছে',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isFrozen
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer.withAlpha(200),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
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
                      vertical: 10, horizontal: 16),
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

            // ── Customer list ────────────────────────────────
            Expanded(
              child: allWithDue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 56,
                              color: scheme.onSurface.withAlpha(60)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'কোনো বাকি নেই'
                                : 'কোনো ফলাফল পাওয়া যায়নি',
                            style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurface.withAlpha(120)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: allWithDue.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = allWithDue[i];
                        final isHigh = dueLimit > 0 &&
                            u.totalDue >
                                (dueLimit /
                                    allWithDue.length.clamp(1, 9999));
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          color: isHigh
                              ? scheme.errorContainer.withAlpha(60)
                              : scheme.surfaceContainerHigh,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isHigh
                                  ? scheme.errorContainer
                                  : scheme.secondaryContainer,
                              child: Icon(Icons.store_rounded,
                                  color: isHigh
                                      ? scheme.onErrorContainer
                                      : scheme.onSecondaryContainer),
                            ),
                            title: Text(
                              u.shopName.isNotEmpty
                                  ? u.shopName
                                  : u.proprietorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${u.proprietorName}  •  ${u.phone}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '৳ ${_fmt.format(u.totalDue)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isHigh
                                          ? scheme.error
                                          : scheme.primary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

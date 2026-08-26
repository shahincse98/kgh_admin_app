import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/sr_panel_controller.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';
import '../../../widgets/responsive.dart';

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
      body: ResponsiveWrapper(child: Obx(() {
        if (userCtrl.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

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

        return Column(
          children: [
            // ── Summary header ──────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryTile(
                      'মোট বাকি',
                      '৳ ${_fmt.format(totalDue)}',
                      scheme.onPrimaryContainer),
                  _summaryTile(
                      'গ্রাহক সংখ্যা',
                      '${allWithDue.length} জন',
                      scheme.onPrimaryContainer),
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
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          color: scheme.surfaceContainerHigh,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(Icons.store_rounded,
                                  color: scheme.onSecondaryContainer),
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
                            trailing: Text(
                              '৳ ${_fmt.format(u.totalDue)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: scheme.primary),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      })),
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

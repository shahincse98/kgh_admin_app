import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/sr_panel_controller.dart';
import '../../user/controller/user_controller.dart';
import '../../user/model/user_model.dart';

// Visit status options
const _visitStatuses = [
  ('pending', 'অপেক্ষারত', Icons.hourglass_empty_rounded),
  ('visited', 'ভিজিট সম্পন্ন', Icons.check_circle_rounded),
  ('ordered', 'অর্ডার সম্পন্ন', Icons.shopping_bag_rounded),
  ('order_later', 'অর্ডার পরে দিবে', Icons.schedule_rounded),
  ('shop_closed', 'দোকান বন্ধ', Icons.store_mall_directory_outlined),
  ('no_order', 'অর্ডার দিবেনা', Icons.remove_shopping_cart_rounded),
];

Color _visitColor(String status) {
  switch (status) {
    case 'visited':
      return const Color(0xFF16A34A);
    case 'ordered':
      return const Color(0xFF7C3AED);
    case 'order_later':
      return const Color(0xFFF59E0B);
    case 'shop_closed':
      return const Color(0xFF64748B);
    case 'no_order':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF0891B2);
  }
}

class SrMyCustomersView extends StatelessWidget {
  const SrMyCustomersView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SrPanelController>();
    final userCtrl = Get.find<UserController>();
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('ইউজার তালিকা',
              style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'সকল ইউজার'),
              Tab(text: 'নির্ধারিত দোকান'),
              Tab(text: 'কল তালিকা'),
            ],
          ),
        ),
        body: Obx(() {
          if (userCtrl.loading.value || ctrl.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            children: [
              _SearchableUserList(userCtrl: userCtrl, scheme: scheme),
              _AssignedShopList(ctrl: ctrl, scheme: scheme),
              _CustomerList(
                users: ctrl.callContacts,
                emptyIcon: Icons.phone_missed_rounded,
                emptyMsg: 'কোনো কল তালিকা নেই',
                scheme: scheme,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Assigned shop list with visit status & remove ───────────────────────────

class _AssignedShopList extends StatelessWidget {
  final SrPanelController ctrl;
  final ColorScheme scheme;

  const _AssignedShopList({required this.ctrl, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shops = ctrl.assignedShops;
      if (shops.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_mall_directory_rounded,
                  size: 56, color: scheme.onSurface.withAlpha(60)),
              const SizedBox(height: 12),
              Text('কোনো দোকান নির্ধারিত নেই',
                  style: TextStyle(color: scheme.onSurface.withAlpha(120))),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () => ctrl.loadVisitLogs(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          itemCount: shops.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _AssignedShopCard(user: shops[i], ctrl: ctrl, scheme: scheme),
        ),
      );
    });
  }
}

class _AssignedShopCard extends StatelessWidget {
  final UserModel user;
  final SrPanelController ctrl;
  final ColorScheme scheme;

  const _AssignedShopCard(
      {required this.user, required this.ctrl, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = ctrl.visitLogs[user.id];
      final hasStatus = status != null && status != 'pending';
      final statusColor = status != null ? _visitColor(status) : null;

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
                  CircleAvatar(
                    backgroundColor: statusColor != null
                        ? statusColor.withAlpha(40)
                        : scheme.primaryContainer,
                    child: Icon(Icons.store_rounded,
                        color: statusColor ?? scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.shopName.isNotEmpty
                              ? user.shopName
                              : user.proprietorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text('${user.proprietorName}  •  ${user.phone}',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withAlpha(160))),
                        if (user.address.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 12,
                                  color: scheme.onSurface.withAlpha(120)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(user.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurface.withAlpha(140))),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'অপশন',
                    onSelected: (val) async {
                      if (val == 'remove') {
                        final ok = await Get.dialog<bool>(AlertDialog(
                          title: const Text('তালিকা থেকে বাদ দিবেন?'),
                          content: Text(
                              '"${user.shopName.isNotEmpty ? user.shopName : user.proprietorName}" ভিজিট তালিকা থেকে বাদ দিতে চান?'),
                          actions: [
                            TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('না')),
                            TextButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('হ্যাঁ',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (ok == true) await ctrl.removeAssignedShop(user.id);
                      } else {
                        await ctrl.setVisitStatus(user.id, val);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'pending',
                        child: Text('— স্ট্যাটাস স্থির করুন —',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                        enabled: false,
                      ),
                      ..._visitStatuses.map((s) => PopupMenuItem(
                            value: s.$1,
                            child: Row(
                              children: [
                                Icon(s.$3, size: 16, color: _visitColor(s.$1)),
                                const SizedBox(width: 8),
                                Text(s.$2),
                              ],
                            ),
                          )),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline_rounded,
                                size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Text('তালিকা থেকে বাদ দিন',
                                style:
                                    TextStyle(color: Colors.red.shade400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasStatus) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor!.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: statusColor.withAlpha(80), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              _visitStatuses
                                  .firstWhere((s) => s.$1 == status,
                                      orElse: () => _visitStatuses.first)
                                  .$3,
                              size: 12,
                              color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                              _visitStatuses
                                  .firstWhere((s) => s.$1 == status,
                                      orElse: () => _visitStatuses.first)
                                  .$2,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('আজকের ভিজিট',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ── Searchable all-users list ────────────────────────────────────────────────

class _SearchableUserList extends StatefulWidget {
  final UserController userCtrl;
  final ColorScheme scheme;

  const _SearchableUserList(
      {required this.userCtrl, required this.scheme});

  @override
  State<_SearchableUserList> createState() => _SearchableUserListState();
}

class _SearchableUserListState extends State<_SearchableUserList> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: TextField(
            controller: _ctrl,
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
                        _ctrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final users = _query.isEmpty
                ? widget.userCtrl.users
                : widget.userCtrl.users
                    .where((u) =>
                        u.shopName.toLowerCase().contains(_query) ||
                        u.proprietorName.toLowerCase().contains(_query) ||
                        u.phone.contains(_query))
                    .toList();

            if (users.isEmpty) {
              return Center(
                child: Text('কোনো ইউজার পাওয়া যায়নি',
                    style: TextStyle(
                        color: scheme.onSurface.withAlpha(120))),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _UserCard(user: users[i], scheme: scheme),
            );
          }),
        ),
      ],
    );
  }
}

class _CustomerList extends StatelessWidget {
  final List<UserModel> users;
  final IconData emptyIcon;
  final String emptyMsg;
  final ColorScheme scheme;

  const _CustomerList({
    required this.users,
    required this.emptyIcon,
    required this.emptyMsg,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon,
                size: 56, color: scheme.onSurface.withAlpha(60)),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: TextStyle(
                    color: scheme.onSurface.withAlpha(120))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _UserCard(user: users[i], scheme: scheme),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final ColorScheme scheme;

  const _UserCard({required this.user, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.store_rounded,
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.shopName.isNotEmpty
                        ? user.shopName
                        : user.proprietorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(user.proprietorName,
                      style: TextStyle(
                          color: scheme.onSurface.withAlpha(160),
                          fontSize: 12)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 13,
                          color: scheme.onSurface.withAlpha(140)),
                      const SizedBox(width: 4),
                      Text(user.phone,
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withAlpha(160))),
                    ],
                  ),
                  if (user.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: scheme.onSurface.withAlpha(140)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(user.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      scheme.onSurface.withAlpha(140))),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (user.deliveryDay.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(user.deliveryDay,
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

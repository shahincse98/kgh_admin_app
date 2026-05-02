import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/user_controller.dart';
import 'user_details_view.dart';

class UserListView extends StatelessWidget {
  const UserListView({super.key});

  Future<void> _showEditDueDialog(
      BuildContext context, UserController controller, dynamic user) async {
    final ctrl = TextEditingController(text: user.totalDue.toString());
    final formKey = GlobalKey<FormState>();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('${user.shopName}\nবাকি পাওনা সম্পাদনা'),
        titleTextStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'পরিমাণ',
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                int.tryParse(v?.trim() ?? '') == null
                    ? 'সঠিক সংখ্যা লিখুন'
                    : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Get.back(result: true);
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final newAmt = int.parse(ctrl.text.trim());
    await controller.updateTotalDue(user.id, newAmt);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UserController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              onChanged: (v) => controller.searchText.value = v,
              decoration: const InputDecoration(
                hintText: 'Shop নাম, মালিক বা ফোন দিয়ে খুঁজুন...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Obx(() {
            final totalDue = controller.users
                .fold<int>(0, (sum, u) => sum + u.totalDue);
            final dueCount =
                controller.users.where((u) => u.totalDue > 0).length;
            if (controller.loading.value || controller.users.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'মোট বাকি পাওনা',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '৳$totalDue',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$dueCount জন',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'বাকি আছে',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = controller.filteredUsers;

              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'কোনো user পাওয়া যায়নি',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: controller.fetchUsers,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = list[index];

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Get.to(() => UserDetailsView(user: user)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: user.isBlocked
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0E7490),
                                child: Text(
                                  user.shopName.isNotEmpty
                                      ? user.shopName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.shopName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (user.isBlocked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDC2626)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Blocked',
                                              style: TextStyle(
                                                color: Color(0xFFDC2626),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('মালিক: ${user.proprietorName}'),
                                    Text('ফোন: ${user.phone}'),
                                    if (user.address.isNotEmpty)
                                      Text(
                                        'ঠিকানা: ${user.address}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'বাকি: ৳${user.totalDue}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: user.totalDue > 0
                                                  ? Colors.red
                                                  : Colors.green),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _showEditDueDialog(
                                              context, controller, user),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red
                                                  .withAlpha(20),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: Colors.red
                                                      .withAlpha(60)),
                                            ),
                                            child: const Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_rounded,
                                                    size: 11,
                                                    color: Colors.red),
                                                SizedBox(width: 3),
                                                Text('এডিট',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'details') {
                                    Get.to(() => UserDetailsView(user: user));
                                  } else if (v == 'block') {
                                    final action = user.isBlocked ? 'Unblock' : 'Block';
                                    final confirmed = await Get.dialog<bool>(
                                      AlertDialog(
                                        title: Text('$action User'),
                                        content: Text('${user.shopName} কে $action করতে চান?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Get.back(result: false),
                                            child: const Text('না'),
                                          ),
                                          TextButton(
                                            onPressed: () => Get.back(result: true),
                                            child: Text(action),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await controller.toggleBlock(user);
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Text('Details'),
                                  ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Text(user.isBlocked ? 'Unblock' : 'Block'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

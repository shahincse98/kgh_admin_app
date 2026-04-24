import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/user_controller.dart';
import 'user_details_view.dart';

class UserListView extends StatelessWidget {
  const UserListView({super.key});

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
                                    Text('Owner: ${user.proprietorName}'),
                                    Text('Phone: ${user.phone}'),
                                    Text(
                                      'Due: ৳${user.totalDue}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
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

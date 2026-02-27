import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/user_controller.dart';
import 'user_details_view.dart';

class UserListView extends StatelessWidget {
  final controller = Get.put(UserController());

  UserListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Users")),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: controller.users.length,
          itemBuilder: (context, index) {
            final user = controller.users[index];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(user.shopName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Owner: ${user.proprietorName}"),
                    Text("Phone: ${user.phone}"),
                    Text("Address: ${user.address}"),
                    Text("Due: ${user.totalDue}"),
                  ],
                ),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  Get.to(() => UserDetailsView(user: user));
                },
              ),
            );
          },
        );
      }),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../localization/locale_service.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/settings_controller.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(title: Text('Settings'.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  icon: Icons.translate_rounded,
                  title: 'Language'.tr,
                  subtitle: 'Choose the language for the whole app'.tr,
                  child: Obx(
                    () => Column(
                      children: [
                        _LanguageTile(
                          label: 'বাংলা',
                          caption: 'Bangla',
                          selected: controller.isBangla,
                          onTap: () =>
                              controller.setLanguage(LocaleService.bangla),
                        ),
                        const SizedBox(height: 8),
                        _LanguageTile(
                          label: 'English',
                          caption: 'ইংরেজি',
                          selected: !controller.isBangla,
                          onTap: () =>
                              controller.setLanguage(LocaleService.english),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  icon: Icons.palette_rounded,
                  title: 'Appearance'.tr,
                  subtitle: 'Switch between light and dark theme'.tr,
                  child: Obx(
                    () => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.isDark.value,
                      onChanged: (_) => controller.toggleTheme(),
                      secondary: Icon(
                        controller.isDark.value
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                      ),
                      title: Text(
                        controller.isDark.value ? 'Dark'.tr : 'Light'.tr,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  icon: Icons.person_rounded,
                  title: 'Account'.tr,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alternate_email_rounded),
                        title: Text('Signed in as'.tr),
                        subtitle: Text(
                          Get.find<AuthController>().currentUser?.email ?? '—',
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                        ),
                        title: Text(
                          'Logout'.tr,
                          style: const TextStyle(color: Colors.red),
                        ),
                        subtitle: Text('Sign out of this device'.tr),
                        onTap: () => _confirmLogout(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'About'.tr,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_rounded),
                    title: const Text('KGH Admin'),
                    subtitle: Text('${'Version'.tr} 1.0.0'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Logout'.tr),
        content: Text('আপনি কি Logout করতে চান?'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('না'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('হ্যাঁ'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) Get.find<AuthController>().logout();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../localization/locale_service.dart';
import '../../../theme/app_theme.dart';

class SettingsController extends GetxController {
  /// বর্তমান ভাষার কোড ('bn' বা 'en')।
  late final RxString languageCode;

  /// ডার্ক থিম চালু আছে কি না।
  late final RxBool isDark;

  @override
  void onInit() {
    super.onInit();
    languageCode = (Get.locale ?? LocaleService.saved).languageCode.obs;
    isDark = Get.isDarkMode.obs;
  }

  bool get isBangla => languageCode.value == 'bn';

  Future<void> setLanguage(Locale locale) async {
    if (locale.languageCode == languageCode.value) return;
    await LocaleService.change(locale);
    languageCode.value = locale.languageCode;
  }

  void toggleTheme() {
    AppTheme.toggleTheme();
    isDark.value = Get.isDarkMode;
  }
}

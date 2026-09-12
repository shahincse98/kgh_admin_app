import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// অ্যাপের ভাষা নিয়ন্ত্রণ ও সংরক্ষণ।
///
/// অনুবাদের key হিসেবে মূল লেখাটাই ব্যবহার করা হয় (যেমন `'স্টক ইন'.tr`)।
/// ফলে কোনো key ম্যাপে না থাকলে GetX সেই key-ই ফেরত দেয় — স্ক্রিন কখনো
/// ফাঁকা বা ভাঙা দেখায় না, বড়জোর মূল লেখাটা দেখায়।
class LocaleService {
  LocaleService._();

  static final GetStorage _box = GetStorage();
  static const String _key = 'appLanguageCode';

  static const Locale bangla = Locale('bn', 'BD');
  static const Locale english = Locale('en', 'US');

  /// অ্যাপ ডিফল্টভাবে বাংলায় চালু হয়।
  static const Locale fallback = bangla;

  static Locale get saved {
    final code = _box.read<String>(_key);
    return code == 'en' ? english : bangla;
  }

  static bool get isBangla => (Get.locale ?? saved).languageCode == 'bn';

  static Future<void> change(Locale locale) async {
    Get.updateLocale(locale);
    await _box.write(_key, locale.languageCode);
  }

  static Future<void> toggle() =>
      change(isBangla ? english : bangla);

  /// বর্তমান ভাষার নাম, সেটিংসে দেখানোর জন্য।
  static String get currentLabel => isBangla ? 'বাংলা' : 'English';
}

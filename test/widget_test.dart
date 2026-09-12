import 'package:flutter_test/flutter_test.dart';
import 'package:kgh_admin_app/localization/app_translations.dart';
import 'package:kgh_admin_app/localization/strings_bn.dart';
import 'package:kgh_admin_app/localization/strings_en.dart';

void main() {
  group('AppTranslations', () {
    final keys = AppTranslations().keys;
    final bn = keys['bn_BD']!;
    final en = keys['en_US']!;

    test('দুই ভাষার key সেট সম্পূর্ণ ও অভিন্ন', () {
      // অসম্পূর্ণ হলে GetX fallbackLocale-এ খুঁজবে এবং এক ভাষার লেখা
      // অন্য ভাষায় ফাঁস হবে — সেই বাগটি যাতে ফিরে না আসে।
      expect(bn.keys.toSet(), equals(en.keys.toSet()));
    });

    test('কোনো অনুবাদ ফাঁকা নয়', () {
      for (final e in bn.entries) {
        expect(e.value.trim(), isNotEmpty, reason: 'bn: ${e.key}');
      }
      for (final e in en.entries) {
        expect(e.value.trim(), isNotEmpty, reason: 'en: ${e.key}');
      }
    });

    test('বাংলা source key ইংরেজিতে অনূদিত হয়', () {
      expect(en['স্টক ইন'], 'Stock in');
      expect(bn['স্টক ইন'], 'স্টক ইন');
    });

    test('ইংরেজি source key বাংলায় অনূদিত হয়', () {
      expect(bn['Settings'], 'সেটিংস');
      expect(en['Settings'], 'Settings');
    });

    test('সংরক্ষিত ডোমেইন মান অনুবাদ ম্যাপে নেই', () {
      // পেমেন্ট মেথড ও বার Firestore-এ বাংলা টেক্সট হিসেবেই সেভ হয়।
      // এগুলো অনূদিত হলে ডেটা নষ্ট হবে — প্রদর্শনের জন্য DomainLabels আছে।
      for (final v in ['নগদ', 'বিকাশ', 'রকেট', 'ব্যাংক', 'হাতে',
                       'রবিবার', 'সোমবার', 'নগদ অ্যাপ']) {
        expect(enUS.containsKey(v), isFalse, reason: v);
        expect(bnBD.containsKey(v), isFalse, reason: v);
      }
    });
  });
}

import 'package:get/get.dart';

import 'strings_bn.dart';
import 'strings_en.dart';

/// GetX অনুবাদ রেজিস্ট্রি।
///
/// key = সোর্স কোডে লেখা মূল স্ট্রিং। তাই:
///   * [enUS] তে শুধু বাংলা key → ইংরেজি অনুবাদ থাকে।
///   * [bnBD] তে শুধু ইংরেজি key → বাংলা অনুবাদ থাকে।
///
/// দুটো ম্যাপকে এখানে *সম্পূর্ণ* করা হয়: যে key যে ম্যাপে নেই, সেখানে key
/// নিজেই মান হিসেবে বসে। এটি জরুরি — GetX কোনো key না পেলে fallbackLocale-এর
/// ম্যাপে খোঁজে, ফলে অসম্পূর্ণ ম্যাপ থাকলে ইংরেজি মোডেও বাংলা লেখা ফিরে আসত।
class AppTranslations extends Translations {
  static final Set<String> _allKeys = {...enUS.keys, ...bnBD.keys};

  static final Map<String, String> _bn = {
    for (final k in _allKeys) k: bnBD[k] ?? k,
  };

  static final Map<String, String> _en = {
    for (final k in _allKeys) k: enUS[k] ?? k,
  };

  @override
  Map<String, Map<String, String>> get keys => {
        'bn_BD': _bn,
        'en_US': _en,
      };
}

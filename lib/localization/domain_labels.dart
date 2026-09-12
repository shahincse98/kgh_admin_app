import 'package:get/get.dart';

/// Firestore-এ সংরক্ষিত ডোমেইন মানগুলোর *প্রদর্শনযোগ্য* রূপ।
///
/// পেমেন্ট মেথড, বার, খরচের ক্যাটাগরি — এগুলো ডেটাবেজে বাংলা টেক্সট হিসেবেই
/// সেভ থাকে এবং তুলনাও হয় সেই বাংলা মান দিয়ে। তাই মানগুলো কখনো অনুবাদ করে
/// সেভ করা যাবে না; শুধু স্ক্রিনে দেখানোর সময় এই হেলপারগুলো ব্যবহার করতে হবে।
class DomainLabels {
  DomainLabels._();

  static const Map<String, String> _paymentMethodEn = {
    'নগদ': 'Cash',
    'হাতে': 'Cash in hand',
    'বিকাশ': 'bKash',
    'নগদ (মোবাইল)': 'Nagad',
    'নগদ অ্যাপ': 'Nagad app',
    'রকেট': 'Rocket',
    'ব্যাংক': 'Bank',
    'SR হাতে': 'With SR',
    'বাকি': 'Due',
  };

  static const Map<String, String> _weekdayEn = {
    'শনিবার': 'Saturday',
    'রবিবার': 'Sunday',
    'সোমবার': 'Monday',
    'মঙ্গলবার': 'Tuesday',
    'বুধবার': 'Wednesday',
    'বৃহস্পতিবার': 'Thursday',
    'শুক্রবার': 'Friday',
  };

  static const Map<String, String> _expenseCategoryEn = {
    'বাইকের তেল': 'Bike fuel',
    'পরিবহন ভাড়া': 'Transport fare',
    'দোকান খরচ': 'Shop expense',
    'বাইক সার্ভিসিং': 'Bike servicing',
    'কর্মচারী বেতন': 'Staff salary',
    'অন্যান্য': 'Other',
  };

  static const Map<String, String> _orderStatusBn = {
    'pending': 'পেন্ডিং',
    'dispatched': 'ডিসপ্যাচ হয়েছে',
    'delivered': 'ডেলিভারি হয়েছে',
    'cancelled': 'বাতিল',
  };

  static const Map<String, String> _orderStatusEn = {
    'pending': 'Pending',
    'dispatched': 'Dispatched',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  static bool get _isBn => (Get.locale?.languageCode ?? 'bn') == 'bn';

  static String _show(Map<String, String> enMap, String value) =>
      _isBn ? value : (enMap[value.trim()] ?? value);

  /// পেমেন্ট মেথডের প্রদর্শনযোগ্য নাম। অজানা মান হুবহু ফেরত যায়।
  static String paymentMethod(String value) => _show(_paymentMethodEn, value);

  /// বারের প্রদর্শনযোগ্য নাম।
  static String weekday(String value) => _show(_weekdayEn, value);

  /// খরচের ক্যাটাগরির প্রদর্শনযোগ্য নাম।
  static String expenseCategory(String value) =>
      _show(_expenseCategoryEn, value);

  /// অর্ডার স্ট্যাটাসের প্রদর্শনযোগ্য নাম (ডেটাবেজে ইংরেজি কোড হিসেবে থাকে)।
  static String orderStatus(String value) {
    final v = value.trim().toLowerCase();
    return (_isBn ? _orderStatusBn : _orderStatusEn)[v] ?? value;
  }

  /// পণ্যের সংখ্যা। বাংলায় একবচন-বহুবচনে পার্থক্য নেই, ইংরেজিতে আছে।
  static String productCount(int n) =>
      _isBn ? '$n পণ্য' : '$n ${n == 1 ? 'product' : 'products'}';

  /// 'সব' / 'All' ধরনের ফিল্টার অপশনও ডেটার সাথে মিলিয়ে দেখাতে হয়।
  static String filterOption(String value) {
    if (_isBn) return value;
    if (value.trim() == 'সব') return 'All';
    return _paymentMethodEn[value.trim()] ??
        _expenseCategoryEn[value.trim()] ??
        _weekdayEn[value.trim()] ??
        value;
  }
}

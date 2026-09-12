import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final _box = GetStorage();
  static const _key = 'isDark';

  static ThemeMode get themeMode =>
      (_box.read(_key) == true) ? ThemeMode.dark : ThemeMode.light;

  static bool get isDark => Get.isDarkMode;

  static void toggleTheme() {
    final dark = !Get.isDarkMode;
    Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    _box.write(_key, dark);
  }

  /// অ্যাপের লেখা মূলত বাংলা, কিন্তু Manrope/Space Grotesk-এ বাংলা বর্ণ নেই।
  /// ফন্ট স্পষ্ট করে না দিলে রেন্ডারার চাহিদামতো fallback ফন্ট নামায় — ধীর
  /// সংযোগে ততক্ষণ বাংলা লেখা খালি চৌকো বাক্স হয়ে থাকে। তাই বাংলা ফন্টটি
  /// fallback হিসেবে ঘোষণা করা হয় এবং main()-এ আগেই নামিয়ে রাখা হয়।
  static final List<String> bengaliFallback = [
    GoogleFonts.notoSansBengali().fontFamily!,
  ];

  static TextTheme _text(TextTheme? base) =>
      (base == null
              ? GoogleFonts.manropeTextTheme()
              : GoogleFonts.manropeTextTheme(base))
          .apply(fontFamilyFallback: bengaliFallback);

  static const Color _seedLight = Color(0xFF0E7490);
  static const Color _seedDark = Color(0xFF22D3EE);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedLight,
      brightness: Brightness.light,
    ),
    textTheme: _text(null),
    scaffoldBackgroundColor: const Color(0xFFF3F8FB),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF0A2533),
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0A2533),
      ).copyWith(fontFamilyFallback: bengaliFallback),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0ECF2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0ECF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _seedLight, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedDark,
      brightness: Brightness.dark,
    ),
    textTheme: _text(ThemeData.dark().textTheme),
    scaffoldBackgroundColor: const Color(0xFF0A1218),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFFDAF6FF),
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFDAF6FF),
      ).copyWith(fontFamilyFallback: bengaliFallback),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF101C24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E3440)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E3440)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _seedDark, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: const Color(0xFF101C24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

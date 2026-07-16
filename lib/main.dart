import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'routes/app_routes.dart';
import 'routes/app_pages.dart';
import 'bindings/initial_binding.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

String? srDocIdForStartup;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  String initialRoute = AppRoutes.login;
  String? srDocId;

  try {
    await GetStorage.init().timeout(const Duration(seconds: 5));
  } catch (_) {}

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (_) {}

  try {
    await _initFirestore().timeout(const Duration(seconds: 10));
  } catch (_) {}

  try {
    final user = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 10));
    if (user != null && user.email != null) {
      try {
        final srSnap = await FirebaseFirestore.instance
            .collection('sr_staff')
            .where('email', isEqualTo: user.email)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        if (srSnap.docs.isNotEmpty) {
          initialRoute = AppRoutes.srPanel;
          srDocId = srSnap.docs.first.id;
        } else {
          initialRoute = AppRoutes.home;
        }
      } catch (_) {
        initialRoute = AppRoutes.home;
      }
    }
  } catch (_) {}

  srDocIdForStartup = srDocId;
  runApp(MyApp(initialRoute: initialRoute, srDocId: srDocId));
}

Future<void> _initFirestore() async {
  final db = FirebaseFirestore.instance;
  final financeRef = db.collection('admin_settings').doc('finance');
  final snap = await financeRef.get();
  if (!snap.exists) {
    await financeRef.set({
      'srCommissionPercent': 6.0,
      'srMonthlyFixedSalary': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final String? srDocId;

  const MyApp({super.key, required this.initialRoute, this.srDocId});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.themeMode,
    );
  }
}

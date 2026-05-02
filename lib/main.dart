import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'routes/app_routes.dart';
import 'routes/app_pages.dart';
import 'bindings/initial_binding.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

String _initialRoute = AppRoutes.login;
String? srDocIdForStartup;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _initFirestore();

  // Determine initial route based on role
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final db = FirebaseFirestore.instance;
    final srSnap = await db
        .collection('sr_staff')
        .where('email', isEqualTo: user.email)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (srSnap.docs.isNotEmpty) {
      _initialRoute = AppRoutes.srPanel;
      srDocIdForStartup = srSnap.docs.first.id;
    } else {
      _initialRoute = AppRoutes.home;
    }
  }

  runApp(const MyApp());
}

/// Ensures required Firestore documents exist with default values.
/// Collections are auto-created in Firestore on first write.
///   • admin_settings/finance  — SR commission % & monthly salary
///   • expenses                — auto-created on first expense entry
///   • sr_payments             — auto-created on first payment entry
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: _initialRoute,
      getPages: AppPages.pages,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.themeMode,
    );
  }
}

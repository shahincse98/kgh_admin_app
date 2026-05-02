import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final email = ''.obs;
  final password = ''.obs;
  final loading = false.obs;
  final errorMsg = ''.obs;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Check whether the currently logged-in user is an SR.
  /// Returns the SR document ID if found, null otherwise.
  Future<String?> _detectSrRole(String userEmail) async {
    final snap = await _db
        .collection('sr_staff')
        .where('email', isEqualTo: userEmail.trim().toLowerCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    return null;
  }

  Future<void> login() async {
    errorMsg.value = '';
    if (email.value.trim().isEmpty || password.value.isEmpty) {
      errorMsg.value = 'Email ও Password দিন';
      return;
    }
    loading.value = true;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.value.trim(),
        password: password.value,
      );
      await _navigateByRole();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          errorMsg.value = 'এই email এ কোনো account নেই';
          break;
        case 'wrong-password':
          errorMsg.value = 'Password ভুল';
          break;
        case 'invalid-credential':
          errorMsg.value = 'Email বা Password ভুল';
          break;
        case 'too-many-requests':
          errorMsg.value = 'অনেক বার চেষ্টা হয়েছে, কিছুক্ষণ পর চেষ্টা করুন';
          break;
        default:
          errorMsg.value = 'Login failed: ${e.message}';
      }
    } finally {
      loading.value = false;
    }
  }

  /// Called once after a successful Firebase sign-in to route to the
  /// correct home (admin vs SR panel).
  Future<void> _navigateByRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final srId = await _detectSrRole(user.email ?? '');
    if (srId != null) {
      Get.offAllNamed(AppRoutes.srPanel, arguments: srId);
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  /// Used by main.dart to decide the initial route on app start when
  /// a user is already logged in.
  Future<String> resolveInitialRoute() async {
    final user = _auth.currentUser;
    if (user == null) return AppRoutes.login;
    final srId = await _detectSrRole(user.email ?? '');
    return srId != null ? AppRoutes.srPanel : AppRoutes.home;
  }

  Future<void> logout() async {
    await _auth.signOut();
    Get.offAllNamed(AppRoutes.login);
  }
}

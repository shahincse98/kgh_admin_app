import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;

  final email = ''.obs;
  final password = ''.obs;
  final loading = false.obs;
  final errorMsg = ''.obs;

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => currentUser != null;

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
      Get.offAllNamed(AppRoutes.home);
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

  Future<void> logout() async {
    await _auth.signOut();
    Get.offAllNamed(AppRoutes.login);
  }
}

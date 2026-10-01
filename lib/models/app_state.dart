import 'package:flutter/foundation.dart';

class AppState {
  static final ValueNotifier<bool> isAuthenticated = ValueNotifier(false);

  static const String demoEmail = 'demo@smartfind.com';
  static const String demoPassword = 'demo123';
  static const String demoUserName = 'User';

  static bool validateCredentials(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    return normalizedEmail == demoEmail && password == demoPassword;
  }

  static bool signUp({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().length < 6) {
      return false;
    }

    isAuthenticated.value = true;
    return true;
  }

  static void signOut() {
    isAuthenticated.value = false;
  }
}

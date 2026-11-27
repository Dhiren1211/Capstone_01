import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

/// An authentication problem with a message that is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything that touches Firebase Authentication and the `/users/{uid}`
/// profile document.
///
/// Sign-in method: **e-mail + password**, and the account must have a
/// **verified e-mail address** before it can read or write any data (this is
/// enforced by `firestore.rules`, not just by the UI).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Emits whenever the signed-in user changes (sign-in, sign-out, profile
  /// updates, token refresh).
  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Sign up / sign in
  // ---------------------------------------------------------------------------

  /// Creates the account, stores the profile and sends the verification
  /// e-mail. The user must open the link in that e-mail before they can use
  /// the app.
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String studentId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim();

    final domainProblem = AppValidators.campusEmailError(cleanEmail);
    if (domainProblem != null) throw AuthFailure(domainProblem);

    final User user;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final created = cred.user;
      if (created == null) {
        throw const AuthFailure('Could not create the account. Try again.');
      }
      user = created;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }

    // The account exists now. The next steps are best-effort: if one fails
    // (for example a flaky connection) the user can still continue, because
    // the profile is re-created on first sign-in and the verification e-mail
    // can be re-sent from the "Check your inbox" screen.
    try {
      await user.updateDisplayName(cleanName);
    } catch (e) {
      debugPrint('[auth] updateDisplayName failed: $e');
    }
    try {
      await ensureProfile(user, displayName: cleanName, studentId: studentId);
    } catch (e) {
      debugPrint('[auth] profile creation failed (will retry later): $e');
    }
    try {
      await sendEmailVerification();
    } on AuthFailure catch (e) {
      debugPrint('[auth] verification e-mail not sent: ${e.message}');
    }
    return user;
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthFailure('Sign-in failed. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  // ---------------------------------------------------------------------------
  // E-mail verification & password reset
  // ---------------------------------------------------------------------------

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('You are signed out. Please sign in again.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
    final email = user.email;
    if (email != null) unawaited(_autoVerifyInEmulator(email));
  }

  /// Re-reads the account from the server. Returns `true` once the e-mail is
  /// verified (and the ID token has been refreshed so Firestore rules see the
  /// `email_verified` claim).
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' ||
          e.code == 'user-not-found' ||
          e.code == 'user-disabled') {
        await _auth.signOut();
      }
      throw AuthFailure(_message(e));
    }
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    try {
      await fresh.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
    return true;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Profile document
  // ---------------------------------------------------------------------------

  /// Creates `/users/{uid}` if it does not exist yet.
  Future<void> ensureProfile(
    User user, {
    String? displayName,
    String? studentId,
  }) async {
    final ref = _db.collection(AppConstants.colUsers).doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final profile = UserModel.fromAuthUser(user).copyWith(
      displayName: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : null,
      studentId: studentId,
    );
    await ref.set(profile.toFirestore());
  }

  /// Live view of the signed-in user's profile document.
  Stream<UserModel?> watchProfile(String uid) {
    return _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> updateDisplayName(String newDisplayName) async {
    final user = _requireUser();
    final name = newDisplayName.trim();
    if (name.length < 2) {
      throw const AuthFailure('Name must be at least 2 characters.');
    }
    await user.updateDisplayName(name);
    await _db.collection(AppConstants.colUsers).doc(user.uid).set({
      'displayName': name,
    }, SetOptions(merge: true));
  }

  Future<void> updateAvatarUrl(String newAvatarUrl) async {
    final user = _requireUser();
    await _db.collection(AppConstants.colUsers).doc(user.uid).set({
      'avatarUrl': newAvatarUrl,
    }, SetOptions(merge: true));
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('You are signed out. Please sign in again.');
    }
    return user;
  }

  // ---------------------------------------------------------------------------
  // Error messages
  // ---------------------------------------------------------------------------

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That e-mail address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled. Contact the administrator.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect e-mail or password.';
      case 'email-already-in-use':
        return 'An account with this e-mail already exists. Try signing in.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No connection to the server. Check your internet (or that the '
            'Firebase emulators are running) and try again.';
      case 'operation-not-allowed':
        return 'E-mail/password sign-in is not enabled for this Firebase '
            'project. Enable it in Authentication → Sign-in method.';
      case 'requires-recent-login':
        return 'Please sign in again to do this.';
      case 'user-token-expired':
        return 'Your session expired. Please sign in again.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'The Firebase API key is not valid. Check env.json.';
      default:
        final m = e.message;
        return (m == null || m.isEmpty)
            ? 'Something went wrong (${e.code}). Please try again.'
            : m;
    }
  }

  // ---------------------------------------------------------------------------
  // Emulator convenience
  // ---------------------------------------------------------------------------

  /// The Auth emulator cannot send real e-mail. In **debug builds that talk to
  /// the emulator** we therefore open the verification link ourselves so that
  /// sign-up works end to end without any manual step.
  Future<void> _autoVerifyInEmulator(String email) async {
    if (!(kDebugMode && AppConfig.useEmulator)) return;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final host = _emulatorHttpHost();
      final port = AppConfig.authEmulatorPort;
      final projectId = Firebase.app().options.projectId;
      final list = await http
          .get(
            Uri.http(
              '$host:$port',
              '/emulator/v1/projects/$projectId/oobCodes',
            ),
          )
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(list.body);
      final codes = decoded is Map ? decoded['oobCodes'] : null;
      if (codes is! List) return;
      Map<String, dynamic>? latest;
      for (final c in codes) {
        if (c is Map<String, dynamic> &&
            c['requestType'] == 'VERIFY_EMAIL' &&
            (c['email'] as String?)?.toLowerCase() == email.toLowerCase()) {
          latest = c;
        }
      }
      final link = latest?['oobLink'] as String?;
      if (link == null) return;
      final params = Uri.parse(link).queryParameters;
      await http
          .get(Uri.http('$host:$port', '/emulator/action', params))
          .timeout(const Duration(seconds: 5));
      debugPrint('[auth] emulator: verification link opened for $email');
    } catch (e) {
      debugPrint('[auth] emulator auto-verify skipped: $e');
    }
  }

  static String _emulatorHttpHost() {
    final host = AppConfig.emulatorHost;
    final isLoopback = host == 'localhost' || host == '127.0.0.1';
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        isLoopback) {
      return '10.0.2.2'; // the Android emulator's alias for the host computer
    }
    return host;
  }
}

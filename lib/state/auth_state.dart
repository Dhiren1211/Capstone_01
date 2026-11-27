import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Where the visitor is in the sign-in journey.
enum AuthStatus {
  /// Waiting for Firebase to tell us who is signed in (app start).
  loading,

  /// Nobody is signed in.
  signedOut,

  /// Signed in with e-mail/password but the e-mail is not verified yet.
  needsVerification,

  /// Verified student.
  signedIn,
}

/// App-wide authentication state, driven by Firebase Auth.
///
/// * [user] is only non-null when [status] is [AuthStatus.signedIn].
/// * Actions (`signIn`, `register`, …) return `true` on success. On failure
///   they return `false` and put a readable message in [error].
class AuthState extends ChangeNotifier {
  AuthState({AuthService? service})
    : _service = service ?? AuthService.instance {
    _listen();
  }

  final AuthService _service;

  StreamSubscription<User?>? _userSub;
  StreamSubscription<UserModel?>? _profileSub;
  StreamSubscription<bool>? _adminSub;
  bool _isAdmin = false;

  AuthStatus _status = AuthStatus.loading;
  UserModel? _user;
  String? _pendingEmail;
  String? _error;
  bool _busy = false;
  String? _profileUid;
  int _sequence = 0;

  AuthStatus get status => _status;
  UserModel? get user => _user;

  /// E-mail of the account that still has to be verified.
  String? get pendingEmail => _pendingEmail;

  /// Last error message from an action, or `null`.
  String? get error => _error;

  /// True while an action such as sign-in is running (use for button spinners).
  bool get isBusy => _busy;

  /// True only while the app is working out who is signed in at start-up.
  bool get isLoading => _status == AuthStatus.loading;

  bool get isAuthenticated => _status == AuthStatus.signedIn && _user != null;
  bool get needsVerification => _status == AuthStatus.needsVerification;

  /// Signed-in person has an `/admins/{uid}` document (live).
  bool get isAdmin => isAuthenticated && _isAdmin;

  /// Signed-in person was suspended by an admin.
  bool get isBanned => isAuthenticated && (_user?.banned ?? false);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Listening to Firebase
  // ---------------------------------------------------------------------------

  void _listen() {
    _userSub = _service.userChanges.listen(
      _onFirebaseUser,
      onError: (Object e) {
        debugPrint('[auth] user stream error: $e');
        _status = AuthStatus.signedOut;
        _user = null;
        notifyListeners();
      },
    );
  }

  Future<void> _onFirebaseUser(User? fb) async {
    final seq = ++_sequence;

    if (fb == null) {
      await _stopProfile();
      _user = null;
      _pendingEmail = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    if (fb.isAnonymous) {
      // Left over from an older build that had a "Try Demo" button: there is
      // no anonymous mode any more, so end that session.
      await _stopProfile();
      _user = null;
      _pendingEmail = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      try {
        await _service.signOut();
      } catch (e) {
        debugPrint('[auth] could not end the old guest session: $e');
      }
      return;
    }

    if (!fb.emailVerified) {
      await _stopProfile();
      _user = null;
      _pendingEmail = fb.email;
      _status = AuthStatus.needsVerification;
      notifyListeners();
      return;
    }

    // Verified student.
    _pendingEmail = null;
    if (_profileUid == fb.uid && _profileSub != null) {
      // Same person, just a token refresh — nothing to do.
      return;
    }
    _user = UserModel.fromAuthUser(fb);
    _status = AuthStatus.signedIn;
    notifyListeners();

    try {
      await _service.ensureProfile(fb);
    } catch (e) {
      debugPrint('[auth] ensureProfile failed: $e');
    }
    if (seq != _sequence) return; // a newer event superseded this one

    _profileUid = fb.uid;
    _profileSub = _service.watchProfile(fb.uid).listen((profile) {
      if (profile == null) return;
      _user = profile;
      notifyListeners();
    }, onError: (Object e) => debugPrint('[auth] profile stream error: $e'));
    _adminSub = AdminService.instance.watchIsAdmin(fb.uid).listen((admin) {
      if (admin == _isAdmin) return;
      _isAdmin = admin;
      notifyListeners();
    });
  }

  Future<void> _stopProfile() async {
    await _profileSub?.cancel();
    await _adminSub?.cancel();
    _profileSub = null;
    _adminSub = null;
    _isAdmin = false;
    _profileUid = null;
  }

  /// Make [status] reflect the current Firebase user right now (used after an
  /// action so the next screen never sees a stale state).
  Future<void> _syncNow() => _onFirebaseUser(_service.currentUser);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<bool> signIn({required String email, required String password}) {
    return _run(() async {
      await _service.signIn(email: email, password: password);
      await _syncNow();
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String studentId,
  }) {
    return _run(() async {
      await _service.register(
        email: email,
        password: password,
        displayName: displayName,
        studentId: studentId,
      );
      await _syncNow();
    });
  }

  /// Re-checks the e-mail verification. Returns `true` once verified.
  Future<bool> checkEmailVerified({bool silent = false}) async {
    try {
      final ok = await _service.refreshVerification();
      if (ok) await _syncNow();
      return ok;
    } catch (e) {
      if (!silent) {
        _error = _describe(e);
        notifyListeners();
      }
      return false;
    }
  }

  /// Sends the verification e-mail again. Returns `null` on success, otherwise
  /// a message for the user.
  Future<String?> resendVerification() async {
    try {
      await _service.sendEmailVerification();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  /// Sends a password-reset e-mail. Returns `null` on success, otherwise a
  /// message for the user.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _service.sendPasswordReset(email);
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  Future<void> signOut() async {
    try {
      // Forget this phone first, while we are still allowed to write.
      await NotificationService.instance.prepareSignOut();
    } catch (e) {
      debugPrint('[auth] could not unregister alerts: $e');
    }
    try {
      await _service.signOut();
    } catch (e) {
      debugPrint('[auth] signOut failed: $e');
    }
    await _syncNow();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      _error = _describe(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static String _describe(Object e) {
    if (e is AuthFailure) return e.message;
    debugPrint('[auth] unexpected error: $e');
    return 'Something went wrong. Please check your connection and try again.';
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _profileSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }
}

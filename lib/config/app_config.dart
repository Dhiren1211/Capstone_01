import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Nothing secret lives in the source code. Every value below is injected when
/// the app is built or run, using Dart's `--dart-define` mechanism. The
/// easiest way is one JSON file that holds all of them:
///
///     flutter run --dart-define-from-file=env.json
///
/// `env.example.json` (in the project root) lists every key. Copy it to
/// `env.json` and fill it in. `env.json` is git-ignored.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Firebase backend selection
  // ---------------------------------------------------------------------------

  /// `true` → talk to the Firebase Local Emulator Suite instead of the cloud.
  ///
  /// Ignored in release builds so a shipped app can never be pointed at a
  /// developer machine by accident.
  static const bool _useEmulatorRequested = bool.fromEnvironment(
    'USE_EMULATOR',
    defaultValue: false,
  );

  static bool get useEmulator => _useEmulatorRequested && !kReleaseMode;

  /// Host of the machine that runs `firebase emulators:start`.
  ///
  /// * Android emulator / iOS simulator / desktop: leave as `localhost`.
  ///   (FlutterFire maps `localhost` to `10.0.2.2` on the Android emulator.)
  /// * Real phone: use your computer's LAN IP, e.g. `192.168.0.23`.
  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const int authEmulatorPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );

  static const int firestoreEmulatorPort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  // ---------------------------------------------------------------------------
  // Firebase project values (cloud mode only).
  //
  // Not needed when you use `flutterfire configure` (it generates
  // lib/firebase_options.dart for you) or when USE_EMULATOR is true.
  // ---------------------------------------------------------------------------
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseAppIdAndroid = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const String firebaseAppIdIos = String.fromEnvironment(
    'FIREBASE_APP_ID_IOS',
  );
  static const String firebaseAppIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );

  /// Project id used by the emulators. The `demo-` prefix tells the Firebase
  /// tools that this is an offline "demo" project that needs no credentials.
  static const String emulatorProjectId = 'demo-smartfind';

  // ---------------------------------------------------------------------------
  // Image hosting (Cloudinary, free plan — replaces Firebase Storage)
  // ---------------------------------------------------------------------------

  /// Cloudinary "cloud name" (Dashboard → top-left, or Settings → API Keys).
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );

  /// Name of an **unsigned** upload preset (Settings → Upload → Upload presets).
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  static bool get imageUploadsConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Accounts
  // ---------------------------------------------------------------------------

  /// Comma separated list of e-mail domains allowed to register, for example
  /// `ks.ac.kr,kyungsung.ac.kr`. Leave empty to allow any e-mail address.
  static const String _allowedEmailDomains = String.fromEnvironment(
    'ALLOWED_EMAIL_DOMAINS',
  );

  static List<String> get allowedEmailDomains => _allowedEmailDomains
      .split(',')
      .map((d) => d.trim().toLowerCase().replaceFirst(RegExp(r'^@'), ''))
      .where((d) => d.isNotEmpty)
      .toList();


  // ---------------------------------------------------------------------------
  // Push notifications + AI matching (optional Cloudflare Worker, see server/)
  // ---------------------------------------------------------------------------

  /// Base URL of the deployed Worker, e.g. `https://smartfind-push.you.workers.dev`.
  /// Empty = no server: matching still works on the phone and alerts pop up
  /// while the app is running, but phones that are completely switched off or
  /// the app closed are not reached.
  static const String _pushApiUrl = String.fromEnvironment('MATCH_API_URL');

  static String get pushApiUrl => _pushApiUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static bool get pushApiConfigured => pushApiUrl.isNotEmpty;

  /// Real push (FCM) needs a real Firebase project; the emulators cannot send it.
  static bool get pushAvailable => !useEmulator;
}

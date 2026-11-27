// Firebase options for smartFind.
//
// This file is intentionally generic: it does not contain any real project
// credentials. It reads them from `--dart-define` values (see
// lib/config/app_config.dart and env.example.json).
//
//  * Emulator mode (USE_EMULATOR=true)  → harmless demo values are used.
//  * Cloud mode                         → values come from env.json, OR run
//                                         `flutterfire configure`, which
//                                         replaces this whole file with a
//                                         generated one that has the same
//                                         `DefaultFirebaseOptions.currentPlatform`
//                                         API. Both ways work.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'config/app_config.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    final emulator = AppConfig.useEmulator;

    String pick(String value, String emulatorFallback) {
      if (value.isNotEmpty) return value;
      return emulator ? emulatorFallback : '';
    }

    final String appId;
    if (kIsWeb) {
      appId = pick(
        AppConfig.firebaseAppIdWeb,
        '1:000000000000:web:0000000000000000000000',
      );
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          appId = pick(
            AppConfig.firebaseAppIdAndroid,
            '1:000000000000:android:0000000000000000000000',
          );
          break;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          appId = pick(
            AppConfig.firebaseAppIdIos,
            '1:000000000000:ios:0000000000000000000000',
          );
          break;
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          appId = pick(
            AppConfig.firebaseAppIdWeb,
            '1:000000000000:web:0000000000000000000000',
          );
          break;
      }
    }

    final projectId = pick(
      AppConfig.firebaseProjectId,
      AppConfig.emulatorProjectId,
    );

    return FirebaseOptions(
      apiKey: pick(AppConfig.firebaseApiKey, 'demo-api-key'),
      appId: appId,
      messagingSenderId: pick(
        AppConfig.firebaseMessagingSenderId,
        '000000000000',
      ),
      projectId: projectId,
      authDomain: AppConfig.firebaseAuthDomain.isNotEmpty
          ? AppConfig.firebaseAuthDomain
          : (projectId.isEmpty ? null : '$projectId.firebaseapp.com'),
    );
  }
}

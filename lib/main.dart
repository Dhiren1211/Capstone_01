import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/setup_required_screen.dart';
import 'services/notification_service.dart';
import 'state/auth_state.dart';
import 'state/items_state.dart';
import 'state/settings_store.dart';
import 'utils/ksu_buildings.dart';

/// Entry point.
///
/// 1. Lock the orientation to portrait.
/// 2. Start Firebase (cloud project, or the local emulators in debug builds
///    when `USE_EMULATOR=true`). If that is not possible, show a clear
///    "setup required" screen instead of crashing.
/// 3. Load the persisted settings and the surveyed building positions.
/// 4. Prepare the alert service (pop-ups and push).
/// 5. Run the app with its Provider state.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log (instead of silently swallowing) errors that escape every handler.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final problem = await _startFirebase();
  if (problem != null) {
    runApp(SetupRequiredApp(problem: problem));
    return;
  }

  await SettingsStore.instance.init();
  await _loadBuildingPositions();
  await NotificationService.instance.init(
    navigatorKey: SmartfindApp.navigatorKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
        // The feed may only be read by signed-in users, so it follows the
        // sign-in state of AuthState.
        ChangeNotifierProxyProvider<AuthState, ItemsState>(
          create: (_) => ItemsState(),
          update: (_, auth, items) =>
              (items ?? ItemsState())..setSignedIn(auth.isAuthenticated),
        ),
        ChangeNotifierProvider<SettingsStore>.value(
          value: SettingsStore.instance,
        ),
      ],
      child: const SmartfindApp(),
    ),
  );
}

/// Applies surveyed building positions (assets/data/building_positions.json)
/// over the built-in coordinates. An empty or broken file changes nothing.
Future<void> _loadBuildingPositions() async {
  try {
    final raw = await rootBundle.loadString('assets/data/building_positions.json');
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) BuildingPositions.apply(json);
  } catch (e) {
    debugPrint('[buildings] could not load surveyed positions: $e');
  }
}

/// Starts Firebase. Returns `null` on success, otherwise a human readable
/// description of what is missing.
Future<String?> _startFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  final missing = <String>[
    if (options.apiKey.isEmpty) 'FIREBASE_API_KEY',
    if (options.appId.isEmpty) 'FIREBASE_APP_ID_*',
    if (options.projectId.isEmpty) 'FIREBASE_PROJECT_ID',
    if (options.messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
  ];
  if (missing.isNotEmpty) {
    return 'No Firebase settings were found (missing: ${missing.join(', ')}).';
  }

  try {
    await Firebase.initializeApp(options: options);

    if (AppConfig.useEmulator) {
      final host = AppConfig.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(
        host,
        AppConfig.authEmulatorPort,
      );
      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        AppConfig.firestoreEmulatorPort,
      );
      debugPrint(
        '[firebase] Using emulators on $host '
        '(auth ${AppConfig.authEmulatorPort}, '
        'firestore ${AppConfig.firestoreEmulatorPort})',
      );
    }
    return null;
  } catch (e, st) {
    debugPrint('[firebase] initialization failed: $e\n$st');
    return 'Firebase could not be started: $e';
  }
}

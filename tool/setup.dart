// One-time project setup for smartFind.
//
//   dart tool/setup.dart            create + configure the Android / iOS projects
//   dart tool/setup.dart --check    only check that everything is ready to run
//
// What it does (safe to run again at any time — it never duplicates anything):
//
//   1. Checks that Flutter is installed.
//   2. Runs `flutter create` for the Android and iOS folders (the zip ships
//      only the Dart code, not the generated native projects).
//   3. Patches the generated native files so the app works:
//        Android  minSdk 24 (needed by Firebase), INTERNET, location and
//                 notification permissions, core-library desugaring (needed
//                 by the notification plugin), the default alert channel, the
//                 Google services plugin when android/app/google-services.json
//                 exists, app name, cleartext traffic for the local emulators
//                 (debug builds only)
//        iOS      location / photo / camera usage texts, remote-notification
//                 background mode, iOS 15 deployment target, app name
//   4. Installs the launcher icons from tool/branding.
//   5. Runs `flutter pub get`.
//
// It only needs `dart:` libraries, so it runs with plain `dart` — no
// `flutter pub get` first.

import 'dart:convert';
import 'dart:io';

const _projectName = 'smartfind';
const _displayName = 'smartFind';
const _minAndroidSdk = 24;
const _minIosVersion = '15.0';

late final String root;
int _problems = 0;

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage: dart tool/setup.dart [--check] [--skip-pub-get]');
    return;
  }
  root = _findRoot();
  final checkOnly = args.contains('--check');

  stdout.writeln('smartFind ${checkOnly ? 'check' : 'setup'}');
  stdout.writeln('Project folder: $root\n');

  final flutterOk = await _checkFlutter();

  if (!checkOnly) {
    if (!flutterOk) {
      _fatal(
        'Flutter is required. Install it from https://docs.flutter.dev/get-started/install '
        'and make sure `flutter --version` works in this terminal.',
      );
    }
    await _ensureNativeProjects();
    _patchAndroid();
    _patchIos();
    _installIcons();
    if (!args.contains('--skip-pub-get')) {
      await _run('flutter', ['pub', 'get'], 'flutter pub get');
    }
    stdout.writeln('');
  }

  await _checkConfiguration();

  stdout.writeln('');
  if (_problems == 0) {
    stdout.writeln('✓ All good. Next: see "Run the app" in README.md.');
  } else {
    stdout.writeln(
      '✗ $_problems thing(s) need attention (see the lines marked ✗ above).',
    );
    exitCode = 1;
  }
}

// ---------------------------------------------------------------- utilities

String _findRoot() {
  // Prefer the folder this script lives in (tool/..), fall back to the cwd.
  final fromScript = File.fromUri(Platform.script).parent.parent;
  if (File('${fromScript.path}/pubspec.yaml').existsSync()) {
    return fromScript.path;
  }
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd.path;
  _fatal(
    'Run this from the smartFind project folder (the one containing pubspec.yaml).',
  );
}

Never _fatal(String message) {
  stderr.writeln('\n✗ $message\n');
  exit(1);
}

void _ok(String message) => stdout.writeln('✓ $message');
void _info(String message) => stdout.writeln('  $message');
void _warn(String message) => stdout.writeln('! $message');
void _bad(String message) {
  _problems++;
  stdout.writeln('✗ $message');
}

String _p(String relative) => '$root/$relative';

Future<ProcessResult?> _tryRun(String exe, List<String> args) async {
  try {
    return await Process.run(
      exe,
      args,
      runInShell: true,
      workingDirectory: root,
    );
  } on ProcessException {
    return null;
  }
}

/// Runs a command and streams its output. Exits the script on failure.
Future<void> _run(String exe, List<String> args, String label) async {
  stdout.writeln('→ $label');
  final process = await Process.start(
    exe,
    args,
    runInShell: true,
    workingDirectory: root,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    _fatal(
      '"$label" failed (exit code $code). Fix the message above and run '
      '`dart tool/setup.dart` again.',
    );
  }
}

String _read(String relative) => File(_p(relative)).readAsStringSync();
void _write(String relative, String content) =>
    File(_p(relative)).writeAsStringSync(content);

// ----------------------------------------------------------------- Flutter

Future<bool> _checkFlutter() async {
  final result = await _tryRun('flutter', ['--version']);
  if (result == null || result.exitCode != 0) {
    _bad(
      'Flutter was not found. Install: https://docs.flutter.dev/get-started/install',
    );
    return false;
  }
  final firstLine = '${result.stdout}'.split('\n').first.trim();
  _ok(firstLine);
  final match = RegExp(r'Flutter (\d+)\.(\d+)').firstMatch(firstLine);
  if (match != null) {
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    if (major < 3 || (major == 3 && minor < 38)) {
      _bad(
        'Flutter 3.38 or newer is required (found $major.$minor). '
        'Run `flutter upgrade`.',
      );
    }
  }
  return true;
}

bool get _hasAndroid =>
    File(_p('android/app/build.gradle')).existsSync() ||
    File(_p('android/app/build.gradle.kts')).existsSync();

bool get _hasIos => Directory(_p('ios/Runner.xcodeproj')).existsSync();

Future<void> _ensureNativeProjects() async {
  if (_hasAndroid && _hasIos) {
    _ok('Android and iOS projects already exist');
    return;
  }
  await _run('flutter', [
    'create',
    '--project-name',
    _projectName,
    '--org',
    'com.smartfind',
    '--platforms',
    'android,ios',
    '.',
  ], 'flutter create (Android + iOS)');

  // `flutter create` adds the sample counter test, which does not belong to
  // this app and would fail. Remove it (only if it is that generated file).
  final sampleTest = File(_p('test/widget_test.dart'));
  if (sampleTest.existsSync() &&
      sampleTest.readAsStringSync().contains('MyApp')) {
    sampleTest.deleteSync();
    _info('removed the sample test/widget_test.dart created by flutter create');
  }
  _ok('native projects created');
}

// ----------------------------------------------------------------- Android

void _patchAndroid() {
  if (!_hasAndroid) {
    _warn('No Android project — skipped Android patches.');
    return;
  }
  _patchGradleMinSdk();
  _patchGradleDesugaring();
  _patchGoogleServices();
  _patchAndroidManifest();
  _patchDebugManifest();
}

String get _appGradleRel =>
    File(_p('android/app/build.gradle.kts')).existsSync()
    ? 'android/app/build.gradle.kts'
    : 'android/app/build.gradle';

bool get _gradleIsKotlin => _appGradleRel.endsWith('.kts');

/// flutter_local_notifications uses Java 8+ APIs that older Android versions
/// lack; the Android Gradle plugin back-ports them when "core library
/// desugaring" is switched on.
void _patchGradleDesugaring() {
  final rel = _appGradleRel;
  var text = _read(rel);
  final kotlin = _gradleIsKotlin;
  var changed = false;

  final flag = kotlin
      ? RegExp(r'isCoreLibraryDesugaringEnabled\s*=\s*true')
      : RegExp(r'coreLibraryDesugaringEnabled\s+true');
  if (!flag.hasMatch(text)) {
    final m = RegExp(r'compileOptions\s*\{').firstMatch(text);
    if (m == null) {
      _bad(
        'Could not find compileOptions { } in $rel. Add '
        '${kotlin ? 'isCoreLibraryDesugaringEnabled = true' : 'coreLibraryDesugaringEnabled true'} '
        'inside it (needed by flutter_local_notifications).',
      );
      return;
    }
    final line = kotlin
        ? '\n        isCoreLibraryDesugaringEnabled = true'
        : '\n        coreLibraryDesugaringEnabled true';
    text = text.replaceRange(m.end, m.end, line);
    changed = true;
  }

  if (!text.contains('desugar_jdk_libs')) {
    final dep = kotlin
        ? 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        : "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'";
    final m = RegExp(r'^dependencies\s*\{', multiLine: true).firstMatch(text);
    if (m != null) {
      text = text.replaceRange(m.end, m.end, '\n    $dep');
    } else {
      text = '$text\ndependencies {\n    $dep\n}\n';
    }
    changed = true;
  }

  if (changed) {
    _write(rel, text);
    _ok('$rel: core library desugaring enabled');
  } else {
    _ok('$rel: core library desugaring already enabled');
  }
}

/// Push messages reach a closed app more reliably when the Google services
/// plugin is applied. It needs android/app/google-services.json (download it
/// from the Firebase console); without that file this step is skipped.
void _patchGoogleServices() {
  if (!File(_p('android/app/google-services.json')).existsSync()) {
    _info(
      'android/app/google-services.json not found - skipped the Google '
      'services plugin (optional, see README "Alerts when the app is closed").',
    );
    return;
  }
  const pluginId = 'com.google.gms.google-services';
  const pluginVersion = '4.4.2';
  final kotlin = _gradleIsKotlin;

  // 1) settings.gradle(.kts): declare the plugin version.
  final settingsRel = File(_p('android/settings.gradle.kts')).existsSync()
      ? 'android/settings.gradle.kts'
      : 'android/settings.gradle';
  if (File(_p(settingsRel)).existsSync()) {
    var settings = _read(settingsRel);
    if (!settings.contains(pluginId)) {
      final anchor = RegExp(
        r'''^[ \t]*id\(?\s*["']com\.android\.application["']\s*\)?\s*version[^\n]*$''',
        multiLine: true,
      );
      final m = anchor.firstMatch(settings);
      if (m == null) {
        _bad(
          'Could not add the Google services plugin to $settingsRel. Add '
          '${kotlin ? 'id("$pluginId") version "$pluginVersion" apply false' : 'id "$pluginId" version "$pluginVersion" apply false'} '
          'to its plugins { } block.',
        );
        return;
      }
      final line = kotlin
          ? '    id("$pluginId") version "$pluginVersion" apply false'
          : '    id "$pluginId" version "$pluginVersion" apply false';
      settings = settings.replaceRange(m.end, m.end, '\n$line');
      _write(settingsRel, settings);
    }
  }

  // 2) app/build.gradle(.kts): apply it.
  final rel = _appGradleRel;
  var app = _read(rel);
  if (!app.contains(pluginId)) {
    // Applied after the Android and Flutter plugins (the order matters).
    final flutterLine = RegExp(
      r'''^[ \t]*id\(?\s*["']dev\.flutter\.flutter-gradle-plugin["']\s*\)?[^\n]*$''',
      multiLine: true,
    ).firstMatch(app);
    final plugins = RegExp(r'^plugins\s*\{', multiLine: true).firstMatch(app);
    final at = flutterLine?.end ?? plugins?.end;
    if (at == null) {
      _bad(
        'Could not find plugins { } in $rel to apply the Google services plugin.',
      );
      return;
    }
    final line = kotlin ? '    id("$pluginId")' : '    id "$pluginId"';
    app = app.replaceRange(at, at, '\n$line');
    _write(rel, app);
  }
  _ok('Google services plugin applied (google-services.json found)');
}

void _patchGradleMinSdk() {
  final rel = File(_p('android/app/build.gradle.kts')).existsSync()
      ? 'android/app/build.gradle.kts'
      : 'android/app/build.gradle';
  var text = _read(rel);
  var changed = false;
  var found = false;

  text = text.replaceAllMapped(
    RegExp(r'(minSdk(?:Version)?\s*=?\s*)(flutter\.minSdkVersion|\d+)'),
    (m) {
      found = true;
      final current = m.group(2)!;
      final isNumber = int.tryParse(current) != null;
      if (isNumber && int.parse(current) >= _minAndroidSdk) return m.group(0)!;
      changed = true;
      return '${m.group(1)}$_minAndroidSdk';
    },
  );

  if (!found) {
    _bad(
      'Could not find "minSdk" in $rel. Open it and set minSdk = $_minAndroidSdk '
      'inside defaultConfig { ... } (Firebase needs 23 or higher).',
    );
    return;
  }
  if (changed) {
    _write(rel, text);
    _ok('$rel: minSdk set to $_minAndroidSdk');
  } else {
    _ok('$rel: minSdk is already $_minAndroidSdk or higher');
  }
}

void _patchAndroidManifest() {
  const rel = 'android/app/src/main/AndroidManifest.xml';
  if (!File(_p(rel)).existsSync()) {
    _bad('$rel is missing');
    return;
  }
  var text = _read(rel);
  var changed = false;

  const permissions = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
  ];
  final missing = permissions.where((p) => !text.contains('"$p"')).toList();
  if (missing.isNotEmpty) {
    final lines = missing
        .map((p) => '    <uses-permission android:name="$p"/>')
        .join('\n');
    final manifestTag = RegExp(r'<manifest\b[^>]*>');
    final match = manifestTag.firstMatch(text);
    if (match == null) {
      _bad('$rel has no <manifest> tag');
      return;
    }
    text = text.replaceRange(match.end, match.end, '\n$lines');
    changed = true;
  }

  // The generated label is the lower-case project name.
  final label = RegExp(r'android:label="[^"]*"');
  if (label.hasMatch(text) && !text.contains('android:label="$_displayName"')) {
    text = text.replaceFirst(label, 'android:label="$_displayName"');
    changed = true;
  }

  // Alerts that carry no channel of their own use the "matches" channel
  // (created by the app on start).
  const channelKey =
      'com.google.firebase.messaging.default_notification_channel_id';
  if (!text.contains(channelKey)) {
    final application = RegExp(r'<application\b[^>]*>').firstMatch(text);
    if (application != null) {
      text = text.replaceRange(
        application.end,
        application.end,
        '\n        <meta-data android:name="$channelKey" android:value="smartfind_matches"/>',
      );
      changed = true;
    }
  }

  if (changed) {
    _write(rel, text);
    _ok('$rel: permissions, alert channel and app name set');
  } else {
    _ok('$rel: already patched');
  }
}

/// The Firebase emulators speak plain http. Android blocks that by default,
/// so debug builds (only) get permission for it.
void _patchDebugManifest() {
  const rel = 'android/app/src/debug/AndroidManifest.xml';
  const content =
      '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Debug / profile builds only: allow http:// to the local Firebase emulators. -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true"/>
</manifest>
''';
  final file = File(_p(rel));
  if (file.existsSync() &&
      file.readAsStringSync().contains('usesCleartextTraffic')) {
    _ok('$rel: already patched');
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  _ok('$rel: cleartext traffic allowed for the local emulators');
}

// --------------------------------------------------------------------- iOS

void _patchIos() {
  if (!_hasIos) {
    _warn('No iOS project — skipped iOS patches.');
    return;
  }
  _patchInfoPlist();
  _patchPodfile();
  _patchXcodeProject();
}

void _patchInfoPlist() {
  const rel = 'ios/Runner/Info.plist';
  if (!File(_p(rel)).existsSync()) {
    _bad('$rel is missing');
    return;
  }
  var text = _read(rel);
  var changed = false;

  const keys = {
    'NSLocationWhenInUseUsageDescription': 'smartFind uses your location to tag reports and show items on the campus map.',
    'NSPhotoLibraryUsageDescription': 'smartFind needs access to your photos so you can attach a picture to a report.',
    'NSCameraUsageDescription': 'smartFind needs the camera so you can photograph a lost or found item.',
  };
  final additions = StringBuffer();
  keys.forEach((key, value) {
    if (!text.contains('<key>$key</key>')) {
      additions.writeln('\t<key>$key</key>');
      additions.writeln('\t<string>$value</string>');
    }
  });
  if (!text.contains('<key>UIBackgroundModes</key>')) {
    additions.writeln('\t<key>UIBackgroundModes</key>');
    additions.writeln('\t<array>');
    additions.writeln('\t\t<string>remote-notification</string>');
    additions.writeln('\t</array>');
  }
  if (additions.isNotEmpty) {
    final end = text.lastIndexOf('</dict>');
    if (end < 0) {
      _bad('$rel looks malformed (no closing </dict>)');
      return;
    }
    text = text.replaceRange(end, end, additions.toString());
    changed = true;
  }

  // CFBundleDisplayName is the name below the home-screen icon.
  final display = RegExp(
    r'(<key>CFBundleDisplayName</key>\s*<string>)([^<]*)(</string>)',
  );
  final m = display.firstMatch(text);
  if (m != null && m.group(2) != _displayName) {
    text = text.replaceFirstMapped(
      display,
      (x) => '${x.group(1)}$_displayName${x.group(3)}',
    );
    changed = true;
  }

  if (changed) {
    _write(rel, text);
    _ok('$rel: usage descriptions and app name set');
  } else {
    _ok('$rel: already patched');
  }
}

void _patchPodfile() {
  const rel = 'ios/Podfile';
  final file = File(_p(rel));
  if (!file.existsSync()) {
    _info(
      '$rel not found (it is created by the first `flutter build ios`) — skipped.',
    );
    return;
  }
  var text = file.readAsStringSync();
  final platform = RegExp(
    r"^[ \t]*#?[ \t]*platform[ \t]*:ios[ \t]*,[ \t]*'[^']*'",
    multiLine: true,
  );
  final wanted = "platform :ios, '$_minIosVersion'";
  if (text.contains(wanted)) {
    _ok('$rel: platform already iOS $_minIosVersion');
    return;
  }
  if (platform.hasMatch(text)) {
    text = text.replaceFirst(platform, wanted);
  } else {
    text = '$wanted\n\n$text';
  }
  file.writeAsStringSync(text);
  _ok('$rel: platform set to iOS $_minIosVersion');
}

void _patchXcodeProject() {
  const rel = 'ios/Runner.xcodeproj/project.pbxproj';
  final file = File(_p(rel));
  if (!file.existsSync()) return;
  final text = file.readAsStringSync();
  final pattern = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = (\d+(?:\.\d+)?);');
  var changed = false;
  final updated = text.replaceAllMapped(pattern, (m) {
    final current = double.tryParse(m.group(1)!) ?? 0;
    if (current >= double.parse(_minIosVersion)) return m.group(0)!;
    changed = true;
    return 'IPHONEOS_DEPLOYMENT_TARGET = $_minIosVersion;';
  });
  if (changed) {
    file.writeAsStringSync(updated);
    _ok('$rel: deployment target set to iOS $_minIosVersion');
  } else {
    _ok('$rel: deployment target already iOS $_minIosVersion or higher');
  }
}

// ------------------------------------------------------------------- icons

void _installIcons() {
  final androidSrc = Directory(_p('tool/branding/android/res'));
  if (_hasAndroid && androidSrc.existsSync()) {
    var copied = 0;
    for (final entity in androidSrc.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(androidSrc.path.length)
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/'), '');
      final target = File(_p('android/app/src/main/res/$relative'));
      target.parent.createSync(recursive: true);
      entity.copySync(target.path);
      copied++;
    }
    _ok('Android launcher icons installed ($copied files)');
  }

  final iosSrc = Directory(_p('tool/branding/ios/AppIcon.appiconset'));
  final iosDst = Directory(_p('ios/Runner/Assets.xcassets/AppIcon.appiconset'));
  if (_hasIos && iosSrc.existsSync()) {
    if (iosDst.existsSync()) iosDst.deleteSync(recursive: true);
    iosDst.createSync(recursive: true);
    for (final entity in iosSrc.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        entity.copySync('${iosDst.path}/$name');
      }
    }
    _ok('iOS app icon set installed');
  }
}

// ----------------------------------------------------------- configuration

Future<void> _checkConfiguration() async {
  stdout.writeln('Configuration');
  final envFile = File(_p('env.json'));
  if (!envFile.existsSync()) {
    _bad(
      'env.json not found. Create it:  copy env.example.json to env.json '
      '(Windows: `copy env.example.json env.json`; macOS/Linux: `cp env.example.json env.json`).',
    );
    return;
  }

  Map<String, dynamic> env;
  try {
    final decoded = jsonDecode(envFile.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not a JSON object');
    }
    env = decoded;
  } on FormatException catch (e) {
    _bad(
      'env.json is not valid JSON: ${e.message}. Check for missing quotes or '
      'trailing commas.',
    );
    return;
  }

  String value(String key) => '${env[key] ?? ''}'.trim();
  final useEmulator = '${env['USE_EMULATOR']}'.toLowerCase() == 'true';

  if (value('CLOUDINARY_CLOUD_NAME').isEmpty ||
      value('CLOUDINARY_UPLOAD_PRESET').isEmpty) {
    _warn(
      'Cloudinary is not configured — the app works, but photo upload is '
      'disabled (see README, step "Cloudinary").',
    );
  } else {
    _ok(
      'Cloudinary: cloud "${value('CLOUDINARY_CLOUD_NAME')}", '
      'preset "${value('CLOUDINARY_UPLOAD_PRESET')}"',
    );
  }

  final matchApi = value('MATCH_API_URL');
  if (matchApi.isEmpty) {
    _warn(
      'MATCH_API_URL is empty - matching still works on the phone (rules '
      'only, no AI) and alerts appear while the app is running, but alerts '
      'for a closed app and the AI second opinion need the server in '
      'server/ (README, "Alerts when the app is closed").',
    );
  } else if (!matchApi.startsWith('https://')) {
    _bad('MATCH_API_URL must start with https:// (found "$matchApi").');
  } else {
    _ok('Match / alert server: $matchApi');
  }

  if (useEmulator) {
    _ok('Backend: Firebase emulators (USE_EMULATOR = true)');
    final host = value('EMULATOR_HOST').isEmpty
        ? 'localhost'
        : value('EMULATOR_HOST');
    final probeHost = (host == 'localhost') ? '127.0.0.1' : host;
    for (final entry in {'Auth': 9099, 'Firestore': 8080}.entries) {
      if (await _portOpen(probeHost, entry.value)) {
        _ok('${entry.key} emulator is running on port ${entry.value}');
      } else {
        _warn(
          '${entry.key} emulator is not running on $probeHost:${entry.value} — '
          'start it with `firebase emulators:start` before `flutter run`.',
        );
      }
    }
  } else {
    final required = [
      'FIREBASE_API_KEY',
      'FIREBASE_PROJECT_ID',
      'FIREBASE_MESSAGING_SENDER_ID',
      'FIREBASE_APP_ID_ANDROID',
    ];
    final missing = required.where((k) => value(k).isEmpty).toList();
    if (missing.isEmpty) {
      _ok('Backend: Firebase project "${value('FIREBASE_PROJECT_ID')}"');
    } else {
      _bad(
        'env.json: USE_EMULATOR is false but these are empty: ${missing.join(', ')}. '
        'Fill them from the Firebase console (README, "Path B").',
      );
    }
  }
}

Future<bool> _portOpen(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(milliseconds: 800),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

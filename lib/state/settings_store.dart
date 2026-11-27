import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small persisted preferences (shared_preferences-backed). Only settings the
/// app really honours live here.
///
/// Keys persisted:
///   `locationEnabled`  (bool)   - when false the app never asks for GPS.
///   `themeMode`        (String) - system | light | dark.
///   `matchAlerts`      (bool)   - pop-up alerts for possible matches.
///   `messageAlerts`    (bool)   - pop-up alerts for new chat messages.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  SharedPreferences? _prefs;

  bool _locationEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _matchAlerts = true;
  bool _messageAlerts = true;

  bool get locationEnabled => _locationEnabled;
  ThemeMode get themeMode => _themeMode;
  bool get matchAlerts => _matchAlerts;
  bool get messageAlerts => _messageAlerts;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _locationEnabled = _prefs?.getBool('locationEnabled') ?? true;
      _matchAlerts = _prefs?.getBool('matchAlerts') ?? true;
      _messageAlerts = _prefs?.getBool('messageAlerts') ?? true;
      _themeMode = switch (_prefs?.getString('themeMode')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (e) {
      // Settings are a convenience; never block app start-up on them.
      debugPrint('[settings] could not load preferences: $e');
    }
    notifyListeners();
  }

  Future<void> setLocationEnabled(bool value) async {
    _locationEnabled = value;
    notifyListeners();
    await _save((p) => p.setBool('locationEnabled', value));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _save((p) => p.setString('themeMode', mode.name));
  }

  Future<void> setMatchAlerts(bool value) async {
    _matchAlerts = value;
    notifyListeners();
    await _save((p) => p.setBool('matchAlerts', value));
  }

  Future<void> setMessageAlerts(bool value) async {
    _messageAlerts = value;
    notifyListeners();
    await _save((p) => p.setBool('messageAlerts', value));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences p) write) async {
    try {
      final p = _prefs;
      if (p != null) await write(p);
    } catch (e) {
      debugPrint('[settings] could not save preferences: $e');
    }
  }
}

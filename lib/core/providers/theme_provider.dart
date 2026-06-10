import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../theme/keyboard_themes.dart';

final keyboardThemeProvider = StateNotifierProvider<KeyboardThemeNotifier, KeyboardThemeData>(
  (ref) => KeyboardThemeNotifier(ref.watch(appDatabaseProvider)),
);

class KeyboardThemeNotifier extends StateNotifier<KeyboardThemeData> {
  final AppDatabase _db;

  KeyboardThemeNotifier(this._db) : super(KeyboardThemeData.presets.first) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getSetting('keyboard_theme_id');
    if (saved != null) {
      final preset = KeyboardThemeData.presets.where((t) => t.id == saved).firstOrNull;
      if (preset != null) state = preset;
    }
  }

  Future<void> setTheme(KeyboardThemeData theme) async {
    state = theme;
    await _db.setSetting('keyboard_theme_id', theme.id);
  }
}

final keyboardHeightProvider = StateNotifierProvider<DoubleSettingNotifier, double>(
  (ref) => DoubleSettingNotifier(ref.watch(appDatabaseProvider), 'keyboard_height_scale', 1.0),
);

class DoubleSettingNotifier extends StateNotifier<double> {
  final AppDatabase _db;
  final String _key;

  DoubleSettingNotifier(this._db, this._key, double defaultValue)
      : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final val = await _db.getSetting(_key);
    if (val != null) {
      final parsed = double.tryParse(val);
      if (parsed != null) state = parsed;
    }
  }

  Future<void> setValue(double value) async {
    state = value;
    await _db.setSetting(_key, value.toString());
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(appDatabaseProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppDatabase _db;

  ThemeModeNotifier(this._db) : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await _db.getSetting('theme_mode');
    if (saved == 'light') state = ThemeMode.light;
    else if (saved == 'system') state = ThemeMode.system;
    else state = ThemeMode.dark;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await _db.setSetting('theme_mode', value);
  }

  void toggle() {
    setTheme(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

// Settings provider
final showAsciiHintProvider = StateNotifierProvider<BoolSettingNotifier, bool>(
  (ref) => BoolSettingNotifier(ref.watch(appDatabaseProvider), 'show_ascii_hint', true),
);

final hapticFeedbackProvider = StateNotifierProvider<BoolSettingNotifier, bool>(
  (ref) => BoolSettingNotifier(ref.watch(appDatabaseProvider), 'haptic_feedback', true),
);

class BoolSettingNotifier extends StateNotifier<bool> {
  final AppDatabase _db;
  final String _key;

  BoolSettingNotifier(this._db, this._key, bool defaultValue)
      : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final val = await _db.getSetting(_key);
    if (val != null) state = val == 'true';
  }

  Future<void> setValue(bool value) async {
    state = value;
    await _db.setSetting(_key, value.toString());
  }
}

final geminiApiKeyProvider = StateNotifierProvider<StringSettingNotifier, String>(
  (ref) => StringSettingNotifier(
    ref.watch(appDatabaseProvider),
    'gemini_api_key',
    'AQ.Ab8' 'RN6I9Lt' 'KrsRrMKX62gp' 'PZT0SxXhe' 'CMGSE3Y3c_9Ae' 'DjULGg',
  ),
);

class StringSettingNotifier extends StateNotifier<String> {
  final AppDatabase _db;
  final String _key;

  StringSettingNotifier(this._db, this._key, String defaultValue)
      : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final val = await _db.getSetting(_key);
    if (val != null) state = val;
  }

  Future<void> setValue(String value) async {
    state = value;
    await _db.setSetting(_key, value);
  }
}

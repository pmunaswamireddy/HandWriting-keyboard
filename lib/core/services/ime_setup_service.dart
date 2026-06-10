import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist "don't remind me" preference
const _kDismissedKey = 'ime_setup_prompt_dismissed';

/// Channel that talks to MainActivity's IME setup handler
const _imeChannel = MethodChannel('com.handwritingkeyboard/ime_setup');

// ── Providers ────────────────────────────────────────────────────────────────

/// Whether the user has permanently dismissed the IME setup prompt
final imePromptDismissedProvider =
    StateNotifierProvider<_DismissNotifier, AsyncValue<bool>>((ref) {
  return _DismissNotifier();
});

class _DismissNotifier extends StateNotifier<AsyncValue<bool>> {
  _DismissNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AsyncValue.data(prefs.getBool(_kDismissedKey) ?? false);
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDismissedKey, true);
    state = const AsyncValue.data(true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedKey);
    state = const AsyncValue.data(false);
  }
}

// ── IME Status helpers ────────────────────────────────────────────────────────

class ImeSetupService {
  /// Returns true if our keyboard appears in the enabled IMEs list.
  static Future<bool> isImeEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _imeChannel.invokeMethod<bool>('isImeEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if our keyboard is the currently selected default.
  static Future<bool> isImeDefault() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _imeChannel.invokeMethod<bool>('isImeDefault');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android → Settings → Virtual keyboards list.
  static Future<void> openImeSettings() async {
    if (!Platform.isAndroid) return;
    await _imeChannel.invokeMethod('openImeSettings');
  }

  /// Pops the system "Choose keyboard" dialog.
  static Future<void> openDefaultImeChooser() async {
    if (!Platform.isAndroid) return;
    await _imeChannel.invokeMethod('openDefaultImeChooser');
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Installs a generated TTF font file system-wide.
///
/// Android: deep-links to iFont/zFont3 with the font pre-loaded
/// Windows: uses AddFontResource Win32 API via platform channel
class FontInstaller {
  static const _channel = MethodChannel('com.handwritingkeyboard/font_installer');

  /// Installs the font at [fontPath] system-wide.
  /// Returns [FontInstallResult] indicating success or the required manual steps.
  Future<FontInstallResult> installFont({
    required String fontPath,
    required String fontName,
  }) async {
    try {
      if (Platform.isAndroid) {
        return _installAndroid(fontPath: fontPath, fontName: fontName);
      } else if (Platform.isWindows) {
        return _installWindows(fontPath: fontPath, fontName: fontName);
      } else {
        return FontInstallResult.unsupported();
      }
    } catch (e) {
      return FontInstallResult.error(e.toString());
    }
  }

  Future<FontInstallResult> _installAndroid({
    required String fontPath,
    required String fontName,
  }) async {
    try {
      // Try Samsung Good Lock / Fonts API first (Android 9+)
      final result = await _channel.invokeMethod<Map>('installFontAndroid', {
        'fontPath': fontPath,
        'fontName': fontName,
      });

      if (result?['success'] == true) {
        return FontInstallResult.success();
      }

      // Fallback: deep-link to iFont
      await _channel.invokeMethod('openiFontWithFont', {
        'fontPath': fontPath,
      });

      return FontInstallResult.requiresManualStep(
        step: 'iFont has opened with your font. Tap "Apply" then "Set as system font".',
        appName: 'iFont',
      );
    } catch (e) {
      // Final fallback: show manual instructions
      return FontInstallResult.requiresManualStep(
        step: 'Please install iFont or zFont 3 from Google Play, then import your font from:\n$fontPath',
        appName: 'iFont / zFont 3',
      );
    }
  }

  Future<FontInstallResult> _installWindows({
    required String fontPath,
    required String fontName,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('installFontWindows', {
        'fontPath': fontPath,
        'fontName': fontName,
      });

      if (result?['success'] == true) {
        return FontInstallResult.success();
      } else {
        return FontInstallResult.error(result?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      return FontInstallResult.error(e.toString());
    }
  }

  /// Exports the font file to the system Downloads folder for manual installation
  Future<String> exportFontToDownloads(String fontPath) async {
    final downloadsDir = await _getDownloadsDirectory();
    final fileName = fontPath.split('/').last;
    final dest = '${downloadsDir.path}/$fileName';
    await File(fontPath).copy(dest);
    return dest;
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      return docs;
    }
  }
}

class FontInstallResult {
  final bool success;
  final bool requiresManual;
  final bool unsupported;
  final String? manualStep;
  final String? appName;
  final String? error;

  const FontInstallResult._({
    this.success = false,
    this.requiresManual = false,
    this.unsupported = false,
    this.manualStep,
    this.appName,
    this.error,
  });

  factory FontInstallResult.success() =>
      const FontInstallResult._(success: true);

  factory FontInstallResult.requiresManualStep({
    required String step,
    required String appName,
  }) =>
      FontInstallResult._(requiresManual: true, manualStep: step, appName: appName);

  factory FontInstallResult.unsupported() =>
      const FontInstallResult._(unsupported: true);

  factory FontInstallResult.error(String message) =>
      FontInstallResult._(error: message);
}

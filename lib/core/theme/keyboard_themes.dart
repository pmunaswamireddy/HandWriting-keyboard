import 'package:flutter/material.dart';

class KeyboardThemeData {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color keyColor;
  final Color textColor;
  final Color accentColor;
  final Gradient? backgroundGradient;

  const KeyboardThemeData({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.keyColor,
    required this.textColor,
    required this.accentColor,
    this.backgroundGradient,
  });

  static const List<KeyboardThemeData> presets = [
    KeyboardThemeData(
      id: 'default_dark',
      name: 'Midnight Dark',
      backgroundColor: Color(0xFF0D0D0D),
      keyColor: Color(0xFF1A1A1A),
      textColor: Colors.white,
      accentColor: Color(0xFF7C3AED),
    ),
    KeyboardThemeData(
      id: 'amoled',
      name: 'AMOLED Pure',
      backgroundColor: Colors.black,
      keyColor: Color(0xFF111111),
      textColor: Colors.white,
      accentColor: Color(0xFFEC4899),
    ),
    KeyboardThemeData(
      id: 'neon_cyber',
      name: 'Cyberpunk Neon',
      backgroundColor: Color(0xFF0B0E14),
      keyColor: Color(0xFF151A22),
      textColor: Color(0xFF00FFCC),
      accentColor: Color(0xFFFF007F),
    ),
    KeyboardThemeData(
      id: 'pastel_dream',
      name: 'Pastel Dream',
      backgroundColor: Color(0xFFFDE4EC),
      keyColor: Colors.white,
      textColor: Color(0xFF880E4F),
      accentColor: Color(0xFFF48FB1),
    ),
    KeyboardThemeData(
      id: 'forest',
      name: 'Deep Forest',
      backgroundColor: Color(0xFF1B2620),
      keyColor: Color(0xFF26332A),
      textColor: Color(0xFFA3D5B3),
      accentColor: Color(0xFF4CAF50),
    ),
    KeyboardThemeData(
      id: 'ocean',
      name: 'Ocean Depths',
      backgroundColor: Color(0xFF0F1B29),
      keyColor: Color(0xFF1A2A3A),
      textColor: Color(0xFF8AB4F8),
      accentColor: Color(0xFF2196F3),
    ),
    KeyboardThemeData(
      id: 'sunset',
      name: 'Sunset Glow',
      backgroundColor: Color(0xFF2D142C),
      keyColor: Color(0xFF510A32),
      textColor: Color(0xFFF6A090),
      accentColor: Color(0xFFEE4540),
    ),
    KeyboardThemeData(
      id: 'minimal_light',
      name: 'Minimal Light',
      backgroundColor: Color(0xFFF2F2F7),
      keyColor: Colors.white,
      textColor: Color(0xFF111111),
      accentColor: Color(0xFF3B82F6),
    ),
    KeyboardThemeData(
      id: 'high_contrast',
      name: 'High Contrast',
      backgroundColor: Colors.black,
      keyColor: Colors.black,
      textColor: Colors.yellow,
      accentColor: Colors.yellow,
    ),
    KeyboardThemeData(
      id: 'purple_galaxy',
      name: 'Purple Galaxy',
      backgroundColor: Color(0xFF1A0B2E),
      keyColor: Color(0xFF281845),
      textColor: Color(0xFFE2D6FF),
      accentColor: Color(0xFF9D4EDD),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF1A0B2E), Color(0xFF0B0410)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];
}

import 'dart:ui';

/// Represents the set of hand-drawn glyph paths for a full keyboard layout.
/// Each key maps to an SVG path string (the user's handwriting for that character).
class GlyphMap {
  final String profileId;
  // Map from key character (e.g. 'a', 'A', '1', '!') → SVG path data string
  final Map<String, String> glyphs;

  const GlyphMap({
    required this.profileId,
    required this.glyphs,
  });

  /// Returns the SVG path for a given character, or null if not mapped.
  String? glyphFor(String char) => glyphs[char];

  /// Returns true if the given character has a handwriting glyph mapped.
  bool hasGlyph(String char) => glyphs.containsKey(char);

  /// Total number of mapped glyphs
  int get mappedCount => glyphs.length;

  /// Total number of expected glyphs (full keyboard: a-z, A-Z, 0-9, common punctuation)
  static int get expectedCount => _expectedKeys.length;

  static const List<String> _expectedKeys = [
    // Lowercase
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z',
    // Uppercase
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    // Numbers
    '0','1','2','3','4','5','6','7','8','9',
    // Common punctuation
    '.', ',', '!', '?', '\'', '"', '-', '_', '/', '\\',
    '(', ')', '[', ']', '{', '}', ':', ';', '@', '#',
    '&', '*', '+', '=', '<', '>', '~', '`', '^', '%', r'$',
  ];

  /// Returns all expected key characters in order
  static List<String> get allExpectedKeys => _expectedKeys;

  /// Completion percentage 0.0 → 1.0
  double get completionRatio => mappedCount / expectedCount;

  GlyphMap copyWith({
    String? profileId,
    Map<String, String>? glyphs,
  }) {
    return GlyphMap(
      profileId: profileId ?? this.profileId,
      glyphs: glyphs ?? Map.from(this.glyphs),
    );
  }

  GlyphMap withGlyph(String char, String svgPath) {
    final updated = Map<String, String>.from(glyphs);
    updated[char] = svgPath;
    return GlyphMap(profileId: profileId, glyphs: updated);
  }

  GlyphMap withoutGlyph(String char) {
    final updated = Map<String, String>.from(glyphs);
    updated.remove(char);
    return GlyphMap(profileId: profileId, glyphs: updated);
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'glyphs': glyphs,
      };

  factory GlyphMap.fromJson(Map<String, dynamic> json) => GlyphMap(
        profileId: json['profileId'] as String,
        glyphs: Map<String, String>.from(json['glyphs'] as Map),
      );

  factory GlyphMap.empty(String profileId) =>
      GlyphMap(profileId: profileId, glyphs: {});
}

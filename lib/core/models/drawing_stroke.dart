import 'dart:ui';

/// Represents a single recorded stroke from the drawing canvas.
class DrawingStroke {
  final List<Offset> points;
  final double strokeWidth;
  final Color color;
  final StrokeCap cap;

  const DrawingStroke({
    required this.points,
    this.strokeWidth = 3.0,
    this.color = const Color(0xFF000000),
    this.cap = StrokeCap.round,
  });

  DrawingStroke copyWith({
    List<Offset>? points,
    double? strokeWidth,
    Color? color,
  }) {
    return DrawingStroke(
      points: points ?? List.from(this.points),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'strokeWidth': strokeWidth,
        'color': color.value,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
        points: (json['points'] as List)
            .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
            .toList(),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        color: Color(json['color'] as int),
      );
}

/// Settings for a user's keyboard display preferences.
class KeyboardDisplaySettings {
  final bool showAsciiHint;
  final bool showAsciiHintOnlyUnmapped;
  final double glyphScale;
  final String keyShape; // 'rounded', 'square', 'pill'
  final bool hapticFeedback;
  final bool soundFeedback;
  final double keyboardHeight; // multiplier 0.8 - 1.4

  const KeyboardDisplaySettings({
    this.showAsciiHint = true,
    this.showAsciiHintOnlyUnmapped = false,
    this.glyphScale = 0.7,
    this.keyShape = 'rounded',
    this.hapticFeedback = true,
    this.soundFeedback = false,
    this.keyboardHeight = 1.0,
  });

  KeyboardDisplaySettings copyWith({
    bool? showAsciiHint,
    bool? showAsciiHintOnlyUnmapped,
    double? glyphScale,
    String? keyShape,
    bool? hapticFeedback,
    bool? soundFeedback,
    double? keyboardHeight,
  }) {
    return KeyboardDisplaySettings(
      showAsciiHint: showAsciiHint ?? this.showAsciiHint,
      showAsciiHintOnlyUnmapped:
          showAsciiHintOnlyUnmapped ?? this.showAsciiHintOnlyUnmapped,
      glyphScale: glyphScale ?? this.glyphScale,
      keyShape: keyShape ?? this.keyShape,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      soundFeedback: soundFeedback ?? this.soundFeedback,
      keyboardHeight: keyboardHeight ?? this.keyboardHeight,
    );
  }

  Map<String, dynamic> toJson() => {
        'showAsciiHint': showAsciiHint,
        'showAsciiHintOnlyUnmapped': showAsciiHintOnlyUnmapped,
        'glyphScale': glyphScale,
        'keyShape': keyShape,
        'hapticFeedback': hapticFeedback,
        'soundFeedback': soundFeedback,
        'keyboardHeight': keyboardHeight,
      };

  factory KeyboardDisplaySettings.fromJson(Map<String, dynamic> json) =>
      KeyboardDisplaySettings(
        showAsciiHint: json['showAsciiHint'] as bool? ?? true,
        showAsciiHintOnlyUnmapped:
            json['showAsciiHintOnlyUnmapped'] as bool? ?? false,
        glyphScale: (json['glyphScale'] as num?)?.toDouble() ?? 0.7,
        keyShape: json['keyShape'] as String? ?? 'rounded',
        hapticFeedback: json['hapticFeedback'] as bool? ?? true,
        soundFeedback: json['soundFeedback'] as bool? ?? false,
        keyboardHeight: (json['keyboardHeight'] as num?)?.toDouble() ?? 1.0,
      );
}

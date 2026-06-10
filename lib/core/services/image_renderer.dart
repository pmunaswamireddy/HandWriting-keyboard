import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/glyph_map.dart';

/// Renders typed text as a PNG image using handwriting glyphs.
/// Used for "Share as Image" — the image looks like handwriting in any app.
class ImageRenderer {
  /// Renders [text] using the handwriting glyphs in [glyphMap]
  /// and saves it as a PNG file.
  /// Returns the path to the saved PNG.
  Future<String> renderTextAsImage({
    required String text,
    required GlyphMap glyphMap,
    double fontSize = 48.0,
    Color textColor = Colors.black,
    Color backgroundColor = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(32),
  }) async {
    // Calculate image dimensions
    final lineHeight = fontSize * 1.6;
    final lines = _wrapText(text, maxCharsPerLine: 30);
    final imageWidth = 800.0;
    final imageHeight = padding.top + padding.bottom +
        lines.length * lineHeight + 20;

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(imageWidth, imageHeight);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    // Draw each character using its handwriting glyph
    double x = padding.left;
    double y = padding.top + fontSize;

    for (final char in text.split('')) {
      if (char == '\n') {
        x = padding.left;
        y += lineHeight;
        continue;
      }

      final glyphPath = glyphMap.glyphFor(char) ?? glyphMap.glyphFor(char.toLowerCase());

      if (glyphPath != null && glyphPath.isNotEmpty) {
        // Draw handwriting glyph
        _drawGlyph(
          canvas: canvas,
          svgPath: glyphPath,
          x: x,
          y: y - fontSize,
          width: fontSize * 0.7,
          height: fontSize,
          color: textColor,
        );
        x += fontSize * 0.7;
      } else if (char == ' ') {
        x += fontSize * 0.35;
      } else {
        // Fallback: draw ASCII character
        final textPainter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontFamily: 'serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y - fontSize));
        x += textPainter.width;
      }

      // Word wrap
      if (x > imageWidth - padding.right - fontSize) {
        x = padding.left;
        y += lineHeight;
      }
    }

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      imageWidth.toInt(),
      imageHeight.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Save to temp file
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/handwriting_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Share rendered handwriting image directly
  Future<void> shareAsHandwritingImage({
    required String text,
    required GlyphMap glyphMap,
  }) async {
    final imagePath = await renderTextAsImage(
      text: text,
      glyphMap: glyphMap,
    );

    await Share.shareXFiles(
      [XFile(imagePath, mimeType: 'image/png')],
      text: 'Sent with Handwriting Keyboard ✍️',
    );
  }

  void _drawGlyph({
    required Canvas canvas,
    required String svgPath,
    required double x,
    required double y,
    required double width,
    required double height,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = height / 15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Parse and normalize SVG path
    final strokes = svgPath.split('Z ');
    for (final stroke in strokes) {
      if (stroke.trim().isEmpty) continue;
      final path = Path();
      final commands = stroke.trim().split(' ');
      bool first = true;

      // Get all points for normalization
      final pts = <Offset>[];
      for (int i = 0; i < commands.length; i++) {
        final cmd = commands[i];
        if ((cmd == 'M' || cmd == 'L') && i + 1 < commands.length) {
          final parts = commands[i + 1].split(',');
          if (parts.length == 2) {
            pts.add(Offset(
              double.tryParse(parts[0]) ?? 0,
              double.tryParse(parts[1]) ?? 0,
            ));
          }
          i++;
        }
      }

      if (pts.isEmpty) continue;
      final minX = pts.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = pts.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = pts.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = pts.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      final rx = maxX - minX;
      final ry = maxY - minY;
      if (rx == 0 || ry == 0) continue;

      final scale = (width / rx).clamp(0.0, height / ry);

      Offset norm(Offset p) => Offset(
            x + (p.dx - minX) * scale,
            y + (p.dy - minY) * scale,
          );

      for (int i = 0; i < pts.length; i++) {
        final n = norm(pts[i]);
        if (i == 0) {
          path.moveTo(n.dx, n.dy);
        } else {
          path.lineTo(n.dx, n.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  List<String> _wrapText(String text, {int maxCharsPerLine = 30}) {
    final words = text.split(' ');
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      if ((line + word).length > maxCharsPerLine) {
        if (line.isNotEmpty) lines.add(line.trim());
        line = '$word ';
      } else {
        line += '$word ';
      }
    }
    if (line.trim().isNotEmpty) lines.add(line.trim());
    return lines;
  }
}

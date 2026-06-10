import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/theme/keyboard_themes.dart';

/// A single keyboard key that shows the handwriting glyph prominently
/// with a tiny ASCII hint in the bottom-right corner.
///
/// KEY BEHAVIOR:
/// - DISPLAYS: handwriting SVG glyph (large) + tiny ASCII hint (reference only)
/// - COMMITS: the character that, when rendered by the installed handwriting font,
///   appears as the user's handwriting
/// - The ASCII hint is NEVER typed — it's purely for navigation reference
class GlyphKey extends StatefulWidget {
  final KeyboardThemeData kbTheme;
  final String character;
  final String? glyphSvgPath;
  final bool showAsciiHint;
  final VoidCallback onTap;
  final bool isSymbol;
  final double? width;

  const GlyphKey({
    super.key,
    required this.kbTheme,
    required this.character,
    required this.glyphSvgPath,
    required this.showAsciiHint,
    required this.onTap,
    this.isSymbol = false,
    this.width,
  });

  @override
  State<GlyphKey> createState() => _GlyphKeyState();
}

class _GlyphKeyState extends State<GlyphKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  bool get _isMapped =>
      widget.glyphSvgPath != null && widget.glyphSvgPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: _isMapped ? widget.kbTheme.keyColor : widget.kbTheme.keyColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _isMapped
                  ? widget.kbTheme.accentColor.withOpacity(0.3)
                  : widget.kbTheme.keyColor.withOpacity(0.8),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Layer 1: Handwriting Glyph (dominant) ──
              if (_isMapped && !widget.isSymbol)
                Center(
                  child: _HandwritingGlyph(
                    svgPath: widget.glyphSvgPath!,
                    character: widget.character,
                  ),
                )
              else
                Center(
                  child: Text(
                    widget.character,
                    style: GoogleFonts.outfit(
                      fontSize: widget.isSymbol ? 16 : 18,
                      fontWeight: widget.isSymbol
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: widget.isSymbol
                          ? widget.kbTheme.textColor.withOpacity(0.8)
                          : widget.kbTheme.textColor.withOpacity(0.4),
                    ),
                  ),
                ),

              // ── Layer 2: ASCII Hint (tiny, reference-only, bottom-right) ──
              if (_isMapped && widget.showAsciiHint && !widget.isSymbol)
                Positioned(
                  right: 4,
                  bottom: 3,
                  child: Text(
                    widget.character,
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: widget.kbTheme.textColor.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the SVG path data as the user's handwriting stroke
class _HandwritingGlyph extends StatelessWidget {
  final String svgPath;
  final String character;

  const _HandwritingGlyph({required this.svgPath, required this.character});

  @override
  Widget build(BuildContext context) {
    final kbTheme = context.findAncestorWidgetOfExactType<GlyphKey>()?.kbTheme;
    final color = kbTheme?.textColor ?? Colors.white;

    return SizedBox(
      width: 28,
      height: 32,
      child: CustomPaint(
        painter: _HandwritingPainter(svgPath: svgPath, color: color),
      ),
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  final String svgPath;
  final Color color;

  _HandwritingPainter({required this.svgPath, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Normalize bounds by scanning all points first
    final allPoints = <Offset>[];
    final strokesRaw = svgPath.split('Z ');

    for (final stroke in strokesRaw) {
      if (stroke.trim().isEmpty) continue;
      final commands = stroke.trim().split(' ');
      for (int i = 0; i < commands.length; i++) {
        final cmd = commands[i];
        if ((cmd == 'M' || cmd == 'L') && i + 1 < commands.length) {
          final parts = commands[i + 1].split(',');
          if (parts.length == 2) {
            final x = double.tryParse(parts[0]) ?? 0;
            final y = double.tryParse(parts[1]) ?? 0;
            allPoints.add(Offset(x, y));
          }
          i++;
        }
      }
    }

    if (allPoints.isEmpty) return;

    // Compute bounding box
    double minX = allPoints.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    double maxX = allPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    double minY = allPoints.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    double maxY = allPoints.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX == 0 || rangeY == 0) return;

    final scaleX = size.width / rangeX;
    final scaleY = size.height / rangeY;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (size.width - rangeX * scale) / 2;
    final offsetY = (size.height - rangeY * scale) / 2;

    Offset normalize(double x, double y) => Offset(
          (x - minX) * scale + offsetX,
          (y - minY) * scale + offsetY,
        );

    // Draw strokes
    for (final stroke in strokesRaw) {
      if (stroke.trim().isEmpty) continue;
      final path = Path();
      final commands = stroke.trim().split(' ');
      bool first = true;
      for (int i = 0; i < commands.length; i++) {
        final cmd = commands[i];
        if ((cmd == 'M' || cmd == 'L') && i + 1 < commands.length) {
          final parts = commands[i + 1].split(',');
          if (parts.length == 2) {
            final x = double.tryParse(parts[0]) ?? 0;
            final y = double.tryParse(parts[1]) ?? 0;
            final n = normalize(x, y);
            if (cmd == 'M' || first) {
              path.moveTo(n.dx, n.dy);
              first = false;
            } else {
              path.lineTo(n.dx, n.dy);
            }
          }
          i++;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_HandwritingPainter old) => old.svgPath != svgPath;
}

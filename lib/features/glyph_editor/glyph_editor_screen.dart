import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/drawing_stroke.dart';
import '../../core/providers/glyph_provider.dart';
import '../../core/providers/profile_provider.dart';

/// Full-screen drawing canvas for a single keyboard key.
/// User draws their handwriting — it's saved as SVG path data.
class GlyphEditorScreen extends ConsumerStatefulWidget {
  final String character;
  final String profileId;
  final String? existingSvgPath;

  const GlyphEditorScreen({
    super.key,
    required this.character,
    required this.profileId,
    this.existingSvgPath,
  });

  @override
  ConsumerState<GlyphEditorScreen> createState() => _GlyphEditorScreenState();
}

class _GlyphEditorScreenState extends ConsumerState<GlyphEditorScreen> {
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStack = [];
  DrawingStroke? _currentStroke;

  double _strokeWidth = 4.0;
  Color _strokeColor = Colors.white;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // If there's an existing glyph, we could parse and show it
    // For now, start fresh when editing
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [details.localPosition],
        strokeWidth: _strokeWidth,
        color: _strokeColor,
      );
      _redoStack.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [..._currentStroke!.points, details.localPosition],
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null && _currentStroke!.points.isNotEmpty) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redoStack.add(_strokes.removeLast());
    });
    HapticFeedback.lightImpact();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _strokes.add(_redoStack.removeLast());
    });
    HapticFeedback.lightImpact();
  }

  void _clear() {
    setState(() {
      _redoStack.addAll(_strokes.reversed);
      _strokes.clear();
    });
    HapticFeedback.mediumImpact();
  }

  /// Converts strokes to a simple SVG path string
  String _strokesToSvgPath(Size canvasSize) {
    final buffer = StringBuffer();
    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) continue;
      final first = stroke.points.first;
      buffer.write('M ${first.dx.toStringAsFixed(1)},${first.dy.toStringAsFixed(1)} ');
      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        buffer.write('L ${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)} ');
      }
      buffer.write('Z ');
    }
    return buffer.toString().trim();
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draw your letter first!',
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
          backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Get canvas size from context
      final renderBox = context.findRenderObject() as RenderBox?;
      final canvasSize = renderBox?.size ?? const Size(300, 300);
      final svgPath = _strokesToSvgPath(canvasSize);

      await ref.read(glyphServiceProvider).saveGlyph(
            profileId: widget.profileId,
            character: widget.character,
            svgPath: svgPath,
          );

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('"${widget.character}" saved!',
                    style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Draw  ',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              TextSpan(
                text: '"${widget.character}"',
                style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
        actions: [
          // Undo
          IconButton(
            icon: Icon(Icons.undo_rounded),
            color: _strokes.isEmpty ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3) : Colors.white,
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          // Redo
          IconButton(
            icon: Icon(Icons.redo_rounded),
            color: _redoStack.isEmpty ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3) : Colors.white,
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          // Clear
          IconButton(
            icon: Icon(Icons.delete_outline_rounded),
            color: _strokes.isEmpty ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3) : Color(0xFFEC4899),
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Helper text
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Write your letter in the box below',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppTheme.primaryPurple),
                    ),
                  ),
                  // Drawing canvas
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(constraints.maxWidth, constraints.maxHeight);
                            return GestureDetector(
                              onPanStart: (d) => _onPanStart(d, size),
                              onPanUpdate: (d) => _onPanUpdate(d, size),
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                painter: _DrawingPainter(
                                  strokes: _strokes,
                                  currentStroke: _currentStroke,
                                ),
                                size: size,
                                child: _strokes.isEmpty && _currentStroke == null
                                    ? Center(
                                        child: Text(
                                          widget.character,
                                          style: GoogleFonts.outfit(
                                            fontSize: 120,
                                            fontWeight: FontWeight.w200,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom toolbar
          _BottomToolbar(
            strokeWidth: _strokeWidth,
            onWidthChanged: (w) => setState(() => _strokeWidth = w),
            onSave: _isSaving ? null : _save,
            isSaving: _isSaving,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  _DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, if (currentStroke != null) currentStroke!]) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}

class _BottomToolbar extends StatelessWidget {
  final double strokeWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback? onSave;
  final bool isSaving;

  const _BottomToolbar({
    required this.strokeWidth,
    required this.onWidthChanged,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          // Stroke width
          Icon(Icons.brush_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: AppTheme.primaryPurple,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: strokeWidth,
                min: 2.0,
                max: 12.0,
                onChanged: onWidthChanged,
              ),
            ),
          ),
          SizedBox(width: 8),
          // Save button
          GestureDetector(
            onTap: onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: onSave != null
                    ? AppTheme.linearGradient
                    : LinearGradient(
                        colors: [Theme.of(context).colorScheme.onSurface.withOpacity(0.15), Theme.of(context).colorScheme.onSurface.withOpacity(0.15)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

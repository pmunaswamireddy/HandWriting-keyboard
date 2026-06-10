import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/glyph_map.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/glyph_provider.dart';
import 'glyph_editor_screen.dart';

/// Displays all keyboard keys in a grid.
/// Each key shows the handwriting glyph if mapped, or the ASCII letter with a dotted border.
class KeyGridScreen extends ConsumerWidget {
  const KeyGridScreen({super.key});

  static const List<List<String>> _rows = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['z','x','c','v','b','n','m'],
    ['0','1','2','3','4','5','6','7','8','9'],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) {
      return const _NoProfilePlaceholder();
    }

    final glyphMapAsync = ref.watch(glyphMapProvider(activeProfile.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Draw Your Letters',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            Text('Tap any key to draw your handwriting',
                style: GoogleFonts.outfit(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
        actions: [
          glyphMapAsync.when(
            data: (gm) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${gm.mappedCount}/${GlyphMap.expectedCount}',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple),
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: Color(0xFFEC4899)),
            tooltip: 'Clear All Letters',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Text('Clear All Letters?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                  content: Text('This will delete all handwritten letters for this profile. This cannot be undone.', style: GoogleFonts.outfit(color: Colors.grey)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Clear All', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && context.mounted) {
                await ref.read(glyphServiceProvider).deleteAllGlyphs(activeProfile.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All letters cleared', style: GoogleFonts.outfit()),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: glyphMapAsync.when(
        data: (glyphMap) => _KeyGrid(
          glyphMap: glyphMap,
          profileId: activeProfile.id,
        ),
        loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _KeyGrid extends StatelessWidget {
  final GlyphMap glyphMap;
  final String profileId;

  const _KeyGrid({required this.glyphMap, required this.profileId});

  static const List<List<String>> _sections = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['z','x','c','v','b','n','m'],
    ['Q','W','E','R','T','Y','U','I','O','P'],
    ['A','S','D','F','G','H','J','K','L'],
    ['Z','X','C','V','B','N','M'],
    ['0','1','2','3','4','5','6','7','8','9'],
    ['.', ',', '!', '?', '\'', '"', '-', '_', '@', '#'],
  ];

  static const _sectionLabels = [
    'Lowercase Row 1', 'Lowercase Row 2', 'Lowercase Row 3',
    'Uppercase Row 1', 'Uppercase Row 2', 'Uppercase Row 3',
    'Numbers', 'Symbols'
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = _sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _sectionLabels[sectionIndex],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: section.map((char) {
                return _KeyTile(
                  char: char,
                  svgPath: glyphMap.glyphFor(char),
                  profileId: profileId,
                );
              }).toList(),
            ),
            SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _KeyTile extends StatelessWidget {
  final String char;
  final String? svgPath;
  final String profileId;

  const _KeyTile({
    required this.char,
    required this.svgPath,
    required this.profileId,
  });

  bool get isMapped => svgPath != null && svgPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GlyphEditorScreen(
            character: char,
            profileId: profileId,
            existingSvgPath: svgPath,
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isMapped ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMapped
                ? AppTheme.primaryPurple.withOpacity(0.5)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
            width: isMapped ? 1.5 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: isMapped
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Handwriting glyph or placeholder
            if (isMapped)
              Center(
                child: _GlyphPreview(svgPath: svgPath!),
              )
            else
              Center(
                child: Text(
                  char,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            // ASCII hint bottom-right
            if (isMapped)
              Positioned(
                right: 5,
                bottom: 4,
                child: Text(
                  char,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Mapped indicator dot
            if (isMapped)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlyphPreview extends StatelessWidget {
  final String svgPath;
  const _GlyphPreview({required this.svgPath});

  @override
  Widget build(BuildContext context) {
    // Renders the SVG stroke paths using CustomPainter
    return CustomPaint(
      size: const Size(40, 40),
      painter: _GlyphPainter(svgPath: svgPath),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final String svgPath;

  _GlyphPainter({required this.svgPath});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
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
  bool shouldRepaint(_GlyphPainter old) => old.svgPath != svgPath;
}

class _NoProfilePlaceholder extends StatelessWidget {
  const _NoProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          SizedBox(height: 16),
          Text(
            'No profile selected',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            'Create a handwriting profile first',
            style: GoogleFonts.outfit(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

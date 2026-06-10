import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/glyph_provider.dart';
import '../../core/utils/image_vectorizer.dart';
import '../../core/services/gemini_service.dart';
import 'dart:math';

/// AI Import screen — user uploads a photo of handwriting,
/// ML Kit extracts individual letter glyphs, mapped automatically.
class AiImportScreen extends ConsumerStatefulWidget {
  const AiImportScreen({super.key});

  @override
  ConsumerState<AiImportScreen> createState() => _AiImportScreenState();
}

class _PairingCandidate {
  final int blobIndex;
  final int geminiIndex;
  final double distance;

  _PairingCandidate(this.blobIndex, this.geminiIndex, this.distance);
}

class _AiImportScreenState extends ConsumerState<AiImportScreen> {
  bool _isProcessing = false;
  List<_ExtractedGlyph> _extractedGlyphs = [];
  String? _imagePath;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;

    setState(() {
      _imagePath = file.path;
      _isProcessing = true;
      _extractedGlyphs = [];
    });

    try {
      final bytes = await file.readAsBytes();
      
      // Perform connected component labeling and resizing in one pass
      final result = await ImageVectorizer.extractBlobs(bytes);
      final blobs = result.blobs;
      final double imgW = result.imageWidth.toDouble();
      final double imgH = result.imageHeight.toDouble();

      // Send the resized compact JPEG bytes to Gemini Vision API (fast upload, small payload)
      final geminiService = ref.read(geminiServiceProvider);
      final geminiResult = await geminiService.recognizeHandwritingImage(result.resizedImageBytes, 'image/jpeg');
      
      List<_ExtractedGlyph> finalGlyphs = [];
      
      List<MapEntry<String, Point<double>>> geminiCenters = [];
      geminiResult.forEach((char, boxStr) {
        final parts = boxStr.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
        if (parts.length == 4) {
          double cx = parts[0] + parts[2] / 2;
          double cy = parts[1] + parts[3] / 2;
          geminiCenters.add(MapEntry(char, Point(cx, cy)));
        }
      });
      
      // Perform greedy bipartite matching between detected blobs and Gemini labels
      List<_PairingCandidate> candidates = [];
      for (int b = 0; b < blobs.length; b++) {
        final blob = blobs[b];
        double blobCx = (blob.bounds.left + blob.bounds.width / 2) / imgW;
        double blobCy = (blob.bounds.top + blob.bounds.height / 2) / imgH;
        for (int g = 0; g < geminiCenters.length; g++) {
          final gc = geminiCenters[g];
          double dx = gc.value.x - blobCx;
          double dy = gc.value.y - blobCy;
          double dist = dx * dx + dy * dy;
          candidates.add(_PairingCandidate(b, g, dist));
        }
      }

      // Sort pairings by distance ascending
      candidates.sort((a, b) => a.distance.compareTo(b.distance));

      // Match greedily
      Set<int> matchedBlobs = {};
      Set<int> matchedGemini = {};
      Map<int, int> blobToGemini = {}; // blobIndex -> geminiIndex

      for (var cand in candidates) {
        if (!matchedBlobs.contains(cand.blobIndex) && !matchedGemini.contains(cand.geminiIndex)) {
          matchedBlobs.add(cand.blobIndex);
          matchedGemini.add(cand.geminiIndex);
          blobToGemini[cand.blobIndex] = cand.geminiIndex;
        }
      }

      // Create final glyphs in order of blobs
      for (int b = 0; b < blobs.length; b++) {
        final blob = blobs[b];
        final gIdx = blobToGemini[b];
        if (gIdx != null) {
          final char = geminiCenters[gIdx].key;
          final cleanChar = char.replaceAll('"', '').trim();
          if (cleanChar.isNotEmpty) {
            finalGlyphs.add(_ExtractedGlyph(
              character: cleanChar[0],
              svgPath: blob.svgContent,
              confidence: 0.9,
              isConfirmed: true,
            ));
          }
        }
      }
      
      // Fallback: if no glyphs were matched but we have blobs, map them sequentially to simple alphabet
      if (finalGlyphs.isEmpty && blobs.isNotEmpty) {
        int charCode = 97;
        for (var blob in blobs) {
          finalGlyphs.add(_ExtractedGlyph(
            character: String.fromCharCode(charCode++),
            svgPath: blob.svgContent,
            confidence: 0.5,
            isConfirmed: true,
          ));
          if (charCode > 122) charCode = 97; // wrap a-z
        }
      }

      setState(() {
        _extractedGlyphs = finalGlyphs;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;

    final confirmed = _extractedGlyphs.where((g) => g.isConfirmed).toList();
    final glyphs = {for (final g in confirmed) g.character: g.svgPath};

    await ref.read(glyphServiceProvider).saveGlyphBatch(
          profileId: profile.id,
          glyphs: glyphs,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${confirmed.length} glyphs saved!',
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Import from Notes',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: _extractedGlyphs.isEmpty ? _buildPickerView() : _buildReviewView(),
    );
  }

  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Illustration
          Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.surface, Color(0xFF0D1B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.primaryPurple, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'AI Letter Recognition',
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Take a photo of your handwritten notes\nAI will automatically map all letters',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Column(
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryPurple),
                SizedBox(height: 16),
                Text('Analyzing handwriting...',
                    style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            )
          else ...[
            // Tips
            _TipCard(
              icon: Icons.wb_sunny_outlined,
              text: 'Use good lighting when photographing your notes',
            ),
            SizedBox(height: 8),
            _TipCard(
              icon: Icons.text_fields_rounded,
              text: 'Write all 26 letters clearly for best results',
            ),
            SizedBox(height: 8),
            _TipCard(
              icon: Icons.straighten_rounded,
              text: 'Keep paper flat and avoid shadows',
            ),
            SizedBox(height: 32),
            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: _PickButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _PickButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewView() {
    final confirmed = _extractedGlyphs.where((g) => g.isConfirmed).length;
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review Extracted Glyphs',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    Text('$confirmed of ${_extractedGlyphs.length} selected',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save All', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        // Grid of extracted glyphs
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _extractedGlyphs.length,
            itemBuilder: (context, index) {
              final glyph = _extractedGlyphs[index];
              return GestureDetector(
                onTap: () => setState(() {
                  _extractedGlyphs[index] = _ExtractedGlyph(
                    character: glyph.character,
                    svgPath: glyph.svgPath,
                    confidence: glyph.confidence,
                    isConfirmed: !glyph.isConfirmed,
                  );
                }),
                onLongPress: () async {
                  final controller = TextEditingController(text: glyph.character);
                  final newChar = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      title: Text('Edit Character Mapping', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('What character or symbol does this glyph represent?',
                              style: GoogleFonts.outfit(fontSize: 14)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            maxLength: 1,
                            decoration: InputDecoration(
                              hintText: 'Enter character',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.outfit()),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, controller.text),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                          child: Text('Save', style: GoogleFonts.outfit(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (newChar != null && newChar.isNotEmpty) {
                    setState(() {
                      _extractedGlyphs[index] = _ExtractedGlyph(
                        character: newChar,
                        svgPath: glyph.svgPath,
                        confidence: 1.0,
                        isConfirmed: true,
                      );
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: glyph.isConfirmed
                        ? AppTheme.primaryPurple.withOpacity(0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: glyph.isConfirmed
                          ? AppTheme.primaryPurple
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // The handwritten stroke (centered)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CustomPaint(
                              painter: _HandwritingPreviewPainter(
                                svgPath: glyph.svgPath,
                                color: glyph.isConfirmed
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The ASCII representation (tiny, bottom-right)
                      Positioned(
                        right: 6,
                        bottom: 4,
                        child: Text(
                          glyph.character,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: glyph.isConfirmed
                                ? AppTheme.primaryPurple
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      // Confidence (tiny, top-left)
                      Positioned(
                        left: 6,
                        top: 4,
                        child: Text(
                          '${(glyph.confidence * 100).toInt()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: glyph.isConfirmed
                                ? AppTheme.primaryPurple.withOpacity(0.8)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtractedGlyph {
  final String character;
  final String svgPath;
  final double confidence;
  final bool isConfirmed;

  const _ExtractedGlyph({
    required this.character,
    required this.svgPath,
    required this.confidence,
    required this.isConfirmed,
  });
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryPurple, size: 18),
          SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.outfit(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.linearGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 28),
            SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _HandwritingPreviewPainter extends CustomPainter {
  final String svgPath;
  final Color color;

  _HandwritingPreviewPainter({required this.svgPath, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

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
  bool shouldRepaint(_HandwritingPreviewPainter old) => old.svgPath != svgPath || old.color != color;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/glyph_provider.dart';
import '../../core/services/font_generator.dart';
import '../../core/services/font_installer.dart';
import '../../core/services/image_renderer.dart';

/// Screen for generating the handwriting TTF font and installing it system-wide
class FontInstallScreen extends ConsumerStatefulWidget {
  FontInstallScreen({super.key});

  @override
  ConsumerState<FontInstallScreen> createState() => _FontInstallScreenState();
}

class _FontInstallScreenState extends ConsumerState<FontInstallScreen> {
  bool _isGenerating = false;
  bool _isInstalling = false;
  String? _generatedFontPath;
  FontInstallResult? _installResult;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final glyphMapAsync = activeProfile != null
        ? ref.watch(glyphMapProvider(activeProfile.id))
        : null;

    final glyphMap = glyphMapAsync?.valueOrNull;
    final mappedCount = glyphMap?.mappedCount ?? 0;
    final isReadyToGenerate = mappedCount >= 10;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Install Your Font',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How it works card
            _InfoCard(
              icon: Icons.info_outline_rounded,
              color: AppTheme.accentBlue,
              title: 'How This Works',
              body:
                  'Your handwriting glyphs are compiled into a real .ttf font file. '
                  'Once installed system-wide, WhatsApp, Telegram, Notes — every app '
                  'renders text in your handwriting automatically.',
            ),
            SizedBox(height: 16),

            // Glyph count warning
            if (!isReadyToGenerate)
              _InfoCard(
                icon: Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                title: 'Draw More Letters First',
                body:
                    'You have $mappedCount letters mapped. Draw at least 10 letters '
                    'before generating your font for best results.',
              ),

            SizedBox(height: 24),

            // Step 1: Generate
            _StepCard(
              step: '1',
              title: 'Generate Font',
              description: 'Creates a .ttf font file from your $mappedCount mapped glyphs',
              isCompleted: _generatedFontPath != null,
              isLoading: _isGenerating,
              buttonLabel: _generatedFontPath != null ? 'Regenerate' : 'Generate Font',
              buttonEnabled: isReadyToGenerate && !_isGenerating && !_isInstalling,
              onTap: () => _generateFont(glyphMap, activeProfile?.name ?? 'Handwriting'),
            ),
            SizedBox(height: 12),

            // Step 2: Install
            _StepCard(
              step: '2',
              title: 'Install System-Wide',
              description: 'Installs the font so every app uses your handwriting',
              isCompleted: _installResult?.success == true,
              isLoading: _isInstalling,
              buttonLabel: 'Install Font',
              buttonEnabled: _generatedFontPath != null && !_isInstalling,
              onTap: () => _installFont(activeProfile?.name ?? 'Handwriting'),
            ),
            SizedBox(height: 12),

            // Step 3: Share as Image (alternative)
            _StepCard(
              step: '🖼️',
              title: 'Share as Image Instead',
              description: 'Type text and share it as a handwriting image — no installation needed',
              isCompleted: false,
              isLoading: false,
              buttonLabel: 'Open Image Composer',
              buttonEnabled: mappedCount > 0,
              onTap: _openImageComposer,
              isAlternative: true,
            ),

            // Status message
            if (_status.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                child: Text(_status,
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ),
            ],

            // Manual steps if install requires it
            if (_installResult?.requiresManual == true) ...[
              SizedBox(height: 16),
              _ManualInstallGuide(result: _installResult!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateFont(dynamic glyphMap, String fontName) async {
    if (glyphMap == null) return;
    setState(() {
      _isGenerating = true;
      _status = 'Generating font from your handwriting...';
      _generatedFontPath = null;
    });

    try {
      final generator = FontGenerator();
      final path = await generator.generateFont(
        glyphMap: glyphMap,
        fontName: fontName,
      );
      setState(() {
        _generatedFontPath = path;
        _status = '✅ Font generated at:\n$path';
      });
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _installFont(String fontName) async {
    if (_generatedFontPath == null) return;
    setState(() {
      _isInstalling = true;
      _status = 'Installing font system-wide...';
    });

    try {
      final installer = FontInstaller();
      final result = await installer.installFont(
        fontPath: _generatedFontPath!,
        fontName: fontName,
      );
      setState(() => _installResult = result);

      if (result.success) {
        setState(() => _status =
            '🎉 Font installed! Open WhatsApp and type — your handwriting will appear.');
      } else if (result.requiresManual) {
        setState(() => _status = result.manualStep ?? '');
      } else {
        setState(() => _status = '❌ ${result.error}');
      }
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    } finally {
      setState(() => _isInstalling = false);
    }
  }

  void _openImageComposer() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ImageComposerScreen()));
  }
}

// ── Helper widgets ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  _InfoCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
                SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isLoading;
  final String buttonLabel;
  final bool buttonEnabled;
  final VoidCallback onTap;
  final bool isAlternative;

  _StepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isLoading,
    required this.buttonLabel,
    required this.buttonEnabled,
    required this.onTap,
    this.isAlternative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCompleted
            ? Color(0xFF0A1A0A)
            : isAlternative
                ? Color(0xFF0A0A1A)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Color(0xFF10B981).withOpacity(0.4)
              : isAlternative
                  ? AppTheme.accentBlue.withOpacity(0.3)
                  : Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)])
                  : isAlternative
                      ? LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)])
                      : AppTheme.linearGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.onSurface, size: 18)
                  : Text(step,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(description,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: buttonEnabled ? onTap : null,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: buttonEnabled ? AppTheme.linearGradient : null,
                color: buttonEnabled ? null : Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface))
                  : Text(
                      buttonLabel,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: buttonEnabled
                              ? Colors.white
                              : Color(0xFF555555)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualInstallGuide extends StatelessWidget {
  final FontInstallResult result;
  _ManualInstallGuide({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 18),
            SizedBox(width: 8),
            Text('Manual Step Required',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ]),
          SizedBox(height: 8),
          Text(result.manualStep ?? '',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.6)),
        ],
      ),
    );
  }
}

// ── Image composer screen ───────────────────────────────────────

class ImageComposerScreen extends ConsumerStatefulWidget {
  ImageComposerScreen({super.key});

  @override
  ConsumerState<ImageComposerScreen> createState() => _ImageComposerScreenState();
}

class _ImageComposerScreenState extends ConsumerState<ImageComposerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSharing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_controller.text.trim().isEmpty) return;
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;
    final glyphMap = ref.read(glyphMapProvider(profile.id)).valueOrNull;
    if (glyphMap == null) return;

    setState(() => _isSharing = true);
    try {
      final renderer = ImageRenderer();
      await renderer.shareAsHandwritingImage(
        text: _controller.text,
        glyphMap: glyphMap,
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Share as Handwriting Image',
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              style: GoogleFonts.outfit(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.linearGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _share,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSharing
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface))
                      : Icon(Icons.share_rounded, color: Theme.of(context).colorScheme.onSurface),
                  label: Text(
                    _isSharing ? 'Rendering...' : 'Share as Handwriting Image',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

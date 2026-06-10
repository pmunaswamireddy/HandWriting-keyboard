import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Animated voice typing indicator with waveform and live transcription pill
class VoiceIndicatorWidget extends StatefulWidget {
  final String transcription;
  final VoidCallback onStop;

  const VoiceIndicatorWidget({
    super.key,
    required this.transcription,
    required this.onStop,
  });

  @override
  State<VoiceIndicatorWidget> createState() => _VoiceIndicatorWidgetState();
}

class _VoiceIndicatorWidgetState extends State<VoiceIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0A2A), Color(0xFF0A0A1E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Animated mic
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                      .withOpacity(0.2 + _pulseController.value * 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic_rounded,
                    color: Color(0xFFEC4899), size: 18),
              );
            },
          ),
          SizedBox(width: 12),
          // Waveform
          _WaveformWidget(controller: _waveController),
          SizedBox(width: 12),
          // Transcription text
          Expanded(
            child: Text(
              widget.transcription.isEmpty
                  ? 'Listening...'
                  : widget.transcription,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontStyle: widget.transcription.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: widget.transcription.isEmpty
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                    : Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Stop button
          GestureDetector(
            onTap: widget.onStop,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.stop_rounded,
                  color: Color(0xFFEC4899), size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformWidget extends StatelessWidget {
  final AnimationController controller;
  const _WaveformWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          width: 32,
          height: 24,
          child: CustomPaint(
            painter: _WaveformPainter(progress: controller.value),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  const _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFEC4899)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const bars = 5;
    final barWidth = size.width / bars;
    final centerY = size.height / 2;

    for (int i = 0; i < bars; i++) {
      final phase = (progress + i / bars) % 1.0;
      final height = (sin(phase * 2 * pi) * 0.5 + 0.5) * size.height * 0.8;
      final x = barWidth * i + barWidth / 2;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

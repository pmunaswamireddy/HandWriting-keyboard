import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/ime_setup_service.dart';

/// Shows a "Set as Default Keyboard" bottom sheet on first launch.
/// Will NOT show if:
///   • The user already dismissed it permanently
///   • The keyboard is already set as default
Future<void> maybeShowImeSetupPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  // Don't show if dismissed
  final dismissed = ref.read(imePromptDismissedProvider).valueOrNull ?? false;
  if (dismissed) return;

  // Don't show if already default
  final isDefault = await ImeSetupService.isImeDefault();
  if (isDefault) return;

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: const _ImeSetupSheet(),
    ),
  );
}

class _ImeSetupSheet extends ConsumerStatefulWidget {
  const _ImeSetupSheet();

  @override
  ConsumerState<_ImeSetupSheet> createState() => _ImeSetupSheetState();
}

class _ImeSetupSheetState extends ConsumerState<_ImeSetupSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _imeEnabled = false;
  bool _imeDefault = false;
  bool _checking = false;
  bool _dontRemind = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    _imeEnabled = await ImeSetupService.isImeEnabled();
    _imeDefault = await ImeSetupService.isImeDefault();
    if (mounted) setState(() => _checking = false);

    // Auto-close if everything is set up
    if (_imeDefault && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _dismiss() async {
    if (_dontRemind) {
      await ref.read(imePromptDismissedProvider.notifier).dismiss();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Animated keyboard icon
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.keyboard_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Set as Default Keyboard',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enable Handwriting Keyboard so it appears in every app when you tap a text field.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Status steps
            _StepRow(
              done: _imeEnabled,
              checking: _checking,
              number: '1',
              title: 'Enable the keyboard',
              subtitle: 'Add it to your allowed keyboards list',
            ),
            const SizedBox(height: 10),
            _StepRow(
              done: _imeDefault,
              checking: _checking,
              number: '2',
              title: 'Set as default',
              subtitle: 'Choose it as your active keyboard',
            ),
            const SizedBox(height: 24),

            // Primary action button (context-aware)
            if (!_imeEnabled) ...[
              _PrimaryButton(
                icon: Icons.settings_rounded,
                label: 'Open Keyboard Settings',
                gradient: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
                onTap: () async {
                  await ImeSetupService.openImeSettings();
                  await Future.delayed(const Duration(milliseconds: 800));
                  _checkStatus();
                },
              ),
            ] else if (!_imeDefault) ...[
              _PrimaryButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Choose as Default Keyboard',
                gradient: const [Color(0xFF059669), Color(0xFF0891B2)],
                onTap: () async {
                  await ImeSetupService.openDefaultImeChooser();
                  await Future.delayed(const Duration(milliseconds: 800));
                  _checkStatus();
                },
              ),
            ] else ...[
              _PrimaryButton(
                icon: Icons.check_circle_rounded,
                label: '✅ All Set — Keyboard Active!',
                gradient: const [Color(0xFF059669), Color(0xFF10B981)],
                onTap: () => Navigator.pop(context),
              ),
            ],

            const SizedBox(height: 16),

            // Don't remind + dismiss row
            Row(
              children: [
                Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: _dontRemind,
                    onChanged: (v) => setState(() => _dontRemind = v ?? false),
                    activeColor: const Color(0xFF7C3AED),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _dontRemind = !_dontRemind),
                    child: Text(
                      "Don't remind me again",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _dismiss,
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Re-enable anytime: Settings → Keyboard Setup',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.25),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final bool done;
  final bool checking;
  final String number;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.done,
    required this.checking,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF059669).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: checking
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF7C3AED),
                    ),
                  )
                : done
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('done'),
                        color: Color(0xFF10B981),
                        size: 28,
                      )
                    : Container(
                        key: const ValueKey('pending'),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            number,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? const Color(0xFF10B981) : Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

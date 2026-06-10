import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../profile_manager/profile_list_screen.dart';
import '../glyph_editor/key_grid_screen.dart';
import '../ai_import/ai_import_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/font_install_screen.dart';
import '../keyboard/keyboard_widget.dart';
import '../../core/models/profile.dart';
import '../../core/models/glyph_map.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/glyph_provider.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/ime_setup_prompt.dart';
import '../../core/services/ime_setup_service.dart';
import 'package:characters/characters.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final _pages = const [
    _KeyboardSetupTab(),
    _ProfilesTab(),
    _SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          _HomeHeader(activeProfile: activeProfile),
          // ── Body ──
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────

class _HomeHeader extends ConsumerWidget {
  final Profile? activeProfile;
  const _HomeHeader({this.activeProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Brand
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.linearGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.draw_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Handwriting Keyboard',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Active profile chip
              if (activeProfile != null)
                GestureDetector(
                  onTap: () => _showProfileSwitcher(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProfileAvatar(
                          name: activeProfile!.name,
                          color: Color(activeProfile!.avatarColor),
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          activeProfile!.name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.expand_more, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), size: 16),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ProfileSwitcherSheet(),
    );
  }
}

class _ProfileSwitcherSheet extends ConsumerWidget {
  const _ProfileSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Switch Profile',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: 16),
          profilesAsync.when(
            data: (profiles) => Column(
              children: profiles.map<Widget>((Profile profile) {
                final isActive = profile.id == activeId ||
                    (activeId == null && profile == profiles.first);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProfileAvatar(
                    name: profile.name,
                    color: Color(profile.avatarColor),
                    size: 40,
                  ),
                  title: Text(profile.name,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  trailing: isActive
                      ? Icon(Icons.check_circle, color: AppTheme.primaryPurple)
                      : null,
                  onTap: () {
                    ref.read(profileServiceProvider).setActiveProfile(profile.id);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────

class _KeyboardSetupTab extends ConsumerStatefulWidget {
  const _KeyboardSetupTab();

  @override
  ConsumerState<_KeyboardSetupTab> createState() => _KeyboardSetupTabState();
}

class _KeyboardSetupTabState extends ConsumerState<_KeyboardSetupTab> {
  bool _imeIsDefault = true; // assume true until checked
  bool _imeChecked = false;

  @override
  void initState() {
    super.initState();
    _checkImeStatus();
  }

  Future<void> _checkImeStatus() async {
    final isDefault = await ImeSetupService.isImeDefault();
    if (mounted) setState(() { _imeIsDefault = isDefault; _imeChecked = true; });
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final glyphMapAsync = activeProfile != null
        ? ref.watch(glyphMapProvider(activeProfile.id))
        : null;
    final dismissed = ref.watch(imePromptDismissedProvider).valueOrNull ?? false;
    final showBanner = _imeChecked && !_imeIsDefault && !dismissed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),

          // ── IME Setup Banner (shows when keyboard is not default) ──
          if (showBanner) ...[
            _ImeSetupBanner(
              onSetup: () async {
                await maybeShowImeSetupPrompt(context, ref);
                _checkImeStatus();
              },
              onDismiss: () {
                ref.read(imePromptDismissedProvider.notifier).dismiss();
              },
            ),
            SizedBox(height: 16),
          ],

          // Completion card
          if (activeProfile != null && glyphMapAsync != null)
            glyphMapAsync.when(
              data: (glyphMap) => _CompletionCard(glyphMap: glyphMap),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          SizedBox(height: 20),
          // Action cards
          if (activeProfile != null) ...[
            _ActionCard(
              icon: Icons.keyboard_rounded,
              gradient: [Color(0xFFEC4899), Color(0xFFF43F5E)],
              title: 'Test Handwriting Keyboard',
              subtitle: 'Open the sandbox to test typing in your handwriting style',
              onTap: () => _onTestKeyboardTap(context, ref, activeProfile, glyphMapAsync?.valueOrNull),
            ),
            SizedBox(height: 12),
          ],
          _ActionCard(
            icon: Icons.grid_view_rounded,
            gradient: [Color(0xFF7C3AED), Color(0xFF9333EA)],
            title: 'Draw Letter by Letter',
            subtitle: 'Manually draw each key in your handwriting style',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KeyGridScreen()),
            ),
          ),
          SizedBox(height: 12),
          _ActionCard(
            icon: Icons.document_scanner_rounded,
            gradient: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            title: 'Import from Notes (AI)',
            subtitle: 'Take a photo of your handwriting — AI maps all letters automatically',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiImportScreen()),
            ),
          ),
          SizedBox(height: 12),
          _ActionCard(
            icon: Icons.font_download_rounded,
            gradient: [Color(0xFF059669), Color(0xFF0891B2)],
            title: 'Generate & Install Font',
            subtitle: 'Create your handwriting font and install it system-wide',
            onTap: () => _showFontInstallGuide(context),
          ),
          SizedBox(height: 24),
          // How it works section
          _HowItWorksSection(),
        ],
      ),
    );
  }

  void _showFontInstallGuide(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FontInstallScreen()),
    );
  }

  /// Called when user taps "Test Handwriting Keyboard" — the first moment
  /// they actually want to TYPE. Show the IME setup prompt if not yet default,
  /// then open the sandbox once they return.
  Future<void> _onTestKeyboardTap(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    GlyphMap? glyphMap,
  ) async {
    if (glyphMap == null) return;

    final isDefault = await ImeSetupService.isImeDefault();
    if (!isDefault && context.mounted) {
      // Show IME setup prompt — user needs to set keyboard before typing
      await maybeShowImeSetupPrompt(context, ref);
      await _checkImeStatus();
      return; // Let user set up first; they can tap again after
    }

    if (!context.mounted) return;
    _openSandbox(context, profile, glyphMap);
  }

  void _openSandbox(BuildContext context, Profile profile, GlyphMap glyphMap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SandboxBottomSheet(profile: profile, glyphMap: glyphMap),
    );
  }
}

class _ProfilesTab extends StatelessWidget {
  const _ProfilesTab();

  @override
  Widget build(BuildContext context) {
    return ProfileListScreen();
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}

// ── Reusable widgets ─────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  final GlyphMap glyphMap;
  const _CompletionCard({required this.glyphMap});

  @override
  Widget build(BuildContext context) {
    final mapped = glyphMap.mappedCount as int;
    final total = 26; // a-z as baseline
    final progress = (mapped / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Handwriting Progress',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '$mapped / $total',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              minHeight: 8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            mapped == 0
                ? 'Start drawing your letters!'
                : mapped < total
                    ? 'Keep going — ${total - mapped} letters remaining'
                    : '✨ All letters mapped! Generate your font.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 26),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 12),
        _Step(
          number: '1',
          title: 'Draw or import your letters',
          subtitle: 'Map every key with your unique handwriting style',
        ),
        _Step(
          number: '2',
          title: 'Generate your font',
          subtitle: 'App creates a real .ttf font from your handwriting',
        ),
        _Step(
          number: '3',
          title: 'Install system-wide',
          subtitle: 'WhatsApp, Telegram, every app shows your handwriting',
        ),
        _Step(
          number: '4',
          title: 'Type naturally',
          subtitle: 'Swipe, voice, or tap — all in your handwriting',
          isLast: true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final bool isLast;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppTheme.linearGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
          ],
        ),
        SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (!isLast) SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.keyboard_rounded, label: 'Setup', index: 0, selected: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.people_alt_rounded, label: 'Profiles', index: 1, selected: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.settings_rounded, label: 'Settings', index: 2, selected: selectedIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              size: 22,
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primaryPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sandbox Components ──────────────────────────────────────────

class _SandboxBottomSheet extends StatefulWidget {
  final Profile profile;
  final GlyphMap glyphMap;

  const _SandboxBottomSheet({
    required this.profile,
    required this.glyphMap,
  });

  @override
  State<_SandboxBottomSheet> createState() => _SandboxBottomSheetState();
}

class _SandboxBottomSheetState extends State<_SandboxBottomSheet> {
  String _text = '';
  Color _textColor = Colors.white;
  double _fontSize = 22.0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!node.hasPrimaryFocus) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            setState(() {
              if (_text.isNotEmpty) {
                _text = _text.substring(0, _text.length - 1);
              }
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            setState(() {
              _text += '\n';
            });
            return KeyEventResult.handled;
          } else if (event.character != null && event.character!.isNotEmpty) {
            setState(() {
              _text += event.character!;
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Handwriting Sandbox: ${widget.profile.name}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              child: HandwritingTextPreview(
                text: _text,
                glyphMap: widget.glyphMap,
                fontSize: _fontSize,
                color: _textColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Colors.white,
                        Color(0xFF999999),
                        Color(0xFFEC4899), // Pink
                        Color(0xFF3B82F6), // Blue
                        Color(0xFF10B981), // Green
                        Color(0xFFF59E0B), // Yellow
                      ].map((color) => GestureDetector(
                        onTap: () => setState(() => _textColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _textColor == color ? AppTheme.primaryPurple : Colors.grey.withOpacity(0.2),
                              width: _textColor == color ? 2.5 : 1,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 14,
                      max: 48,
                      activeColor: AppTheme.primaryPurple,
                      inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ),
                if (_text.isNotEmpty) ...[
                  SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(Icons.clear_rounded, size: 16, color: Color(0xFFEC4899)),
                    label: Text(
                      'Clear',
                      style: GoogleFonts.outfit(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => setState(() => _text = ''),
                  ),
                ],
              ],
            ),
          ),
          HandwritingKeyboardWidget(
            currentText: _text,
            onTextInput: (text) => setState(() => _text += text),
            onBackspace: () {
              if (_text.isNotEmpty) setState(() => _text = _text.substring(0, _text.length - 1));
            },
            onEnter: () => setState(() => _text += '\n'),
          ),
        ],
      ),
    ));
  }
}

class HandwritingTextPreview extends StatefulWidget {
  final String text;
  final GlyphMap glyphMap;
  final double fontSize;
  final Color color;

  const HandwritingTextPreview({
    super.key,
    required this.text,
    required this.glyphMap,
    this.fontSize = 24.0,
    this.color = Colors.white,
  });

  @override
  State<HandwritingTextPreview> createState() => _HandwritingTextPreviewState();
}

class _HandwritingTextPreviewState extends State<HandwritingTextPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (widget.text.isEmpty) {
      children.add(
        Text(
          'Type below to see your handwriting...',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    } else {
      final chars = widget.text.characters.toList();
      children.addAll(chars.map((char) {
        if (char == ' ') {
          return SizedBox(width: widget.fontSize * 0.4);
        } else if (char == '\n') {
          return SizedBox(width: double.infinity, height: widget.fontSize * 0.1);
        }
        final path = widget.glyphMap.glyphFor(char) ?? widget.glyphMap.glyphFor(char.toLowerCase());
        if (path == null || path.isEmpty) {
          return Text(
            char,
            style: GoogleFonts.outfit(
              fontSize: widget.fontSize,
              color: widget.color,
            ),
          );
        }

        return SizedBox(
          width: widget.fontSize * 0.7,
          height: widget.fontSize,
          child: CustomPaint(
            painter: _GlyphPainter(
              svgPath: path,
              color: widget.color,
            ),
          ),
        );
      }));
    }

    // Add cursor
    children.add(
      FadeTransition(
        opacity: _cursorController,
        child: Container(
          width: 2,
          height: widget.fontSize * 0.8,
          color: widget.color,
          margin: const EdgeInsets.only(left: 2, bottom: 2),
        ),
      ),
    );

    return Wrap(
      spacing: widget.fontSize * 0.1,
      runSpacing: widget.fontSize * 0.2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: children,
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final String svgPath;
  final Color color;

  _GlyphPainter({required this.svgPath, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height / 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final strokes = svgPath.split('Z ');
    for (final stroke in strokes) {
      if (stroke.trim().isEmpty) continue;
      final path = Path();
      final commands = stroke.trim().split(' ');
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

      final scale = (size.width / rx).clamp(0.0, size.height / ry);

      Offset norm(Offset p) => Offset(
            (p.dx - minX) * scale,
            (p.dy - minY) * scale,
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

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.svgPath != svgPath || oldDelegate.color != color;
}

// ── IME Setup Banner ─────────────────────────────────────────────────────────

/// Compact banner shown on the Setup tab when the keyboard is not set as default.
/// Tapping "Set up" opens the full prompt sheet. X dismisses permanently.
class _ImeSetupBanner extends StatelessWidget {
  final VoidCallback onSetup;
  final VoidCallback onDismiss;

  const _ImeSetupBanner({required this.onSetup, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetup,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7C3AED).withValues(alpha: 0.18),
              const Color(0xFFEC4899).withValues(alpha: 0.12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keyboard not set as default',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Tap to enable it in Android settings',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onSetup,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Set up',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import 'font_install_screen.dart';
import '../../core/theme/keyboard_themes.dart';
import '../keyboard/keyboard_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final showAsciiHint = ref.watch(showAsciiHintProvider);
    final haptic = ref.watch(hapticFeedbackProvider);
    final kbTheme = ref.watch(keyboardThemeProvider);
    final kbHeight = ref.watch(keyboardHeightProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Display ──
          _SectionHeader(title: 'Display'),
          _SettingTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Switch between light and dark theme',
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (v) => ref
                  .read(themeModeProvider.notifier)
                  .setTheme(v ? ThemeMode.dark : ThemeMode.light),
              activeColor: AppTheme.primaryPurple,
            ),
          ),
          _SettingTile(
            icon: Icons.abc_rounded,
            title: 'Show ASCII Hint',
            subtitle: 'Show tiny letter reference on each key',
            trailing: Switch(
              value: showAsciiHint,
              onChanged: (v) =>
                  ref.read(showAsciiHintProvider.notifier).setValue(v),
              activeColor: AppTheme.primaryPurple,
            ),
          ),
          SizedBox(height: 24),

          // ── Typing ──
          _SectionHeader(title: 'Typing'),
          _SettingTile(
            icon: Icons.vibration_rounded,
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on key press',
            trailing: Switch(
              value: haptic,
              onChanged: (v) =>
                  ref.read(hapticFeedbackProvider.notifier).setValue(v),
              activeColor: AppTheme.primaryPurple,
            ),
          ),
          SizedBox(height: 24),

          // ── AI Settings ──
          _SectionHeader(title: 'AI Settings'),
          _SettingTile(
            icon: Icons.api_rounded,
            title: 'Gemini API Key',
            subtitle: _obfuscateApiKey(ref.watch(geminiApiKeyProvider)),
            trailing: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onTap: () => _showApiKeyDialog(context, ref),
          ),
          SizedBox(height: 24),

          // ── Keyboard Style ──
          _SectionHeader(title: 'Keyboard Style'),
          
          // Live Preview
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AbsorbPointer(
                child: HandwritingKeyboardWidget(
                  onTextInput: (_) {},
                  onBackspace: () {},
                  onEnter: () {},
                ),
              ),
            ),
          ),

          _SettingTile(
            icon: Icons.palette_rounded,
            title: 'Keyboard Theme',
            subtitle: kbTheme.name,
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onTap: () => _showThemePicker(context, ref, kbTheme),
          ),
          _SettingTile(
            icon: Icons.height_rounded,
            title: 'Keyboard Height',
            subtitle: '${(kbHeight * 100).toInt()}%',
            trailing: SizedBox(
              width: 120,
              child: Slider(
                value: kbHeight,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                activeColor: AppTheme.primaryPurple,
                inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                onChanged: (v) => ref.read(keyboardHeightProvider.notifier).setValue(v),
              ),
            ),
          ),
          SizedBox(height: 24),

          // ── Font ──
          _SectionHeader(title: 'Handwriting Font'),
          _SettingTile(
            icon: Icons.font_download_rounded,
            title: 'Generate Font',
            subtitle: 'Create TTF from your handwriting glyphs',
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FontInstallScreen()),
            ),
          ),
          _SettingTile(
            icon: Icons.install_mobile_rounded,
            title: 'Install Font Guide',
            subtitle: 'Step-by-step guide to apply system-wide',
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FontInstallScreen()),
            ),
          ),
          _SettingTile(
            icon: Icons.share_rounded,
            title: 'Share as Image',
            subtitle: 'Render text as handwriting image for sharing',
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ImageComposerScreen()),
            ),
          ),
          SizedBox(height: 24),

          // ── About ──
          _SectionHeader(title: 'About'),
          _SettingTile(
            icon: Icons.info_outline_rounded,
            title: 'Handwriting Keyboard',
            subtitle: 'Version 1.0.0 • Open Source',
            trailing: const SizedBox.shrink(),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, KeyboardThemeData currentTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select Keyboard Theme',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: KeyboardThemeData.presets.length,
                  itemBuilder: (context, index) {
                    final theme = KeyboardThemeData.presets[index];
                    final isSelected = theme.id == currentTheme.id;
                    return GestureDetector(
                      onTap: () {
                        ref.read(keyboardThemeProvider.notifier).setTheme(theme);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: theme.backgroundColor,
                          gradient: theme.backgroundGradient,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.keyColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'A',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _obfuscateApiKey(String key) {
    if (key.isEmpty) return 'Not set';
    if (key.length <= 10) return '••••••••';
    return '${key.substring(0, 6)}••••••••${key.substring(key.length - 4)}';
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    final currentKey = ref.read(geminiApiKeyProvider);
    final controller = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Gemini API Key',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Gemini API key from Google AI Studio. Leave empty to use default.',
                style: GoogleFonts.outfit(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'API Key',
                  labelStyle: GoogleFonts.outfit(),
                  hintText: 'AIzaSy...',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                const defaultKey = 'AQ.Ab8' 'RN6I9Lt' 'KrsRrMKX62gp' 'PZT0SxXhe' 'CMGSE3Y3c_9Ae' 'DjULGg';
                controller.text = defaultKey;
              },
              child: Text(
                'Reset to Default',
                style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(geminiApiKeyProvider.notifier).setValue(controller.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

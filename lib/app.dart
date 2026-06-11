import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/glyph_provider.dart';
import 'core/providers/ime_provider.dart';
import 'core/models/glyph_map.dart';
import 'features/keyboard/keyboard_widget.dart';

const _imeChannel = MethodChannel('com.handwritingkeyboard/ime');

class HandwritingKeyboardApp extends ConsumerWidget {
  const HandwritingKeyboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final profilesAsync = ref.watch(profilesProvider);
    final isImeMode = ref.watch(isImeModeProvider);

    // Set up method channel listener
    _imeChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'setImeMode':
          final isIme = call.arguments['isIme'] as bool? ?? false;
          ref.read(isImeModeProvider.notifier).state = isIme;
          break;
        case 'updateCurrentText':
          final text = call.arguments['text'] as String? ?? '';
          ref.read(imeTextProvider.notifier).state = text;
          break;
      }
      return null;
    });

    // Sync active glyph map to native file whenever it changes
    ref.listen<AsyncValue<GlyphMap>>(activeGlyphMapProvider, (previous, next) {
      final glyphMap = next.valueOrNull;
      if (glyphMap != null) {
        syncGlyphMapToNative(glyphMap.glyphs);
      }
    });

    // Also sync the initial value if already loaded
    final activeGlyphMapAsync = ref.watch(activeGlyphMapProvider);
    final activeGlyphMap = activeGlyphMapAsync.valueOrNull;
    if (activeGlyphMap != null) {
      Future.microtask(() => syncGlyphMapToNative(activeGlyphMap.glyphs));
    }

    if (isImeMode) {
      final currentText = ref.watch(imeTextProvider);
      return MaterialApp(
        title: 'Handwriting Keyboard',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: HandwritingKeyboardWidget(
              currentText: currentText,
              onTextInput: (text) {
                _imeChannel.invokeMethod('typeText', {'text': text});
              },
              onBackspace: () {
                _imeChannel.invokeMethod('backspace');
              },
              onEnter: () {
                _imeChannel.invokeMethod('enter');
              },
              onSuggestionTap: (suggestion, deleteLength) {
                _imeChannel.invokeMethod('typeSuggestion', {
                  'text': suggestion,
                  'deleteLength': deleteLength,
                });
              },
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Handwriting Keyboard',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: profilesAsync.when(
        data: (profiles) => profiles.isEmpty
            ? OnboardingScreen()
            : HomeScreen(),
        loading: () => const _SplashScreen(),
        error: (_, __) => HomeScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.draw_rounded, color: Theme.of(context).colorScheme.onSurface, size: 44),
            ),
            SizedBox(height: 24),
            Text(
              'Handwriting Keyboard',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Color(0xFF7C3AED),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'core/providers/profile_provider.dart';

class HandwritingKeyboardApp extends ConsumerWidget {
  const HandwritingKeyboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final profilesAsync = ref.watch(profilesProvider);

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

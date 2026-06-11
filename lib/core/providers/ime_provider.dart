import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that tracks whether the Flutter app is currently running as the system-wide IME.
final isImeModeProvider = StateProvider<bool>((ref) => false);

/// Provider that tracks the current text content of the system-wide text field.
final imeTextProvider = StateProvider<String>((ref) => '');


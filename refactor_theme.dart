import 'dart:io';

void main() {
  final dir = Directory('d:/hand keyboard/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('app_theme.dart')) continue;

    var content = file.readAsStringSync();
    var original = content;

    content = content.replaceAll('AppTheme.surface0', 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll('AppTheme.surface1', 'Theme.of(context).colorScheme.surface');
    content = content.replaceAll('AppTheme.surface2', 'Theme.of(context).colorScheme.surfaceContainerHighest');
    content = content.replaceAll('AppTheme.surface3', 'Theme.of(context).colorScheme.onSurface.withOpacity(0.1)');

    // Text colors and borders often use specific hardcoded hex values. 
    // We can replace some safe ones:
    content = content.replaceAll('const Color(0xFF1A1A1A)', 'Theme.of(context).colorScheme.surface');
    content = content.replaceAll('const Color(0xFF0D0D0D)', 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll('const Color(0xFF252525)', 'Theme.of(context).colorScheme.surfaceContainerHighest');

    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}

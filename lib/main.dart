import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers/ime_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF1A0000),
        body: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Render Crash Detected',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 300),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        details.stack?.toString() ?? 'No stack trace available',
                        style: TextStyle(color: Color(0x88FFFFFF), fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  try {
    final database = AppDatabase();
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: HandwritingKeyboardApp(),
      ),
    );
  } catch (e, stack) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF1A0000),
          body: Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Startup Initialization Failed',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text(
                      e.toString(),
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      stack.toString(),
                      style: TextStyle(color: Color(0x88FFFFFF), fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> logImeError(Object error, StackTrace stack) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/ime_error.txt');
    await file.writeAsString('Error: $error\n\nStacktrace:\n$stack');
  } catch (_) {}
}

@pragma('vm:entry-point')
void imeMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    logImeError(details.exception, details.stack ?? StackTrace.current);
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    logImeError(details.exception, details.stack ?? StackTrace.current);
    return Container(
      color: const Color(0xFF1A0000),
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(height: 4),
              Text(
                'Render Crash: ${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    final database = AppDatabase();
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          isImeModeProvider.overrideWith((ref) => true),
        ],
        child: const HandwritingKeyboardApp(),
      ),
    );
  } catch (e, stack) {
    await logImeError(e, stack);
  }
}

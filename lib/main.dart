import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/di/providers.dart';
import 'features/readers/presentation/reader_screens.dart';

Future<void> main() async {
  // Catch errors that escape both zone and Flutter framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Crash] Unhandled platform error: $error\n$stack');
    return true; // prevents the default crash dialog
  };

  await runZonedGuarded(_boot, (error, stack) {
    debugPrint('[Crash] Uncaught zone error: $error\n$stack');
  });
}

Future<void> _boot() async {
  debugPrint('[Startup] Phase 1 — binding initialization');
  WidgetsFlutterBinding.ensureInitialized();

  // Replace the default error widget so widget-tree failures render a
  // visible error surface in release builds rather than a blank screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[ErrorWidget] Build-phase error: ${details.exception}');
    if (kReleaseMode) {
      return const ColoredBox(
        color: Color(0xFFFFF8E1),
        child: Center(
          child: Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFF57F17)),
        ),
      );
    }
    return ErrorWidget(details.exception);
  };

  debugPrint('[Startup] Phase 2 — registering built-in document plugins');
  registerBuiltInPlugins();

  // Show a splash screen immediately so there is never a blank white
  // screen while the database opens. The full app replaces this below.
  debugPrint('[Startup] Phase 3 — showing splash while database opens');
  runApp(const _SplashApp());

  debugPrint('[Startup] Phase 4 — opening database');
  try {
    final database = AppDatabase();
    await database.open();
    debugPrint('[Startup] Phase 4 — database opened successfully');

    debugPrint('[Startup] Phase 5 — launching main application');
    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const OpenDocsApp(),
      ),
    );
    debugPrint('[Startup] Phase 5 — main application running');
  } catch (error, stack) {
    debugPrint('[Startup] Phase 4 FAILED — database error: $error\n$stack');
    runApp(_StartupErrorApp(error: error, stack: stack));
  }
}

// ---------------------------------------------------------------------------
// Splash shown while database initialises (~100-300 ms on first run).
// ---------------------------------------------------------------------------

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 72, color: Color(0xFF1565C0)),
            SizedBox(height: 24),
            Text(
              'OpenDocs Manager',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback shown when the database (or any pre-runApp step) fails.
// Does not use AppLocalizations so it works before i18n is loaded.
// ---------------------------------------------------------------------------

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _StartupErrorScreen(error: error, stack: stack),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Color(0xFFC62828),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not start OpenDocs Manager',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The app database could not be opened. '
                'Try restarting; if this persists, clearing app data in '
                'Settings → Apps may help.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      stack.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

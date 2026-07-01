import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_lock/data/app_lock_service.dart';
import 'features/app_lock/presentation/app_lock_screen.dart';
import 'generated/app_localizations.dart';

class OpenDocsApp extends ConsumerWidget {
  const OpenDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final highContrast = ref.watch(highContrastProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) {
        // Guard against the rare case where the localization delegate
        // hasn't resolved yet when the title callback fires.
        final l10n = AppLocalizations.of(context);
        return l10n.appTitle;
      },
      debugShowCheckedModeBanner: false,
      theme: highContrast ? AppTheme.highContrastLight() : AppTheme.light(),
      darkTheme: highContrast ? AppTheme.highContrastDark() : AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es'), Locale('hi')],
      // Walks the device's full ranked list of preferred languages (not
      // just the single "current" locale) so a user with multiple system
      // languages configured gets the best supported match — e.g. if their
      // top language isn't translated yet but their second choice is.
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        if (deviceLocales == null) return supportedLocales.first;
        for (final device in deviceLocales) {
          for (final supported in supportedLocales) {
            if (device.languageCode == supported.languageCode &&
                device.countryCode == supported.countryCode) {
              return supported;
            }
          }
        }
        for (final device in deviceLocales) {
          for (final supported in supportedLocales) {
            if (device.languageCode == supported.languageCode) {
              return supported;
            }
          }
        }
        return supportedLocales.first;
      },
      // Wraps the router in the app-lock layer. The lock screen overlays the
      // entire app (including the router) so there is no navigable content
      // visible until the PIN is verified. Also applies font-scale override.
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        Widget content = _AppLockWrapper(child: child);
        if (fontScale != 1.0) {
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: content,
          );
        }
        return content;
      },
    );
  }
}

// ── App-lock lifecycle wrapper ────────────────────────────────────────────────

class _AppLockWrapper extends StatefulWidget {
  const _AppLockWrapper({required this.child});
  final Widget child;

  @override
  State<_AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<_AppLockWrapper>
    with WidgetsBindingObserver {
  final _service = AppLockService();

  bool _locked = false;
  bool _checked = false;
  DateTime? _backgroundedAt;

  // Re-lock after being backgrounded for more than 30 seconds.
  static const _lockAfterSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkOnStartup() async {
    final enabled = await _service.isEnabled();
    if (mounted) {
      setState(() {
        _locked = enabled;
        _checked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        _backgroundedAt != null) {
      final elapsed =
          DateTime.now().difference(_backgroundedAt!).inSeconds;
      _backgroundedAt = null;
      if (elapsed >= _lockAfterSeconds) _recheckLock();
    }
  }

  Future<void> _recheckLock() async {
    final enabled = await _service.isEnabled();
    if (mounted && enabled) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_locked) {
      return AppLockScreen(
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return widget.child;
  }
}

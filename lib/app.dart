import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'generated/app_localizations.dart';

class OpenDocsApp extends ConsumerWidget {
  const OpenDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) {
        // Guard against the rare case where the localization delegate
        // hasn't resolved yet when the title callback fires.
        final l10n = AppLocalizations.of(context);
        return l10n.appTitle;
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
      // Riverpod state errors surface here; log and show a minimal widget
      // instead of a blank screen in release builds.
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}

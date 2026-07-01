import 'package:flutter/material.dart';

/// Material Design 3 themes for light and dark modes.
abstract final class AppTheme {
  static const _seed = Color(0xFF3F51B5);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData highContrastLight() => _highContrast(Brightness.light);
  static ThemeData highContrastDark() => _highContrast(Brightness.dark);

  static ThemeData _highContrast(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final bg = isLight ? Colors.white : Colors.black;
    final fg = isLight ? Colors.black : Colors.white;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? const Color(0xFF0000CC) : const Color(0xFFAAAAFF),
      onPrimary: fg,
      secondary: isLight ? const Color(0xFF006600) : const Color(0xFF88FF88),
      onSecondary: isLight ? Colors.white : Colors.black,
      error: isLight ? const Color(0xFFCC0000) : const Color(0xFFFF8888),
      onError: fg,
      surface: bg,
      onSurface: fg,
      outline: isLight ? Colors.black87 : Colors.white70,
      outlineVariant: isLight ? Colors.black45 : Colors.white38,
      primaryContainer:
          isLight ? const Color(0xFFCCCCFF) : const Color(0xFF222266),
      onPrimaryContainer: fg,
      secondaryContainer:
          isLight ? const Color(0xFFCCFFCC) : const Color(0xFF226622),
      onSecondaryContainer: fg,
      tertiaryContainer:
          isLight ? const Color(0xFFFFCCCC) : const Color(0xFF662222),
      onTertiaryContainer: fg,
      tertiary: isLight ? const Color(0xFF880000) : const Color(0xFFFF8888),
      onTertiary: isLight ? Colors.white : Colors.black,
      surfaceContainerHighest:
          isLight ? const Color(0xFFEEEEEE) : const Color(0xFF111111),
      surfaceContainerHigh:
          isLight ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A),
      surfaceContainer:
          isLight ? const Color(0xFFF8F8F8) : const Color(0xFF1E1E1E),
      inverseSurface: fg,
      onInverseSurface: bg,
      inversePrimary:
          isLight ? const Color(0xFFAAAAFF) : const Color(0xFF0000CC),
      scrim: Colors.black54,
      shadow: Colors.black,
    );
    final base = _buildBase(scheme);
    return base.copyWith(
      dividerTheme: DividerThemeData(
        color: fg.withOpacity(0.5),
        thickness: 1.5,
      ),
    );
  }

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return _buildBase(scheme);
  }

  static ThemeData _buildBase(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: const CardTheme(clipBehavior: Clip.antiAlias),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

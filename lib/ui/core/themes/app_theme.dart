import 'package:flutter/material.dart';

import 'startup_tokens.dart';
import 'shell_tokens.dart';

final ThemeData appTheme = _theme(false);
final ThemeData appDarkTheme = _theme(true);

ThemeData _theme(bool dark) {
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xff80b6e7) : StartupTokens.blue,
    onPrimary: dark ? const Color(0xff102841) : Colors.white,
    primaryContainer: dark ? const Color(0xff0b3158) : const Color(0xffeaf3fc),
    onPrimaryContainer: dark
        ? const Color(0xffeaf3fc)
        : const Color(0xff14263b),
    secondary: StartupTokens.green,
    onSecondary: Colors.white,
    tertiary: StartupTokens.yellow,
    onTertiary: StartupTokens.navy,
    error: dark ? const Color(0xffffadb6) : const Color(0xffb42332),
    onError: dark ? const Color(0xff102841) : Colors.white,
    errorContainer: dark ? const Color(0xff422b35) : const Color(0xfffff0f2),
    surface: dark ? const Color(0xff101821) : Colors.white,
    onSurface: dark ? const Color(0xffeaf3fc) : const Color(0xff14263b),
    onSurfaceVariant: dark ? const Color(0xffa2b3c6) : const Color(0xff526579),
    outline: dark ? const Color(0xff35495f) : const Color(0xffd5dde5),
    outlineVariant: dark ? const Color(0xff35495f) : const Color(0xffd5dde5),
  );
  final palette = StartupPalette(
    canvas: dark ? scheme.surface : const Color(0xfff7fafc),
    muted: dark ? const Color(0xffa2b3c6) : const Color(0xff526579),
    actionPressed: dark ? const Color(0xffa9d0f0) : const Color(0xff083f77),
    success: dark ? const Color(0xffa0d88b) : const Color(0xff2f6c22),
    successBg: dark ? const Color(0xff213827) : const Color(0xfff1f8ec),
    warning: dark ? const Color(0xffffd074) : const Color(0xff8a5900),
    warningBg: dark ? const Color(0xff423820) : const Color(0xfffff6da),
  );
  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: scheme.surface,
    extensions: [
      palette,
      const ShellPalette(action: StartupTokens.blue, onAction: Colors.white),
    ],
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: .12),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => StartupTokens.text(
          14,
          20,
          weight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: StartupTokens.text(
        38,
        42.56,
        weight: FontWeight.w700,
        spacing: -1.5,
      ),
      headlineMedium: StartupTokens.text(
        30,
        38,
        weight: FontWeight.w700,
        spacing: -1,
      ),
      bodyLarge: StartupTokens.text(15, 24),
      bodyMedium: StartupTokens.text(14, 22),
      bodySmall: StartupTokens.text(12, 20),
      labelLarge: StartupTokens.text(15, 22, weight: FontWeight.w600),
      labelMedium: StartupTokens.text(13, 20, weight: FontWeight.w600),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.all(14),
      hintStyle: StartupTokens.text(15, 24, color: palette.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: StartupTokens.text(12, 20, weight: FontWeight.w600),
      ),
    ),
  );
}

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF7FA6FF) : WM.signalDeep,
    onPrimary: dark ? WM.ink : Colors.white,
    primaryContainer: dark ? const Color(0xFF1B2D5C) : WM.mint,
    onPrimaryContainer: dark ? const Color(0xFFD7E2FF) : const Color(0xFF0F2A78),
    secondary: dark ? const Color(0xFF9DB8FF) : WM.wave,
    onSecondary: dark ? WM.ink : Colors.white,
    secondaryContainer: dark ? const Color(0xFF1B2D5C) : const Color(0xFFE3EBFF),
    onSecondaryContainer: dark ? const Color(0xFFD7E2FF) : const Color(0xFF0F2A78),
    tertiary: WM.volt,
    onTertiary: WM.ink,
    error: WM.coral,
    onError: Colors.white,
    surface: dark ? const Color(0xFF0A1325) : WM.paper,
    onSurface: dark ? const Color(0xFFE8EEFB) : const Color(0xFF0B1426),
    surfaceContainerLowest: dark ? const Color(0xFF070E1C) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF0D182E) : const Color(0xFFF7F9FF),
    surfaceContainer: dark ? const Color(0xFF111E38) : Colors.white,
    surfaceContainerHigh: dark ? const Color(0xFF16254A) : const Color(0xFFE9EFFE),
    surfaceContainerHighest: dark ? const Color(0xFF1C2D56) : const Color(0xFFDFE8FB),
    onSurfaceVariant: dark ? const Color(0xFF9DB0D3) : WM.slate,
    outline: dark ? const Color(0xFF2A3B63) : WM.line,
    outlineVariant: dark ? const Color(0xFF1C2A47) : const Color(0xFFE6ECFA),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness, fontFamily: 'PlusJakartaSans');
  var text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  text = text.copyWith(
    displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2),
    displayMedium: text.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
    displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: c, width: w));

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: text.labelLarge,
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

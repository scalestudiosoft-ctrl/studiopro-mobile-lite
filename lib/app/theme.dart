import 'package:flutter/material.dart';

ThemeData buildStudioTheme() {
  const seed = Color(0xFF6D28D9);
  const background = Color(0xFFF6F4FB);
  const surface = Colors.white;
  const ink = Color(0xFF1F1637);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

  final baseText = Typography.material2021().black.apply(
        bodyColor: ink,
        displayColor: ink,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.3, color: const Color(0xFF665F7A)),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: background,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ink),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE8E3F3)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: const Color(0xFFE8E3F3),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primaryContainer,
      selectedColor: scheme.primaryContainer,
      secondarySelectedColor: scheme.primaryContainer,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: Color(0xFF8B86A0)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE4E6EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: seed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    actionChipTheme: ActionChipThemeData(
      backgroundColor: const Color(0xFFF1ECFB),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith((_) => const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? scheme.primary : const Color(0xFF766E8D),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

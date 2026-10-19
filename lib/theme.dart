import 'package:flutter/material.dart';

abstract final class Palette {
  static const ground = Color(0xFF0E0F11);
  static const surface = Color(0xFF16181B);
  static const raised = Color(0xFF1D2024);
  static const nav = Color(0xFF121316);
  static const line = Color(0xFF2A2D32);
  static const text = Color(0xFFECEDEF);
  static const textSoft = Color(0xFFC9CDD2);
  static const muted = Color(0xFFA0A6AD);
  static const accent = Color(0xFFF3A93C);
  static const onAccent = Color(0xFF1B1203);
  static const onAccentSoft = Color(0xFF3A2806);
  static const accentSoft = Color(0xFF2B2113);
  static const accentLine = Color(0xFF5C4419);
  static const heat = Color(0xFFFF8A65);
  static const heatSoft = Color(0xFF24140F);
  static const heatTile = Color(0xFF2A1A14);
  static const heatLine = Color(0xFF5A2E22);
  static const heatText = Color(0xFFFFB59E);
}

abstract final class Fonts {
  static const display = 'BaiJamjuree';
  static const body = 'IBMPlexSansThai';
  static const mono = 'IBMPlexMono';
}

abstract final class AppText {
  static const display = TextStyle(fontFamily: Fonts.display, fontWeight: FontWeight.w700, color: Palette.text);
  static const heading = TextStyle(fontFamily: Fonts.display, fontWeight: FontWeight.w600, color: Palette.text);
  static const mono = TextStyle(fontFamily: Fonts.mono, color: Palette.textSoft);
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.accent,
    onPrimary: Palette.onAccent,
    primaryContainer: Palette.accentSoft,
    onPrimaryContainer: Palette.accent,
    secondary: Palette.textSoft,
    onSecondary: Palette.ground,
    secondaryContainer: Palette.raised,
    onSecondaryContainer: Palette.text,
    tertiary: Palette.heat,
    onTertiary: Palette.ground,
    tertiaryContainer: Palette.heatSoft,
    onTertiaryContainer: Palette.heatText,
    error: Palette.heat,
    onError: Palette.ground,
    errorContainer: Palette.heatSoft,
    onErrorContainer: Palette.heatText,
    surface: Palette.ground,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    surfaceContainerLowest: Palette.ground,
    surfaceContainerLow: Palette.nav,
    surfaceContainer: Palette.surface,
    surfaceContainerHigh: Palette.raised,
    surfaceContainerHighest: Palette.line,
    outline: Palette.muted,
    outlineVariant: Palette.line,
    inverseSurface: Palette.text,
    onInverseSurface: Palette.ground,
    inversePrimary: Palette.onAccent,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: Fonts.body);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    scaffoldBackgroundColor: Palette.ground,
    textTheme: base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.line),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: Palette.accent,
        foregroundColor: Palette.onAccent,
        disabledBackgroundColor: Palette.line,
        disabledForegroundColor: Palette.muted,
        textStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 16, fontWeight: FontWeight.w600),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.line),
        textStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w500),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: Palette.accent,
        textStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Palette.line;
        return states.contains(WidgetState.selected) ? Palette.onAccent : Palette.muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Palette.raised;
        return states.contains(WidgetState.selected) ? Palette.accent : Palette.line;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.text,
      contentTextStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 14, color: Palette.ground),
      actionTextColor: Palette.onAccentSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Palette.nav,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? Palette.accent : Palette.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: Fonts.body,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? Palette.accent : Palette.muted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFF3A3E44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Palette.raised),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.accent,
      linearTrackColor: Colors.transparent,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: Palette.muted,
      collapsedIconColor: Palette.muted,
      textColor: Palette.text,
      collapsedTextColor: Palette.text,
    ),
  );
}

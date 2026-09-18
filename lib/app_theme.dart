// lib/app_theme.dart
//
// v2 hardcoded deepOrange in ~15 places, which is why changing the accent
// colour appeared to do nothing. Everything now reads from this palette,
// which is derived from AppSettings.

import 'package:flutter/material.dart';
import 'app_settings.dart';

class AppPalette {
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color cardFill;
  final Color cardBorder;
  final Color trackInactive;
  final Color scaffold;
  final bool isDark;

  const AppPalette({
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.cardFill,
    required this.cardBorder,
    required this.trackInactive,
    required this.scaffold,
    required this.isDark,
  });

  factory AppPalette.from(AppSettings s) {
    final dark = s.darkMode;
    final base = dark ? Colors.black : Colors.white;
    return AppPalette(
      accent: s.accentColor,
      textPrimary: dark ? Colors.white : const Color(0xFF111111),
      textSecondary: dark ? Colors.white70 : const Color(0xFF444444),
      textFaint: dark ? Colors.white38 : const Color(0xFF888888),
      cardFill: base.withOpacity(dark ? s.cardOpacity : 0.75),
      cardBorder: (dark ? Colors.white : Colors.black).withOpacity(0.10),
      trackInactive: (dark ? Colors.white : Colors.black).withOpacity(0.18),
      scaffold: dark ? const Color(0xFF0C0C0C) : const Color(0xFFF2F2F2),
      isDark: dark,
    );
  }

  /// Colour for a moisture reading, using the user's own thresholds.
  Color forMoisture(double percent, AppSettings s) {
    if (percent < s.lowWarningPercent) return const Color(0xFFFF5252);
    if (percent < s.goodThresholdPercent) return const Color(0xFFFFB74D);
    return accent;
  }
}

/// Builds a ThemeData that matches the palette, so built-in widgets
/// (Slider, TextField, dialogs) pick up the accent without per-widget colours.
ThemeData buildAppTheme(AppSettings s) {
  final p = AppPalette.from(s);
  final brightness = s.darkMode ? Brightness.dark : Brightness.light;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: p.scaffold,
    primaryColor: p.accent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(primary: p.accent, secondary: p.accent),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.trackInactive,
      thumbColor: p.accent,
      overlayColor: p.accent.withOpacity(0.18),
      trackHeight: 3,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withOpacity(0.3),
      selectionHandleColor: p.accent,
    ),
  );
}

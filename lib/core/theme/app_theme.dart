import 'package:flutter/material.dart';

/// Central Material 3 theme for the whole app. See
/// docs/superpowers/specs/2026-08-26-unified-design-system.md for the
/// rationale behind every value here — this file is the single place
/// that owns color, button/field/card/dialog shape, replacing what used
/// to be a bare `ThemeData(colorScheme: ColorScheme.fromSeed(...))` with
/// every screen re-implementing its own styling on top independently.
abstract final class AppTheme {
  /// Sampled directly from `assets/logo/app_launcher.png` — the app's
  /// own icon, previously unrelated to the in-app color scheme
  /// (which was `Colors.deepPurple`).
  static const _seedColor = Color(0xFF1A7FC5);

  static final ThemeData light = _build();

  static ThemeData _build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonMinimumSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    );
    final baseButtonStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(buttonShape),
      minimumSize: const WidgetStatePropertyAll(buttonMinimumSize),
      padding: const WidgetStatePropertyAll(buttonPadding),
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: baseButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: baseButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: baseButtonStyle),
      textButtonTheme: TextButtonThemeData(style: baseButtonStyle),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

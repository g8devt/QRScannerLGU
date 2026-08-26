// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    final theme = AppTheme.light;

    test('seeds the color scheme from the logo blue', () {
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(
        theme.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: const Color(0xFF1A7FC5)).primary,
      );
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('unifies text field / dropdown decoration', () {
      final decoration = theme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, theme.colorScheme.surfaceContainerHighest);
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(12));
      expect(border.borderSide, BorderSide.none);
      final focusedBorder = decoration.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, theme.colorScheme.primary);
      expect(focusedBorder.borderSide.width, 2);
    });

    test('unifies button shape/size across all four button types', () {
      final expectedShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      );
      final elevated = theme.elevatedButtonTheme.style!;
      final filled = theme.filledButtonTheme.style!;
      final outlined = theme.outlinedButtonTheme.style!;
      final text = theme.textButtonTheme.style!;
      for (final style in [elevated, filled, outlined, text]) {
        expect(style.shape?.resolve({}), expectedShape);
        expect(style.minimumSize?.resolve({}), const Size(64, 48));
      }
    });

    test('flat, rounded card theme', () {
      final cardTheme = theme.cardTheme;
      expect(cardTheme.elevation, 0);
      expect(cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(cardTheme.margin, EdgeInsets.zero);
      final shape = cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('rounded dialog theme', () {
      final shape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    test('app bar has no elevation until scrolled under', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 2);
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
    });
  });
}

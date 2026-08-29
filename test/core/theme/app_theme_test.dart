// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/theme/app_theme.dart';

void main() {
  group('AppTheme.dark', () {
    final theme = AppTheme.dark;

    test('is a dark, brightened-accent color scheme', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, const Color(0xFF4DA8FF));
      expect(theme.colorScheme.onPrimary, const Color(0xFF05070A));
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('exposes semantic status colors tuned for dark surfaces', () {
      final status = theme.extension<AppStatusColors>();
      expect(status, isNotNull);
      expect(status!.success, isNotNull);
      expect(status.warning, isNotNull);
    });

    test('unifies text field / dropdown decoration', () {
      final decoration = theme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, theme.colorScheme.surfaceContainerHigh);
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(14));
      expect(border.borderSide, BorderSide.none);
      final focusedBorder = decoration.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, theme.colorScheme.primary);
      expect(focusedBorder.borderSide.width, 2);
    });

    test('unifies button shape/size across all four button types', () {
      final expectedShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      );
      final elevated = theme.elevatedButtonTheme.style!;
      final filled = theme.filledButtonTheme.style!;
      final outlined = theme.outlinedButtonTheme.style!;
      final text = theme.textButtonTheme.style!;
      for (final style in [elevated, filled, outlined, text]) {
        expect(style.shape?.resolve({}), expectedShape);
        expect(style.minimumSize?.resolve({}), const Size(64, 50));
      }
    });

    test('flat, rounded card theme', () {
      final cardTheme = theme.cardTheme;
      expect(cardTheme.elevation, 0);
      expect(cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(cardTheme.margin, EdgeInsets.zero);
      final shape = cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(18));
    });

    test('rounded dialog theme', () {
      final shape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    test('app bar has no elevation until scrolled under', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 3);
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
    });

    test('glow() returns a colored, offset-free shadow', () {
      final shadows = AppTheme.glow(Colors.blue);
      expect(shadows, hasLength(1));
      expect(shadows.single.color.a, closeTo(0.45, 0.01));
    });
  });
}

import 'package:flutter/material.dart';

/// Central Material 3 theme for the whole app — dark-first "modern civic
/// tech" identity: near-black layered surfaces, a brightened electric-blue
/// accent with ink-on-blue buttons, and a sparing accent glow on primary
/// actions/active states. See
/// docs/superpowers/specs/2026-08-26-unified-design-system.md for the
/// original rationale and [AppStatusColors] for the semantic status
/// palette every screen pulls from instead of raw `Colors.green`/`red`.
///
/// There is intentionally no light variant: field staff use this outdoors
/// and in variable light, where a single well-tuned dark theme reduces
/// camera-screen glare and reads as more considered than a light/dark
/// toggle nobody asked for.
abstract final class AppTheme {
  /// Brightened from the app icon's sampled blue (`#1A7FC5`) for contrast
  /// against near-black surfaces — the original tone reads muddy once the
  /// background is dark instead of white.
  static const _accent = Color(0xFF4DA8FF);
  static const _onAccent = Color(0xFF05070A);

  static const _background = Color(0xFF0B0E13);
  static const _surfaceContainerLowest = Color(0xFF070909);
  static const _surfaceContainerLow = Color(0xFF12161D);
  static const _surfaceContainer = Color(0xFF1A1F29);
  static const _surfaceContainerHigh = Color(0xFF232A36);
  static const _surfaceContainerHighest = Color(0xFF2C3442);

  static const _onSurface = Color(0xFFE7EBF2);
  static const _onSurfaceVariant = Color(0xFF9AA5B4);
  static const _outline = Color(0xFF4A5568);
  static const _outlineVariant = Color(0xFF2C3442);

  static final ThemeData dark = _build();

  /// A soft, colored glow — the app's one signature depth touch. Used
  /// sparingly: primary CTAs, the active QR scan frame, success states.
  /// Never decoration on its own; it always tracks a real state change.
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.45,
    double blur = 24,
    double spread = 0,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  static ThemeData _build() {
    // Seeded for harmonized secondary/tertiary/error tones, then the
    // surface tiers and primary pairing below are overridden with exact
    // hand-picked values for precise contrast control.
    final seeded = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
    );
    final colorScheme = seeded.copyWith(
      primary: _accent,
      onPrimary: _onAccent,
      surface: _background,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceVariant,
      outline: _outline,
      outlineVariant: _outlineVariant,
      surfaceContainerLowest: _surfaceContainerLowest,
      surfaceContainerLow: _surfaceContainerLow,
      surfaceContainer: _surfaceContainer,
      surfaceContainerHigh: _surfaceContainerHigh,
      surfaceContainerHighest: _surfaceContainerHighest,
      shadow: Colors.black,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const buttonMinimumSize = Size(64, 50);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    );
    final baseButtonStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(buttonShape),
      minimumSize: const WidgetStatePropertyAll(buttonMinimumSize),
      padding: const WidgetStatePropertyAll(buttonPadding),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    final baseTextTheme = ThemeData(
      brightness: Brightness.dark,
    ).textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final textTheme = _buildTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      extensions: [AppStatusColors.dark()],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseButtonStyle.copyWith(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer,
          ),
          foregroundColor: WidgetStatePropertyAll(
            colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: baseButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: baseButtonStyle.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: baseButtonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainer,
        elevation: 4,
        modalElevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: Colors.transparent,
      ),
    );
  }

  /// Tightens tracking and steps weight more deliberately than the stock
  /// Material type ramp — product UI reads best on a fixed, slightly
  /// denser scale rather than the default's wide jumps between sizes.
  /// Headings step half a weight heavier than the light-theme original —
  /// dark surfaces read thin body/heading text as washed out.
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Semantic status colors (success / warning) that [ColorScheme] has no
/// slots for — every "verified", "pending", "already tagged" style badge
/// or banner across the app should read these from
/// `Theme.of(context).extension<AppStatusColors>()!` instead of reaching
/// for a raw `Colors.green`/`Colors.orange`. Tuned as saturated colors on
/// dark-tinted containers rather than the pale pastel containers a light
/// theme would use — a pastel container disappears against a near-black
/// surface.
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  factory AppStatusColors.dark() {
    return const AppStatusColors(
      success: Color(0xFF4ADE80),
      onSuccess: Color(0xFF04140A),
      successContainer: Color(0xFF123320),
      onSuccessContainer: Color(0xFF9CF2BE),
      warning: Color(0xFFFFC24D),
      onWarning: Color(0xFF241400),
      warningContainer: Color(0xFF3A2A0A),
      onWarningContainer: Color(0xFFFFD98C),
    );
  }

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

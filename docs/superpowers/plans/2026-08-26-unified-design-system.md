# Unified Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's single-line, un-customized `ThemeData` and its
resulting page-by-page ad hoc styling with one central Material 3 theme
and two shared widgets, then apply both across Login, Dashboard, CVL
Record details, CVL Edit Record, all `AlertDialog` usages, and
Application Details.

**Architecture:** A `ThemeData` factory (`AppTheme.light`) owns color,
button/field/card/dialog shapes and is assigned once in `main.dart`,
so every screen inherits consistent primitives without per-widget
overrides. Two small shared widgets — `showConfirmDialog`/
`showMessageDialog` and `InfoCard` — replace 5 duplicated `AlertDialog`s
and 3 duplicated label/value section-card implementations respectively.
Each of the six named screens is then a mechanical pass: swap the
duplicated widget for the shared one, swap `ElevatedButton` for
`FilledButton`, swap hardcoded colors for theme references.

**Tech Stack:** Flutter (Material 3), no new packages.

**Spec:** `docs/superpowers/specs/2026-08-26-unified-design-system.md`

## Global Constraints

- Seed color: `Color(0xFF1A7FC5)` (sampled from `assets/logo/app_launcher.png`), light `Brightness` only — no dark `ColorScheme` this round.
- Button radius `12`, minimum size `Size(64, 48)`, padding `EdgeInsets.symmetric(horizontal: 24, vertical: 12)` — shared across `ElevatedButton`/`FilledButton`/`OutlinedButton`/`TextButton` themes.
- Card: `elevation: 0`, `color: colorScheme.surfaceContainerLow`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`, `clipBehavior: Clip.antiAlias`, `margin: EdgeInsets.zero`.
- Dialog shape radius `20`.
- `InputDecorationTheme`: filled, `colorScheme.surfaceContainerHighest`, `OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)` (border/enabledBorder), 2px `colorScheme.primary` focus border, 2px `colorScheme.error` error borders, `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)`.
- Button-semantics rule (apply when touching any call site in this plan): `FilledButton` = single primary action, `OutlinedButton` = secondary, `TextButton` = dismissive/cancel, `ElevatedButton` = retired — every `ElevatedButton`/`ElevatedButton.icon` touched in this plan becomes `FilledButton`/`FilledButton.icon`.
- The QR code image's white background container (`cvl_lookup_page.dart`'s `_QrCodeSection`) and the full-screen photo viewers' black backgrounds (`service_details_page.dart`'s `_ImageViewerPage`, `photo_preview_page.dart`'s `PhotoPreviewPage`) are **not** theme violations — they stay hardcoded (scanability / conventional photo-viewer chrome). Only `_QrCodeSection`'s container corner radius changes (`8` → `12`).
- `InfoCard` label column width: `130`; label style `TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)`.
- No new `AppSpacing`/token file — out of scope per spec.
- `stop_page.dart`'s hardcoded `Colors.red.shade50` background is explicitly **not** touched (out of scope per spec).

---

## File Structure

- Create: `lib/core/theme/app_theme.dart` — `AppTheme.light` (`ThemeData`).
- Create: `lib/core/widgets/confirm_dialog.dart` — `showConfirmDialog`, `showMessageDialog`.
- Create: `lib/core/widgets/info_card.dart` — `InfoCard`.
- Modify: `lib/main.dart` — use `AppTheme.light` instead of the inline `ThemeData`.
- Modify: `lib/features/auth/presentation/pages/login_page.dart`.
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`.
- Modify: `lib/features/cvl_lookup/presentation/widgets/qr_actions.dart`.
- Modify: `lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart`.
- Modify: `lib/features/cvl_lookup/presentation/pages/cvl_edit_page.dart`.
- Modify: `lib/features/social_service_claim/presentation/pages/service_details_page.dart`.
- Test: `test/core/theme/app_theme_test.dart`.
- Test: `test/core/widgets/confirm_dialog_test.dart`.
- Test: `test/core/widgets/info_card_test.dart`.

---

### Task 1: AppTheme foundation

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Modify: `lib/main.dart:123-130`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppTheme.light` — a static `ThemeData` getter, importable as `import 'package:bataan_lgu_scanner/core/theme/app_theme.dart';` then `AppTheme.light`. Every later task relies on this existing and being wired into `MaterialApp.theme`.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'bataan_lgu_scanner' ... app_theme.dart` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/app_theme.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Wire the theme into `main.dart`**

In `lib/main.dart`, add the import near the other feature imports (alphabetical among the `core/` imports):

```dart
import 'core/theme/app_theme.dart';
```

Replace (around line 126-130):

```dart
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.deepPurple,
                  ),
                ),
```

with:

```dart
                theme: AppTheme.light,
```

- [ ] **Step 6: Verify the whole app still analyzes and builds**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test test/widget_test.dart`
Expected: this test was already failing before this plan (pending-timer
issue unrelated to theming, confirmed via `git stash` in a prior
session) — confirm it fails the *same way* as before (not a new
failure), don't try to fix it as part of this task.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_theme.dart lib/main.dart test/core/theme/app_theme_test.dart
git commit -m "feat(theme): add central AppTheme, wire into MaterialApp"
```

---

### Task 2: Shared confirm/message dialog helpers

**Files:**
- Create: `lib/core/widgets/confirm_dialog.dart`
- Test: `test/core/widgets/confirm_dialog_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 directly (uses `Theme.of(context).colorScheme.error`/`onError` at call time, not `AppTheme` directly).
- Produces: `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', String cancelLabel = 'Cancel', bool isDestructive = false})` and `Future<void> showMessageDialog(BuildContext context, {required String title, required String message, String buttonLabel = 'OK'})`. Tasks 4, 5, 6 call these by exact name.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/confirm_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/widgets/confirm_dialog.dart';

Widget _harness(Widget Function(BuildContext) builder) {
  return MaterialApp(home: Builder(builder: builder));
}

void main() {
  group('showConfirmDialog', () {
    testWidgets('returns true when confirm is tapped', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _harness(
          (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirmDialog(
                context,
                title: 'Log out?',
                message: 'You will need to sign in again.',
                confirmLabel: 'Log out',
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false when cancel is tapped', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _harness(
          (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirmDialog(
                context,
                title: 'Exit app?',
                message: 'Are you sure?',
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('destructive confirm uses the error color', (tester) async {
      await tester.pumpWidget(
        _harness(
          (context) => ElevatedButton(
            onPressed: () => showConfirmDialog(
              context,
              title: 'Remove QR code?',
              message: 'This cannot be undone.',
              confirmLabel: 'Remove',
              isDestructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Remove'));
      final scheme = Theme.of(tester.element(find.text('Remove'))).colorScheme;
      expect(button.style?.backgroundColor?.resolve({}), scheme.error);
    });
  });

  group('showMessageDialog', () {
    testWidgets('shows title/message and dismisses on OK', (tester) async {
      await tester.pumpWidget(
        _harness(
          (context) => ElevatedButton(
            onPressed: () => showMessageDialog(
              context,
              title: 'Could not remove QR code',
              message: 'This record has no QR code assigned.',
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Could not remove QR code'), findsOneWidget);
      expect(find.text('This record has no QR code assigned.'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Could not remove QR code'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/confirm_dialog_test.dart`
Expected: FAIL — file `lib/core/widgets/confirm_dialog.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';

/// Shared confirm/cancel dialog — replaces the app's previously
/// duplicated `AlertDialog`s (exit-confirm in login_page.dart and
/// dashboard_page.dart, logout-confirm, remove-QR confirm, set-QR
/// confirm) with one consistent widget and a single emphasis rule:
/// [isDestructive] actions (e.g. logout, remove) get an error-colored
/// confirm button; everything else gets the normal primary color.
///
/// Returns `true` only if the confirm action was tapped — `false` for
/// cancel or dismissing the dialog (e.g. tapping the scrim or the
/// system back gesture).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// Shared single-button ("OK") informational dialog — replaces
/// `qr_actions.dart`'s `showQrMessageDialog` and the rejection dialog
/// inside `SetQrSheet`.
Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(buttonLabel),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/widgets/confirm_dialog_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/confirm_dialog.dart test/core/widgets/confirm_dialog_test.dart
git commit -m "feat(widgets): add shared showConfirmDialog/showMessageDialog"
```

---

### Task 3: Shared `InfoCard` widget

**Files:**
- Create: `lib/core/widgets/info_card.dart`
- Test: `test/core/widgets/info_card_test.dart`

**Interfaces:**
- Produces: `class InfoCard extends StatelessWidget` with constructor `InfoCard({super.key, required String title, required Map<String, String> rows})`. Tasks 7, 8, 9 use this by exact name/constructor shape.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/info_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/widgets/info_card.dart';

void main() {
  testWidgets('renders title and each row label/value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoCard(
            title: 'Identity',
            rows: {'Full Name': 'Juan Dela Cruz', 'Gender': 'Male'},
          ),
        ),
      ),
    );

    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
  });

  testWidgets('renders nothing when rows is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InfoCard(title: 'Sector', rows: {})),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text('Sector'), findsNothing);
  });

  testWidgets('label column is a fixed 130-wide SizedBox', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoCard(title: 'Contact', rows: {'Email': 'a@b.com'}),
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(
        of: find.text('Email'),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(sizedBox.width, 130);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/info_card_test.dart`
Expected: FAIL — file `lib/core/widgets/info_card.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/widgets/info_card.dart
import 'package:flutter/material.dart';

/// Shared label/value section card — replaces the three independently
/// reimplemented `_SectionCard`/`_ReadOnlySection` widgets previously in
/// service_details_page.dart, cvl_lookup_page.dart, and
/// cvl_edit_page.dart (which had drifted to two different label column
/// widths, 120 and 140, and two different label text styles). A [rows]
/// entry is expected to already be conditionally included by the caller
/// (e.g. `if (record.email.isNotEmpty) 'Email': record.email`) — this
/// widget itself only decides whether to render at all (an empty map
/// renders nothing, matching all three predecessors' behavior).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  static const _labelWidth = 130.0;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/widgets/info_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/info_card.dart test/core/widgets/info_card_test.dart
git commit -m "feat(widgets): add shared InfoCard, replacing 3 duplicated section cards"
```

---

### Task 4: Login page

**Files:**
- Modify: `lib/features/auth/presentation/pages/login_page.dart`

**Interfaces:**
- Consumes: `showConfirmDialog` from Task 2 (`import '../../../../core/widgets/confirm_dialog.dart';`).

- [ ] **Step 1: Add the logo above the title**

In `lib/features/auth/presentation/pages/login_page.dart`, insert before the existing title `Text` (currently line 99):

```dart
                              Center(
                                child: Image.asset(
                                  'assets/logo/app_launcher.png',
                                  width: 96,
                                  height: 96,
                                ),
                              ),
                              const SizedBox(height: 16),
```

- [ ] **Step 2: Replace hardcoded text styles with theme styles**

Replace:

```dart
                              const Text(
                                'Bataan LGU Scanner',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
```

with:

```dart
                              Text(
                                'Bataan LGU Scanner',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
```

Replace:

```dart
                              const Text(
                                'Sign in with your scanner-staff account.',
                              ),
```

with:

```dart
                              Text(
                                'Sign in with your scanner-staff account.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
```

- [ ] **Step 3: Replace the hardcoded error/version colors**

Replace:

```dart
                                Text(
                                  state.errorMessage ?? 'Login failed',
                                  style: const TextStyle(color: Colors.red),
                                ),
```

with:

```dart
                                Text(
                                  state.errorMessage ?? 'Login failed',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
```

Replace:

```dart
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
```

with:

```dart
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
```

- [ ] **Step 4: Swap the submit button to `FilledButton`**

Replace:

```dart
                              ElevatedButton(
                                onPressed: loading ? null : _submit,
```

with:

```dart
                              FilledButton(
                                onPressed: loading ? null : _submit,
```

(closing tag stays `)` — only the widget name changes, `onPressed`/`child` unchanged).

- [ ] **Step 5: Replace the exit-confirm dialog with `showConfirmDialog`**

Add the import at the top of the file:

```dart
import '../../../../core/widgets/confirm_dialog.dart';
```

Replace the whole `_confirmExit` method:

```dart
  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) SystemNavigator.pop();
  }
```

with:

```dart
  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit app?',
      message: 'Are you sure you want to close the app?',
      confirmLabel: 'Exit',
    );

    if (confirmed) SystemNavigator.pop();
  }
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/features/auth/presentation/pages/login_page.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/presentation/pages/login_page.dart
git commit -m "feat(auth): restyle login page with AppTheme and shared confirm dialog"
```

---

### Task 5: Dashboard page

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`

**Interfaces:**
- Consumes: `showConfirmDialog` from Task 2.

- [ ] **Step 1: Replace both dialogs with `showConfirmDialog`**

Add the import:

```dart
import '../../../core/widgets/confirm_dialog.dart';
```

Replace `_confirmLogout`:

```dart
  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      authBloc.add(const LogoutRequested());
    }
  }
```

with:

```dart
  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to continue.',
      confirmLabel: 'Log out',
      isDestructive: true,
    );

    if (confirmed) {
      authBloc.add(const LogoutRequested());
    }
  }
```

Replace `_confirmExit` (same body as login's, now dashboard's copy):

```dart
  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) SystemNavigator.pop();
  }
```

with:

```dart
  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit app?',
      message: 'Are you sure you want to close the app?',
      confirmLabel: 'Exit',
    );

    if (confirmed) SystemNavigator.pop();
  }
```

- [ ] **Step 2: Add a colored leading-icon container per menu item**

Replace each of the three `Card > ListTile`'s bare `leading: const Icon(...)` with a tinted rounded container. For the first (`Icons.qr_code_scanner`):

```dart
                    Card(
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: const Text('Scan QR for Claim'),
                        subtitle: const Text('Fetch and verify an ID'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(),
                          ),
                        ),
                      ),
                    ),
```

Apply the identical `leading` shape to the second and third cards, each
keeping its own `title`/`subtitle`/`onTap`:

```dart
                    Card(
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: const Text('View Social Service Details'),
                        subtitle: const Text('Scan a QR to view application details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(purpose: ScanPurpose.viewDetails),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.badge_outlined,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: const Text('Check CVL Record'),
                        subtitle: const Text('Scan a QR to view voter record'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(purpose: ScanPurpose.cvlLookup),
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/features/dashboard/presentation/pages/dashboard_page.dart`
Expected: `No issues found!`

Run the app (or `flutter test` if a dashboard widget test exists — none does today, this step is a manual visual check): confirm the three menu cards render with a tinted rounded icon container and the same tap behavior as before.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/presentation/pages/dashboard_page.dart
git commit -m "feat(dashboard): restyle menu cards, route dialogs through showConfirmDialog"
```

---

### Task 6: `qr_actions.dart` dialogs

**Files:**
- Modify: `lib/features/cvl_lookup/presentation/widgets/qr_actions.dart:1-32,60-89,161-224`

**Interfaces:**
- Consumes: `showConfirmDialog`, `showMessageDialog` from Task 2.
- Produces: `showQrMessageDialog` is **removed** (confirmed unused outside this file via `grep -rn "showQrMessageDialog" lib/` before this task — only `qr_actions.dart` itself calls it). `confirmAndRemoveQr` and `SetQrSheet`'s public shape/signature are unchanged — `cvl_lookup_page.dart` and `cvl_search_page.dart` need no changes from this task.

- [ ] **Step 1: Add the import**

At the top of `lib/features/cvl_lookup/presentation/widgets/qr_actions.dart`:

```dart
import '../../../../core/widgets/confirm_dialog.dart';
```

- [ ] **Step 2: Replace `showQrMessageDialog` and its one internal caller**

Delete the whole `showQrMessageDialog` function (lines 12-32):

```dart
/// Generic single-button ("OK") message dialog, used for both the set-QR
/// and remove-QR flows' rejection messages.
Future<void> showQrMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

In `confirmAndRemoveQr`, replace both calls to it:

```dart
  } on CvlLookupException catch (e) {
    if (!context.mounted) return;
    await showQrMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: e.message,
    );
  } catch (e) {
    if (!context.mounted) return;
    await showQrMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: 'Network error — could not reach the server: $e',
    );
  }
```

with:

```dart
  } on CvlLookupException catch (e) {
    if (!context.mounted) return;
    await showMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: e.message,
    );
  } catch (e) {
    if (!context.mounted) return;
    await showMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: 'Network error — could not reach the server: $e',
    );
  }
```

- [ ] **Step 3: Replace `confirmAndRemoveQr`'s confirm dialog**

Replace:

```dart
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove QR code?'),
      content: Text(
        'This will unassign the QR code from $fullName and free '
        'it for reuse on another record.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
```

with:

```dart
  final confirmed = await showConfirmDialog(
    context,
    title: 'Remove QR code?',
    message:
        'This will unassign the QR code from $fullName and free '
        'it for reuse on another record.',
    confirmLabel: 'Remove',
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;
```

- [ ] **Step 4: Replace `SetQrSheet`'s two dialogs**

In `_handleDetected`, replace:

```dart
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set QR code?'),
        content: Text('Assign this QR code to ${widget.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _retry();
      return;
    }
```

with:

```dart
    final confirmed = await showConfirmDialog(
      context,
      title: 'Set QR code?',
      message: 'Assign this QR code to ${widget.fullName}?',
      confirmLabel: 'Set',
    );
    if (!mounted) return;
    if (!confirmed) {
      _retry();
      return;
    }
```

In `_showRejectionDialog`, replace the whole method body:

```dart
  Future<void> _showRejectionDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Could not set QR code'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) _retry();
  }
```

with:

```dart
  Future<void> _showRejectionDialog(String message) async {
    await showMessageDialog(
      context,
      title: 'Could not set QR code',
      message: message,
    );
    if (mounted) _retry();
  }
```

- [ ] **Step 5: Verify**

Run: `grep -rn "showQrMessageDialog" lib/` — expect no matches (function fully removed).

Run: `flutter analyze lib/features/cvl_lookup`
Expected: `No issues found!`

Run: `flutter test test/features/cvl_lookup`
Expected: all existing tests still pass (this task doesn't change `confirmAndRemoveQr`'s or `SetQrSheet`'s external signatures, so `cvl_lookup_page.dart`/`cvl_search_page.dart`'s call sites need no changes and existing tests exercising them are unaffected).

- [ ] **Step 6: Commit**

```bash
git add lib/features/cvl_lookup/presentation/widgets/qr_actions.dart
git commit -m "refactor(cvl_lookup): route qr_actions dialogs through shared helpers"
```

---

### Task 7: CVL Record details (`cvl_lookup_page.dart`)

**Files:**
- Modify: `lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart`

**Interfaces:**
- Consumes: `InfoCard` from Task 3.

- [ ] **Step 1: Import `InfoCard` and replace the three `_SectionCard(...)` call sites**

Add the import:

```dart
import '../../../core/widgets/info_card.dart';
```

Replace each of the three `_SectionCard(...)` usages in
`_DetailsView.build()` with `InfoCard(...)` (identical arguments, only
the widget name changes), with a `const SizedBox(height: 12)` spacer
after each — `InfoCard`'s `Card` has `margin: EdgeInsets.zero` from
Task 1's `CardTheme`, where the deleted `_SectionCard` had
`margin: EdgeInsets.only(bottom: 12)`; these spacers replace that:

```dart
          InfoCard(
            title: 'Identity',
            rows: {
              'Full Name': record.fullName,
              if (record.gender.isNotEmpty) 'Gender': record.gender,
              if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Location',
            rows: {
              if (record.address.isNotEmpty) 'Address': record.address,
              if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
              if (record.municipality.isNotEmpty)
                'Municipality': record.municipality,
              if (record.precinctNo.isNotEmpty)
                'Precinct No.': record.precinctNo,
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Contact',
            rows: {
              if (record.contactNo.isNotEmpty) 'Contact No.': record.contactNo,
              if (record.email.isNotEmpty) 'Email': record.email,
            },
          ),
          const SizedBox(height: 12),
          if (record.sector.isNotEmpty) ...[
            InfoCard(title: 'Sector', rows: {'Sector': record.sector}),
            const SizedBox(height: 12),
          ],
```

`_QrCodeSection(qrCode: record.qrCode)` immediately follows in the
existing `ListView` — no other change needed there.

- [ ] **Step 2: Delete the now-unused `_SectionCard` class**

Delete the whole class at the bottom of the file:

```dart
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update `_QrCodeSection`'s container radius**

Replace:

```dart
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
```

with:

```dart
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
```

(the `Colors.white` fill itself is intentionally unchanged — see Global Constraints).

- [ ] **Step 4: Update `_ErrorView`'s button and text style**

Replace:

```dart
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
```

with:

```dart
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
```

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart`
Expected: `No issues found!`

Run: `flutter test test/features/cvl_lookup`
Expected: `cvl_search_page_dispose_test.dart` (which pushes `CvlLookupPage.byId`) still passes — confirms `InfoCard` renders without throwing in that flow.

- [ ] **Step 6: Commit**

```bash
git add lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart
git commit -m "feat(cvl_lookup): use shared InfoCard, FilledButton in CVL Record details"
```

---

### Task 8: CVL Edit Record (`cvl_edit_page.dart`)

**Files:**
- Modify: `lib/features/cvl_lookup/presentation/pages/cvl_edit_page.dart`

**Interfaces:**
- Consumes: `InfoCard` from Task 3.

- [ ] **Step 1: Import `InfoCard` and replace `_ReadOnlySection`'s usage**

Add the import:

```dart
import '../../../core/widgets/info_card.dart';
```

`_ReadOnlySection` has a subtitle disclaimer line
("Read-only — only contact details below can be edited.") that
`InfoCard`'s API has no slot for. Move that subtitle to sit above the
card instead of inside it — replace the `_ReadOnlySection(record: record)`
call in `_EditFormState.build()`:

```dart
            _ReadOnlySection(record: record),
```

with:

```dart
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Read-only — only contact details below can be edited.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            InfoCard(
              title: 'Record Details',
              rows: {
                'Full Name': record.fullName,
                if (record.gender.isNotEmpty) 'Gender': record.gender,
                if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
                if (record.address.isNotEmpty) 'Address': record.address,
                if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
                if (record.municipality.isNotEmpty)
                  'Municipality': record.municipality,
                if (record.precinctNo.isNotEmpty)
                  'Precinct No.': record.precinctNo,
                if (record.sector.isNotEmpty) 'Sector': record.sector,
              },
            ),
```

- [ ] **Step 2: Delete the now-unused `_ReadOnlySection` class**

Delete the whole class at the bottom of the file:

```dart
/// Everything about the record that isn't editable here — shown for
/// context so the person editing can confirm they have the right
/// record.
class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Full Name': record.fullName,
      if (record.gender.isNotEmpty) 'Gender': record.gender,
      if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
      if (record.address.isNotEmpty) 'Address': record.address,
      if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
      if (record.municipality.isNotEmpty) 'Municipality': record.municipality,
      if (record.precinctNo.isNotEmpty) 'Precinct No.': record.precinctNo,
      if (record.sector.isNotEmpty) 'Sector': record.sector,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only — only contact details below can be edited.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/features/cvl_lookup/presentation/pages/cvl_edit_page.dart`
Expected: `No issues found!`

Run: `flutter test test/features/cvl_lookup`
Expected: `cvl_edit_page_gender_test.dart` and
`cvl_lookup_cubit_shared_state_test.dart` (both pump `CvlEditPage`) still
pass — confirms `InfoCard` renders without throwing for a real record,
including the "MALE" legacy-gender-value case.

- [ ] **Step 4: Commit**

```bash
git add lib/features/cvl_lookup/presentation/pages/cvl_edit_page.dart
git commit -m "feat(cvl_lookup): use shared InfoCard in CVL Edit Record"
```

---

### Task 9: Application Details (`service_details_page.dart`)

**Files:**
- Modify: `lib/features/social_service_claim/presentation/pages/service_details_page.dart`

**Interfaces:**
- Consumes: `InfoCard` from Task 3.

- [ ] **Step 1: Import `InfoCard` and replace all six `_SectionCard(...)` call sites**

Add the import:

```dart
import '../../../core/widgets/info_card.dart';
```

Replace each of the six `_SectionCard(...)` usages in `_DetailsView.build()`
(`Application`, `Beneficiary`, `Address`, `Amount`, `Appointment`,
`Timeline`) with `InfoCard(...)` — identical `title`/`rows` arguments,
only the widget name changes. For example, the first one:

```dart
          _SectionCard(
            title: 'Application',
            rows: {
              'Application #': details.applicationNumber,
              'Status': details.status,
              'Service Type': details.serviceType,
              if (details.serviceSubCategory.isNotEmpty) 'Sub-category': details.serviceSubCategory,
              if (details.assistanceType.isNotEmpty) 'Assistance Type': details.assistanceType,
              if (details.briefDescription.isNotEmpty) 'Description': details.briefDescription,
            },
          ),
```

becomes:

```dart
          InfoCard(
            title: 'Application',
            rows: {
              'Application #': details.applicationNumber,
              'Status': details.status,
              'Service Type': details.serviceType,
              if (details.serviceSubCategory.isNotEmpty) 'Sub-category': details.serviceSubCategory,
              if (details.assistanceType.isNotEmpty) 'Assistance Type': details.assistanceType,
              if (details.briefDescription.isNotEmpty) 'Description': details.briefDescription,
            },
          ),
          const SizedBox(height: 12),
```

Apply the same rename to the remaining five cards, with the same
`const SizedBox(height: 12)` spacer after each (`InfoCard`'s `Card` has
`margin: EdgeInsets.zero` from Task 1's `CardTheme`, where the deleted
`_SectionCard` had `margin: EdgeInsets.only(bottom: 12)` — these spacers
replace that):

```dart
          InfoCard(
            title: 'Beneficiary',
            rows: {
              if (details.beneficiaryName.isNotEmpty) 'Beneficiary': details.beneficiaryName,
              'Name': details.applicantFullName,
              if (details.requestedForRelation.isNotEmpty) 'Relation': details.requestedForRelation,
              if (details.requestedForBirthdate.isNotEmpty) 'Birthdate': details.requestedForBirthdate,
              if (details.requestedForGender.isNotEmpty) 'Gender': details.requestedForGender,
              if (details.requestedForContact.isNotEmpty) 'Contact': details.requestedForContact,
              if (details.requestedForEmail.isNotEmpty) 'Email': details.requestedForEmail,
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Address',
            rows: {
              if (details.requestedForAddress.isNotEmpty) 'Address': details.requestedForAddress,
              if (details.requestedForBarangay.isNotEmpty) 'Barangay': details.requestedForBarangay,
              if (details.requestedForMunicipality.isNotEmpty) 'Municipality': details.requestedForMunicipality,
              if (details.requestedForProvince.isNotEmpty) 'Province': details.requestedForProvince,
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Amount',
            rows: {
              if (details.amount.isNotEmpty) 'Requested Amount': _formatAmount(details.amount),
              if (details.claimedAmount.isNotEmpty) 'Claimed Amount': _formatAmount(details.claimedAmount),
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Appointment',
            rows: {
              if (details.appointmentDate.isNotEmpty) 'Date': details.appointmentDate,
              if (details.appointmentTime.isNotEmpty) 'Time': details.appointmentTime,
              if (details.appointmentLocation.isNotEmpty) 'Location': details.appointmentLocation,
            },
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Timeline',
            rows: {
              if (details.dateRequested.isNotEmpty) 'Requested': details.dateRequested,
              if (details.dateApproved.isNotEmpty) 'Approved': details.dateApproved,
              if (details.dateScheduled.isNotEmpty) 'Scheduled': details.dateScheduled,
              if (details.dateReleased.isNotEmpty) 'Released': details.dateReleased,
              if (details.dateClaimed.isNotEmpty) 'Claimed': details.dateClaimed,
            },
          ),
          const SizedBox(height: 12),
```

`_DocumentsSection(details: details)` immediately follows the `Timeline`
card's spacer in the existing `ListView` — no other change needed there.

- [ ] **Step 2: Delete the now-unused `_SectionCard` class**

Delete the whole class at the bottom of the file:

```dart
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        entry.key,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update `_ErrorView`'s text style and button**

Replace:

```dart
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
```

with:

```dart
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
```

- [ ] **Step 4: Update the trailing "Scan Another" button**

Replace:

```dart
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another'),
          ),
```

with:

```dart
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another'),
          ),
```

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/social_service_claim/presentation/pages/service_details_page.dart`
Expected: `No issues found!`

Run: `flutter test test/features/social_service_claim` (if this directory
has existing tests) — expected: all still pass. If no tests exist for
this page today, this step is a manual run-the-app check instead: scan a
QR through "View Social Service Details" and confirm the details render
correctly with the new cards.

- [ ] **Step 6: Commit**

```bash
git add lib/features/social_service_claim/presentation/pages/service_details_page.dart
git commit -m "feat(service_details): use shared InfoCard in Application Details"
```

---

## Final verification (after all 9 tasks)

- [ ] Run `flutter analyze` (whole project) — expect `No issues found!`.
- [ ] Run `flutter test` (whole project) — expect every test to pass
      except `test/widget_test.dart`'s pre-existing pending-timer failure
      (confirmed unrelated to this plan in Task 1, Step 6).
- [ ] `grep -rn "ElevatedButton" lib/features/auth lib/features/dashboard lib/features/cvl_lookup lib/features/social_service_claim/presentation/pages/service_details_page.dart` —
      expect no matches (every `ElevatedButton` in the six named screens
      was replaced with `FilledButton` in Tasks 4-9).
- [ ] `grep -rn "class _SectionCard\|class _ReadOnlySection" lib/` —
      expect no matches (all three duplicated section-card
      implementations deleted in Tasks 7-9).
- [ ] Manually run the app through: login (see logo, submit, exit-confirm),
      dashboard (tinted menu icons, logout-confirm), scan into CVL Record
      details (InfoCard sections, QR image, Edit/Set-or-Remove-QR
      buttons), Edit CVL Record (InfoCard, save), and Application Details
      (InfoCard sections, documents) — confirm nothing regressed
      functionally and the new styling looks consistent across all six.

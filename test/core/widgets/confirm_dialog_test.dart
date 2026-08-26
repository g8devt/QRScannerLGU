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

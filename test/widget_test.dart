// Minimal smoke test: confirms the app initializes without throwing.
// No camera hardware is available in the test environment, so this only
// verifies that the widget tree builds — it does not exercise scanning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bataan_lgu_scanner/main.dart';

void main() {
  testWidgets('MyApp builds without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // AuthGate starts a 3s Future.delayed splash timer in initState();
    // without letting it fire, the test framework flags it as "still
    // pending" when the tree is disposed at the end of the test.
    await tester.pump(const Duration(seconds: 3));
  });
}

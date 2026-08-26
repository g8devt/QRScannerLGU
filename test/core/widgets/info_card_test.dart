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

// Basic smoke test for the Taha app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freelancertaha/theme.dart';

void main() {
  testWidgets('app theme builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: Text('TAHA'))),
      ),
    );

    expect(find.text('TAHA'), findsOneWidget);
  });
}

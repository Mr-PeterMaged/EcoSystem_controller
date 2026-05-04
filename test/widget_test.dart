import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app1/screens/signup_screen.dart';

void main() {
  testWidgets('renders signup screen for first account', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('Create Admin Account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}

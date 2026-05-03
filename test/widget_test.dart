import 'package:flutter_test/flutter_test.dart';

import 'package:app1/main.dart';

void main() {
  testWidgets('shows loading screen before login', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartHomeApp());

    expect(find.byType(SmartHomeApp), findsOneWidget);
    expect(find.text('Welcome'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}

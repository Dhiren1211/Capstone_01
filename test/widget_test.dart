import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartfind/main.dart';

void main() {
  testWidgets('user can submit a lost item report and see it on the feed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartFindApp());
    await tester.pumpAndSettle();

    expect(find.text('smartFind'), findsWidgets);

    final authFields = find.byType(TextFormField);
    await tester.enterText(authFields.at(0), 'demo@foundit.com');
    await tester.enterText(authFields.at(1), 'demo123');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Sign in'),
      find.byType(SingleChildScrollView),
      const Offset(0, -50),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Report an Item'), findsOneWidget);

    await tester.tap(find.text('I Lost Something'));
    await tester.pumpAndSettle();

    expect(find.text('Report Lost Item'), findsOneWidget);

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Silver Keychain');
    await tester.enterText(textFields.at(1), 'Union Square');
    await tester.enterText(
      textFields.at(2),
      'Small silver keychain with red tag',
    );
    await tester.enterText(textFields.at(3), 'demo@foundit.com');

    await tester.dragUntilVisible(
      find.text('Submit Report'),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('Success!'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Silver Keychain'), findsOneWidget);
  });
}

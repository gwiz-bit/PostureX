import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/main.dart';

void main() {
  testWidgets('App launches and shows Home screen with bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const PostureXApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);

    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();

    expect(find.text('Exercises'), findsWidgets);
    expect(find.text('Back Squat'), findsOneWidget);
  });
}

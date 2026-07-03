import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/main.dart';
import 'package:posturex/screens/main_shell.dart';
import 'package:posturex/theme/app_theme.dart';

void main() {
  testWidgets('App launches to the Login screen and can navigate to Register', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PostureXApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('MainShell shows Home screen with bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const MainShell()),
    );
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

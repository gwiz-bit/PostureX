import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/main.dart';
import 'package:posturex/screens/main_shell.dart';
import 'package:posturex/theme/app_theme.dart';

void main() {
  testWidgets('App launches to the Login screen and can navigate to Register', (
    WidgetTester tester,
  ) async {
    // Use a tall surface so the whole login form (incl. the Google button
    // and "Sign up" link below it) is mounted without needing to scroll.
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PostureXApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('Registering navigates into the onboarding questionnaire', (
    WidgetTester tester,
  ) async {
    // Use a tall surface so the whole registration form is mounted without
    // needing to scroll a lazy ListView to reveal the CTA button.
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PostureXApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@example.com');
    await tester.enterText(fields.at(2), 'password1');
    await tester.enterText(fields.at(3), 'password1');
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your goals'), findsOneWidget);

    // Back navigation returns to the account form.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
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

  testWidgets('Logging out from Profile returns to the Login screen', (
    WidgetTester tester,
  ) async {
    // Use a tall surface so the Log out row at the bottom of Profile is
    // mounted without needing to scroll a lazy ListView first.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const MainShell()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:posturex/main.dart';
import 'package:posturex/screens/main_shell.dart';
import 'package:posturex/services/api_client.dart';
import 'package:posturex/services/token_storage.dart';
import 'package:posturex/theme/app_theme.dart';
import 'package:posturex/widgets/app_logo.dart';

/// In-memory stand-in for flutter_secure_storage — the real plugin has no
/// working platform channel under `flutter test` and hangs rather than
/// throwing, so it must be swapped out rather than relied on to fail fast.
class _FakeSecureStorageBackend implements SecureStorageBackend {
  final _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// Canned backend so widget tests never make a real network call to the
/// dev server address (http://10.0.2.2:9000) — matches the request path
/// against the same endpoints ApiClient hits in the real app.
final _mockClient = MockClient((request) async {
  final path = request.url.path;
  const userJson = {
    'id': 1,
    'email': 'test@example.com',
    'full_name': 'Test User',
    'is_active': true,
    'is_admin': false,
    'created_at': '2024-01-01T00:00:00',
  };

  if (path == '/api/v1/auth/register' && request.method == 'POST') {
    return http.Response(jsonEncode(userJson), 201);
  }
  if (path == '/api/v1/auth/login' && request.method == 'POST') {
    return http.Response(
      jsonEncode({'access_token': 'mock-token', 'token_type': 'bearer'}),
      200,
    );
  }
  if (path == '/api/v1/auth/verify-otp' && request.method == 'POST') {
    return http.Response(
      jsonEncode({'access_token': 'mock-token', 'token_type': 'bearer'}),
      200,
    );
  }
  if (path == '/api/v1/auth/resend-otp' && request.method == 'POST') {
    return http.Response(jsonEncode({'message': 'Đã gửi lại mã OTP.'}), 200);
  }
  if (path == '/api/v1/users/me/profile') {
    return http.Response(
      jsonEncode({
        'gender': null,
        'height_cm': null,
        'weight_kg': null,
        'fitness_level': null,
        'weekly_goal': null,
      }),
      200,
    );
  }
  if (path == '/api/v1/users/me') {
    return http.Response(jsonEncode(userJson), 200);
  }
  if (path == '/api/v1/workouts' && request.method == 'GET') {
    return http.Response(jsonEncode(<dynamic>[]), 200);
  }
  if (path == '/api/v1/exercises' && request.method == 'GET') {
    return http.Response(
      jsonEncode([
        {
          'id': 1,
          'name': 'Back Squat',
          'description': null,
          'category': 'Strength',
          'difficulty': 'Beginner',
          'exercise_type': 'Standard',
          'demo_video_url': null,
          'thumbnail_url': null,
          'met': null,
          'is_active': true,
          'created_at': '2024-01-01T00:00:00',
        },
      ]),
      200,
    );
  }
  return http.Response(jsonEncode({'detail': 'Not found'}), 404);
});

void main() {
  ApiClient.instance = ApiClient(httpClient: _mockClient);
  TokenStorage.backend = _FakeSecureStorageBackend();

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

    // Registering no longer logs straight in — the account is unverified
    // until the emailed OTP is confirmed.
    expect(find.text('Check your email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your goals'), findsOneWidget);

    // Back navigation returns to the account form (OTP screen replaced
    // itself in the nav stack via pushReplacement).
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

  testWidgets('Tapping a day on the Home training plan calendar opens the day detail sheet', (
    WidgetTester tester,
  ) async {
    // Use a tall surface so the Training Plan calendar (below the fold) is
    // mounted without needing to scroll a lazy ListView first.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const MainShell()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training Plan'), findsOneWidget);

    await tester.tap(find.text('${DateTime.now().day}').first);
    await tester.pumpAndSettle();

    final hasWorkoutIcon = find.byType(AppLogo).evaluate().isNotEmpty;
    final hasRestIcon = find.byIcon(Icons.self_improvement_rounded).evaluate().isNotEmpty;
    expect(hasWorkoutIcon || hasRestIcon, isTrue);
  });

  testWidgets('Completing onboarding generates a plan and lands on a personalized Home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PostureXApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Plan Tester');
    await tester.enterText(fields.at(1), 'plan@example.com');
    await tester.enterText(fields.at(2), 'password1');
    await tester.enterText(fields.at(3), 'password1');
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your goals'), findsOneWidget);

    // Steps 1-13 all default to a valid selection, so Continue is always
    // enabled — step 14 (workout days) is reached after 13 taps.
    for (var i = 0; i < 13; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Set your workout days'), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await tester.pump(const Duration(milliseconds: 300));
    // The incoming route is still mid page-transition here, so its content
    // is technically "offstage" for a frame or two — skipOffstage: false
    // is the standard way to assert on it at this point.
    expect(
      find.text('Building your training plan', skipOffstage: false),
      findsOneWidget,
    );

    // Let the plan-generating animation finish, then settle into MainShell.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Plan Tester'), findsOneWidget);
    expect(find.text('Training Plan'), findsOneWidget);
  });
}

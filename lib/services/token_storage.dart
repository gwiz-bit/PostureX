import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal storage contract [TokenStorage] delegates to. Lets tests inject
/// an in-memory fake instead of the real [FlutterSecureStorage] plugin
/// (which has no working platform channel in the widget-test harness).
abstract class SecureStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> deleteAll();
}

class _FlutterSecureStorageBackend implements SecureStorageBackend {
  const _FlutterSecureStorageBackend();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Persists the signed-in session across app restarts. Backed by Android
/// Keystore / iOS Keychain via [FlutterSecureStorage] — never plain
/// SharedPreferences, since this holds an auth token.
class TokenStorage {
  TokenStorage._();

  /// Mutable so tests can swap in a fake [SecureStorageBackend].
  static SecureStorageBackend backend = const _FlutterSecureStorageBackend();

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';

  static const _workoutDaysKey = 'plan_workout_days';
  static const _weeklyGoalKey = 'plan_weekly_goal';
  static const _fitnessLevelKey = 'plan_fitness_level';
  static const _focusAreasKey = 'plan_focus_areas';
  static const _equipmentKey = 'plan_equipment';
  static const _goalsKey = 'plan_goals';
  static const _healthIssuesKey = 'plan_health_issues';

  static Future<void> saveSession({
    required String accessToken,
    required int userId,
    required String email,
  }) async {
    await Future.wait([
      backend.write(key: _tokenKey, value: accessToken),
      backend.write(key: _userIdKey, value: userId.toString()),
      backend.write(key: _emailKey, value: email),
    ]);
  }

  /// Returns `null` if no session is stored (or it's incomplete/corrupt).
  static Future<StoredSession?> readSession() async {
    final token = await backend.read(key: _tokenKey);
    final userId = await backend.read(key: _userIdKey);
    final email = await backend.read(key: _emailKey);
    if (token == null || userId == null || email == null) return null;
    final parsedId = int.tryParse(userId);
    if (parsedId == null) return null;
    return StoredSession(accessToken: token, userId: parsedId, email: email);
  }

  static Future<void> clear() async {
    await backend.deleteAll();
  }

  static Future<void> savePlanParams({
    required Set<String> workoutDays,
    required int weeklyGoal,
    required String fitnessLevel,
    required Set<String> focusAreas,
    required Set<String> equipment,
    required Set<String> goals,
    required Set<String> healthIssues,
  }) async {
    await Future.wait([
      backend.write(key: _workoutDaysKey, value: workoutDays.join(',')),
      backend.write(key: _weeklyGoalKey, value: weeklyGoal.toString()),
      backend.write(key: _fitnessLevelKey, value: fitnessLevel),
      backend.write(key: _focusAreasKey, value: focusAreas.join(',')),
      backend.write(key: _equipmentKey, value: equipment.join(',')),
      backend.write(key: _goalsKey, value: goals.join(',')),
      backend.write(key: _healthIssuesKey, value: healthIssues.join(',')),
    ]);
  }

  static Future<StoredPlanParams?> readPlanParams() async {
    final days = await backend.read(key: _workoutDaysKey);
    final goal = await backend.read(key: _weeklyGoalKey);
    final level = await backend.read(key: _fitnessLevelKey);
    if (days == null || goal == null || level == null) return null;
    Set<String> parse(String? s) =>
        (s == null || s.isEmpty) ? {} : s.split(',').toSet();
    return StoredPlanParams(
      workoutDays: parse(days),
      weeklyGoal: int.tryParse(goal) ?? 4,
      fitnessLevel: level,
      focusAreas: parse(await backend.read(key: _focusAreasKey)),
      equipment: parse(await backend.read(key: _equipmentKey)),
      goals: parse(await backend.read(key: _goalsKey)),
      healthIssues: parse(await backend.read(key: _healthIssuesKey)),
    );
  }
}

class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final int userId;
  final String email;
}

class StoredPlanParams {
  const StoredPlanParams({
    required this.workoutDays,
    required this.weeklyGoal,
    required this.fitnessLevel,
    required this.focusAreas,
    required this.equipment,
    required this.goals,
    required this.healthIssues,
  });

  final Set<String> workoutDays;
  final int weeklyGoal;
  final String fitnessLevel;
  final Set<String> focusAreas;
  final Set<String> equipment;
  final Set<String> goals;
  final Set<String> healthIssues;
}

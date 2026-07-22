import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../admin/models/admin_models.dart';
import '../models/app_notification.dart';
import '../models/auth_response.dart';
import '../models/chat_message.dart';
import '../models/profile_data.dart';
import '../models/subscription.dart';
import '../models/user_profile.dart';
import '../models/video.dart';
import '../models/workout.dart';
import '../models/user_session.dart';
import 'api_exception.dart';

/// Thin wrapper over the posture-x-backend REST API. A singleton (consistent
/// with [UserSession] being a static class — no DI framework in this app),
/// but the underlying [http.Client] is injectable so tests can supply a
/// `MockClient` instead of hitting a real server.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Mutable (not `final`) so tests can swap in an `ApiClient` backed by a
  /// `MockClient` from `package:http/testing.dart` instead of a real server.
  static ApiClient instance = ApiClient();

  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, String> _headers({bool auth = false, bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth && UserSession.accessToken != null) {
      headers['Authorization'] = 'Bearer ${UserSession.accessToken}';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = 'Something went wrong. Please try again.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) {
        message = body['detail'] as String;
      } else if (body is Map && body['detail'] is List) {
        // FastAPI/Pydantic validation errors (422) shape `detail` as a list
        // of {"loc", "msg", "type"} objects rather than a plain string —
        // surface the first one (e.g. a password-strength rule) instead of
        // falling through to the generic message.
        final errors = body['detail'] as List;
        if (errors.isNotEmpty && errors.first is Map && errors.first['msg'] is String) {
          message = errors.first['msg'] as String;
        }
      }
    } catch (_) {
      // Non-JSON error body (e.g. a raw 500) — keep the generic message.
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> _get(String path, {bool auth = false}) async {
    final response = await _http.get(_uri(path), headers: _headers(auth: auth, json: false));
    return _decode(response);
  }

  Future<dynamic> _post(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> _patch(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final response = await _http.patch(
      _uri(path),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> _put(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final response = await _http.put(
      _uri(path),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> _delete(String path, {bool auth = false}) async {
    final response = await _http.delete(_uri(path), headers: _headers(auth: auth, json: false));
    return _decode(response);
  }

  // --- Auth -----------------------------------------------------------

  /// Creates the account (unverified) and triggers an OTP email — the
  /// account cannot log in until [verifyOtp] succeeds.
  Future<UserProfile> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final json = await _post('/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Confirms the OTP sent to [email] — returns a token directly (acts as
  /// login) once the code matches.
  Future<AuthResponse> verifyOtp({required String email, required String otpCode}) async {
    final json = await _post('/api/v1/auth/verify-otp', body: {
      'email': email,
      'otp_code': otpCode,
    });
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Requests a fresh OTP code be emailed to [email] (no-op server-side if
  /// already verified).
  Future<void> resendOtp({required String email}) async {
    await _post('/api/v1/auth/resend-otp', body: {'email': email});
  }

  Future<AuthResponse> login({required String email, required String password}) async {
    final json = await _post('/api/v1/auth/login', body: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Exchanges a Google ID token (from [GoogleAuthService]) for a backend
  /// session — auto-registers the account server-side on first sign-in,
  /// so this doubles as both login and register.
  Future<AuthResponse> loginWithGoogle({required String idToken}) async {
    final json = await _post('/api/v1/auth/google', body: {'id_token': idToken});
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Requests a password-reset code be emailed to [email]. Always succeeds
  /// (backend intentionally never reveals whether the email is registered)
  /// — returns the generic confirmation message to show the user.
  Future<String> forgotPassword({required String email}) async {
    final json = await _post('/api/v1/auth/forgot-password', body: {'email': email});
    return (json as Map<String, dynamic>)['message'] as String;
  }

  /// Completes a password reset using the code emailed via [forgotPassword].
  /// Throws [ApiException] with a specific message on an invalid/expired
  /// token, a weak password, or a confirm-password mismatch.
  Future<String> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final json = await _post('/api/v1/auth/reset-password', body: {
      'token': token,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
    return (json as Map<String, dynamic>)['message'] as String;
  }

  // --- User -------------------------------------------------------------

  Future<UserProfile> fetchMe() async {
    final json = await _get('/api/v1/users/me', auth: true);
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  Future<UserProfile> updateMe({String? fullName, String? password}) async {
    final json = await _patch('/api/v1/users/me', auth: true, body: {
      if (fullName != null) 'full_name': fullName,
      if (password != null) 'password': password,
    });
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Saves the subset of onboarding answers the backend has columns for
  /// (Age/Gender/HeightCm/WeightKg/FitnessLevel + a WorkoutsPerWeek goal).
  Future<ProfileData> updateProfile({
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? fitnessLevel,
    int? weeklyGoal,
  }) async {
    final json = await _put('/api/v1/users/me/profile', auth: true, body: {
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (fitnessLevel != null) 'fitness_level': fitnessLevel,
      if (weeklyGoal != null) 'weekly_goal': weeklyGoal,
    });
    return ProfileData.fromJson(json as Map<String, dynamic>);
  }

  Future<ProfileData> fetchProfile() async {
    final json = await _get('/api/v1/users/me/profile', auth: true);
    return ProfileData.fromJson(json as Map<String, dynamic>);
  }

  // --- Workouts -----------------------------------------------------------

  Future<Workout> createWorkout({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  }) async {
    final json = await _post('/api/v1/workouts', auth: true, body: {
      'exercise': exercise,
      'total_reps': totalReps,
      'duration_seconds': durationSeconds,
      'accuracy_score': accuracyScore,
      'started_at': startedAt.toUtc().toIso8601String(),
    });
    return Workout.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Workout>> fetchWorkouts() async {
    final json = await _get('/api/v1/workouts', auth: true);
    return (json as List).map((e) => Workout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Workout> fetchWorkout(int id) async {
    final json = await _get('/api/v1/workouts/$id', auth: true);
    return Workout.fromJson(json as Map<String, dynamic>);
  }

  // --- Videos -------------------------------------------------------------

  Future<Video> uploadVideo({required File file, required String exercise}) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/videos/upload', {'exercise': exercise}),
    );
    request.headers.addAll(_headers(auth: true, json: false));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final json = _decode(response);
    return Video.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Video>> fetchVideos() async {
    final json = await _get('/api/v1/videos', auth: true);
    return (json as List).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Video> fetchVideo(int id) async {
    final json = await _get('/api/v1/videos/$id', auth: true);
    return Video.fromJson(json as Map<String, dynamic>);
  }

  // --- Admin: stats & users ------------------------------------------------

  Future<SystemStats> fetchAdminStats() async {
    final json = await _get('/api/v1/admin/stats', auth: true);
    return SystemStats.fromJson(json as Map<String, dynamic>);
  }

  Future<List<AdminUser>> fetchAdminUsers() async {
    final json = await _get('/api/v1/admin/users', auth: true);
    return (json as List).map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminUser> updateAdminUser(
    int userId, {
    String? fullName,
    bool? isActive,
    bool? isAdmin,
  }) async {
    final json = await _patch('/api/v1/admin/users/$userId', auth: true, body: {
      if (fullName != null) 'full_name': fullName,
      if (isActive != null) 'is_active': isActive,
      if (isAdmin != null) 'is_admin': isAdmin,
    });
    return AdminUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteAdminUser(int userId) async {
    await _delete('/api/v1/admin/users/$userId', auth: true);
  }

  // --- Admin: workouts & videos ---------------------------------------------

  Future<List<AdminWorkout>> fetchAdminWorkouts() async {
    final json = await _get('/api/v1/admin/workouts', auth: true);
    return (json as List).map((e) => AdminWorkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteAdminWorkout(int workoutId) async {
    await _delete('/api/v1/admin/workouts/$workoutId', auth: true);
  }

  Future<List<AdminVideo>> fetchAdminVideos() async {
    final json = await _get('/api/v1/admin/videos', auth: true);
    return (json as List).map((e) => AdminVideo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteAdminVideo(int videoId) async {
    await _delete('/api/v1/admin/videos/$videoId', auth: true);
  }

  // --- Admin: AI config -------------------------------------------------

  Future<AIConfig> fetchAIConfig() async {
    final json = await _get('/api/v1/admin/config', auth: true);
    return AIConfig.fromJson(json as Map<String, dynamic>);
  }

  Future<AIConfig> updateAIConfig(AIConfig config) async {
    final json = await _patch('/api/v1/admin/config', auth: true, body: config.toJson());
    return AIConfig.fromJson(json as Map<String, dynamic>);
  }

  // --- Admin: plans (SubscriptionPlans) --------------------------------

  Future<List<AdminPlan>> fetchAdminPlans() async {
    final json = await _get('/api/v1/admin/plans', auth: true);
    return (json as List).map((e) => AdminPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminPlan> createAdminPlan({
    required String name,
    required double priceMonthly,
    String currency = 'VND',
    String? features,
    bool isActive = true,
  }) async {
    final json = await _post('/api/v1/admin/plans', auth: true, body: {
      'name': name,
      'price_monthly': priceMonthly,
      'currency': currency,
      'features': features,
      'is_active': isActive,
    });
    return AdminPlan.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminPlan> updateAdminPlan(
    int planId, {
    String? name,
    double? priceMonthly,
    String? currency,
    String? features,
    bool? isActive,
  }) async {
    final json = await _patch('/api/v1/admin/plans/$planId', auth: true, body: {
      if (name != null) 'name': name,
      if (priceMonthly != null) 'price_monthly': priceMonthly,
      if (currency != null) 'currency': currency,
      if (features != null) 'features': features,
      if (isActive != null) 'is_active': isActive,
    });
    return AdminPlan.fromJson(json as Map<String, dynamic>);
  }

  // --- Admin: revenue (Payments) ----------------------------------------

  Future<RevenueStats> fetchAdminRevenue() async {
    final json = await _get('/api/v1/admin/revenue', auth: true);
    return RevenueStats.fromJson(json as Map<String, dynamic>);
  }

  // --- Admin: broadcast notifications -------------------------------------

  Future<List<BroadcastHistoryItem>> fetchBroadcastHistory() async {
    final json = await _get('/api/v1/admin/notifications/broadcast', auth: true);
    return (json as List)
        .map((e) => BroadcastHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> sendBroadcast({required String title, String? body}) async {
    final json = await _post('/api/v1/admin/notifications/broadcast', auth: true, body: {
      'title': title,
      'body': body,
    });
    return (json as Map<String, dynamic>)['recipients'] as int;
  }

  // --- Exercises ------------------------------------------------------

  /// The published exercise library — used by the app's own Exercises tab.
  Future<List<AdminExercise>> fetchExercises() async {
    final json = await _get('/api/v1/exercises');
    return (json as List).map((e) => AdminExercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminExercise>> fetchAdminExercises() async {
    final json = await _get('/api/v1/admin/exercises', auth: true);
    return (json as List).map((e) => AdminExercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminExercise> createAdminExercise({
    required String name,
    String? description,
    String? category,
    String? difficulty,
    String exerciseType = 'Standard',
  }) async {
    final json = await _post('/api/v1/admin/exercises', auth: true, body: {
      'name': name,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'exercise_type': exerciseType,
    });
    return AdminExercise.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminExercise> updateAdminExercise(int exerciseId, {bool? isActive}) async {
    final json = await _patch('/api/v1/admin/exercises/$exerciseId', auth: true, body: {
      if (isActive != null) 'is_active': isActive,
    });
    return AdminExercise.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteAdminExercise(int exerciseId) async {
    await _delete('/api/v1/admin/exercises/$exerciseId', auth: true);
  }

  /// Uploads a guide video for [exerciseId] — shown to every user during a
  /// live analyze session for that exercise instead of the bundled asset
  /// fallback (see `guideVideoAssetFor`). Replaces any existing video.
  Future<AdminExercise> uploadAdminExerciseVideo({
    required int exerciseId,
    required File file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/admin/exercises/$exerciseId/video'),
    );
    request.headers.addAll(_headers(auth: true, json: false));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final json = _decode(response);
    return AdminExercise.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminExercise> deleteAdminExerciseVideo(int exerciseId) async {
    final json = await _delete('/api/v1/admin/exercises/$exerciseId/video', auth: true);
    return AdminExercise.fromJson(json as Map<String, dynamic>);
  }

  // --- AI Coach ---------------------------------------------------------

  /// Sends [message] to the AI Coach along with [history] (the caller's
  /// own running conversation — the backend doesn't persist chat history)
  /// so replies stay personalized to the user's real profile/workout data.
  Future<String> sendCoachMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final json = await _post('/api/v1/coach/chat', auth: true, body: {
      'message': message,
      'history': history.map((m) => m.toJson()).toList(),
    });
    return (json as Map<String, dynamic>)['reply'] as String;
  }

  // --- Notifications ------------------------------------------------------

  Future<List<AppNotification>> fetchNotifications() async {
    final json = await _get('/api/v1/notifications', auth: true);
    return (json as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Số thông báo chưa đọc — cho badge trên icon chuông ở Home.
  Future<int> fetchUnreadCount() async {
    final json = await _get('/api/v1/notifications/unread-count', auth: true);
    return (json as Map<String, dynamic>)['unread'] as int;
  }

  Future<AppNotification> markNotificationRead(int id) async {
    final json = await _patch('/api/v1/notifications/$id/read', auth: true);
    return AppNotification.fromJson(json as Map<String, dynamic>);
  }

  Future<void> markAllNotificationsRead() async {
    await _patch('/api/v1/notifications/read-all', auth: true);
  }

  // --- Subscriptions & payments -------------------------------------------

  /// Giá là thông tin công khai — endpoint này không cần token.
  Future<List<SubscriptionPlan>> fetchPlans() async {
    final json = await _get('/api/v1/subscriptions/plans');
    return (json as List)
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gói đang dùng — `null` nếu user chưa mua gói nào.
  Future<UserSubscription?> fetchMySubscription() async {
    final json = await _get('/api/v1/subscriptions/me', auth: true);
    if (json == null) return null;
    return UserSubscription.fromJson(json as Map<String, dynamic>);
  }

  /// Tạo đơn chờ thanh toán và lấy URL VNPay để mở trong WebView.
  Future<Checkout> checkout(int planId) async {
    final json = await _post(
      '/api/v1/subscriptions/checkout',
      auth: true,
      body: {'plan_id': planId},
    );
    return Checkout.fromJson(json as Map<String, dynamic>);
  }

  /// Huỷ tự động gia hạn. **Không mất quyền ngay** — gói vẫn chạy tới hết hạn.
  Future<UserSubscription> cancelSubscription() async {
    final json = await _post('/api/v1/subscriptions/cancel', auth: true);
    return UserSubscription.fromJson(json as Map<String, dynamic>);
  }

  /// Bật lại tự động gia hạn sau khi đã huỷ.
  Future<UserSubscription> resumeSubscription() async {
    final json = await _post('/api/v1/subscriptions/resume', auth: true);
    return UserSubscription.fromJson(json as Map<String, dynamic>);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_notification.dart';
import '../models/auth_response.dart';
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
  /// (Gender/HeightCm/WeightKg/FitnessLevel + a WorkoutsPerWeek goal).
  Future<ProfileData> updateProfile({
    String? gender,
    double? heightCm,
    double? weightKg,
    String? fitnessLevel,
    int? weeklyGoal,
  }) async {
    final json = await _put('/api/v1/users/me/profile', auth: true, body: {
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

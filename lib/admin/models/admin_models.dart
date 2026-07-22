/// Models mapping the real `/api/v1/admin/*` backend responses — replaces
/// the old fully-mock `AppUser`/`Plan`/`AppNotification` models.

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isAdmin,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  String get displayName => (fullName?.trim().isNotEmpty ?? false) ? fullName! : email;

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        isActive: json['is_active'] as bool,
        isAdmin: json['is_admin'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class AdminWorkout {
  const AdminWorkout({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.totalReps,
    required this.accuracyScore,
    required this.durationSeconds,
    required this.startedAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String exercise;
  final int totalReps;
  final double? accuracyScore;
  final double? durationSeconds;
  final DateTime startedAt;
  final DateTime createdAt;

  factory AdminWorkout.fromJson(Map<String, dynamic> json) => AdminWorkout(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        exercise: json['exercise'] as String,
        totalReps: json['total_reps'] as int,
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
        startedAt: DateTime.parse(json['started_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class AdminVideo {
  const AdminVideo({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.originalFilename,
    required this.totalReps,
    required this.accuracyScore,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String exercise;
  final String? originalFilename;
  final int totalReps;
  final double? accuracyScore;
  final DateTime createdAt;

  factory AdminVideo.fromJson(Map<String, dynamic> json) => AdminVideo(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        exercise: json['exercise'] as String,
        originalFilename: json['original_filename'] as String?,
        totalReps: json['total_reps'] as int,
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SystemStats {
  const SystemStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.adminUsers,
    required this.totalVideos,
    required this.totalWorkouts,
    required this.totalReps,
  });

  final int totalUsers;
  final int activeUsers;
  final int adminUsers;
  final int totalVideos;
  final int totalWorkouts;
  final int totalReps;

  factory SystemStats.fromJson(Map<String, dynamic> json) => SystemStats(
        totalUsers: json['total_users'] as int,
        activeUsers: json['active_users'] as int,
        adminUsers: json['admin_users'] as int,
        totalVideos: json['total_videos'] as int,
        totalWorkouts: json['total_workouts'] as int,
        totalReps: json['total_reps'] as int,
      );
}

class AIConfig {
  const AIConfig({
    required this.squatKneeDepthThreshold,
    required this.squatBackStraightMin,
    required this.squatKneeOvershootRatio,
    required this.squatRepDownThreshold,
    required this.squatRepUpThreshold,
    required this.poseModelComplexity,
    required this.poseMinDetectionConfidence,
  });

  final double squatKneeDepthThreshold;
  final double squatBackStraightMin;
  final double squatKneeOvershootRatio;
  final double squatRepDownThreshold;
  final double squatRepUpThreshold;
  final int poseModelComplexity;
  final double poseMinDetectionConfidence;

  factory AIConfig.fromJson(Map<String, dynamic> json) => AIConfig(
        squatKneeDepthThreshold: (json['squat_knee_depth_threshold'] as num).toDouble(),
        squatBackStraightMin: (json['squat_back_straight_min'] as num).toDouble(),
        squatKneeOvershootRatio: (json['squat_knee_overshoot_ratio'] as num).toDouble(),
        squatRepDownThreshold: (json['squat_rep_down_threshold'] as num).toDouble(),
        squatRepUpThreshold: (json['squat_rep_up_threshold'] as num).toDouble(),
        poseModelComplexity: json['pose_model_complexity'] as int,
        poseMinDetectionConfidence: (json['pose_min_detection_confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'squat_knee_depth_threshold': squatKneeDepthThreshold,
        'squat_back_straight_min': squatBackStraightMin,
        'squat_knee_overshoot_ratio': squatKneeOvershootRatio,
        'squat_rep_down_threshold': squatRepDownThreshold,
        'squat_rep_up_threshold': squatRepUpThreshold,
        'pose_model_complexity': poseModelComplexity,
        'pose_min_detection_confidence': poseMinDetectionConfidence,
      };

  AIConfig copyWith({
    double? squatKneeDepthThreshold,
    double? squatBackStraightMin,
    double? squatKneeOvershootRatio,
    double? squatRepDownThreshold,
    double? squatRepUpThreshold,
    int? poseModelComplexity,
    double? poseMinDetectionConfidence,
  }) =>
      AIConfig(
        squatKneeDepthThreshold: squatKneeDepthThreshold ?? this.squatKneeDepthThreshold,
        squatBackStraightMin: squatBackStraightMin ?? this.squatBackStraightMin,
        squatKneeOvershootRatio: squatKneeOvershootRatio ?? this.squatKneeOvershootRatio,
        squatRepDownThreshold: squatRepDownThreshold ?? this.squatRepDownThreshold,
        squatRepUpThreshold: squatRepUpThreshold ?? this.squatRepUpThreshold,
        poseModelComplexity: poseModelComplexity ?? this.poseModelComplexity,
        poseMinDetectionConfidence: poseMinDetectionConfidence ?? this.poseMinDetectionConfidence,
      );
}

/// Gói cước quản trị — trỏ vào bảng `SubscriptionPlans` thật (hệ MoMo), khác
/// với model `Plan` cũ (đã orphan, không còn dùng).
class AdminPlan {
  const AdminPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.currency,
    required this.features,
    required this.isActive,
  });

  final int id;
  final String name;
  final double priceMonthly;
  final String currency;
  final String? features;
  final bool isActive;

  factory AdminPlan.fromJson(Map<String, dynamic> json) => AdminPlan(
        id: json['id'] as int,
        name: json['name'] as String,
        // Backend trả DECIMAL, JSON hoá thành chuỗi ("99000.00") chứ không phải số.
        priceMonthly: double.parse(json['price_monthly'].toString()),
        currency: json['currency'] as String,
        features: json['features'] as String?,
        isActive: json['is_active'] as bool,
      );
}

class AdminPayment {
  const AdminPayment({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paidAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userEmail;
  final String planName;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final DateTime createdAt;

  factory AdminPayment.fromJson(Map<String, dynamic> json) => AdminPayment(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        userEmail: json['user_email'] as String,
        planName: json['plan_name'] as String,
        amount: double.parse(json['amount'].toString()),
        currency: json['currency'] as String,
        status: json['status'] as String,
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class RevenueByPlan {
  const RevenueByPlan({
    required this.planId,
    required this.planName,
    required this.revenue,
    required this.paymentCount,
  });

  final int planId;
  final String planName;
  final double revenue;
  final int paymentCount;

  factory RevenueByPlan.fromJson(Map<String, dynamic> json) => RevenueByPlan(
        planId: json['plan_id'] as int,
        planName: json['plan_name'] as String,
        revenue: double.parse(json['revenue'].toString()),
        paymentCount: json['payment_count'] as int,
      );
}

class RevenueStats {
  const RevenueStats({
    required this.totalRevenue,
    required this.totalPaidPayments,
    required this.byPlan,
    required this.recentPayments,
  });

  final double totalRevenue;
  final int totalPaidPayments;
  final List<RevenueByPlan> byPlan;
  final List<AdminPayment> recentPayments;

  factory RevenueStats.fromJson(Map<String, dynamic> json) => RevenueStats(
        totalRevenue: double.parse(json['total_revenue'].toString()),
        totalPaidPayments: json['total_paid_payments'] as int,
        byPlan: (json['by_plan'] as List)
            .map((e) => RevenueByPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentPayments: (json['recent_payments'] as List)
            .map((e) => AdminPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BroadcastHistoryItem {
  const BroadcastHistoryItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.recipients,
  });

  final String title;
  final String? body;
  final DateTime createdAt;
  final int recipients;

  factory BroadcastHistoryItem.fromJson(Map<String, dynamic> json) => BroadcastHistoryItem(
        title: json['title'] as String,
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        recipients: json['recipients'] as int,
      );
}

class AdminExercise {
  const AdminExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.exerciseType,
    required this.isActive,
    required this.demoVideoUrl,
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String exerciseType;
  final bool isActive;
  final String? demoVideoUrl;

  factory AdminExercise.fromJson(Map<String, dynamic> json) => AdminExercise(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        difficulty: json['difficulty'] as String?,
        exerciseType: json['exercise_type'] as String,
        isActive: json['is_active'] as bool,
        demoVideoUrl: json['demo_video_url'] as String?,
      );
}

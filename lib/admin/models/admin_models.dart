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

class AdminPromoCode {
  const AdminPromoCode({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.expiresAt,
    required this.isActive,
  });

  final int id;
  final String code;
  final int discountPercent;
  final DateTime? expiresAt;
  final bool isActive;

  factory AdminPromoCode.fromJson(Map<String, dynamic> json) => AdminPromoCode(
        id: json['id'] as int,
        code: json['code'] as String,
        discountPercent: json['discount_percent'] as int,
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
        isActive: json['is_active'] as bool,
      );
}

class AdminTransaction {
  const AdminTransaction({
    required this.id,
    required this.userId,
    required this.planId,
    required this.amountVnd,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final int planId;
  final int amountVnd;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  factory AdminTransaction.fromJson(Map<String, dynamic> json) => AdminTransaction(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        planId: json['plan_id'] as int,
        amountVnd: json['amount_vnd'] as int,
        paymentMethod: json['payment_method'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class RevenueStats {
  const RevenueStats({
    required this.totalRevenueVnd,
    required this.totalTransactions,
    required this.revenueByPlan,
    required this.recentTransactions,
  });

  final int totalRevenueVnd;
  final int totalTransactions;
  final Map<String, int> revenueByPlan;
  final List<AdminTransaction> recentTransactions;

  factory RevenueStats.fromJson(Map<String, dynamic> json) => RevenueStats(
        totalRevenueVnd: json['total_revenue_vnd'] as int,
        totalTransactions: json['total_transactions'] as int,
        revenueByPlan: (json['revenue_by_plan'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as int)),
        recentTransactions: (json['recent_transactions'] as List)
            .map((e) => AdminTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
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
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String exerciseType;
  final bool isActive;

  factory AdminExercise.fromJson(Map<String, dynamic> json) => AdminExercise(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        difficulty: json['difficulty'] as String?,
        exerciseType: json['exercise_type'] as String,
        isActive: json['is_active'] as bool,
      );
}

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.audience,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String audience;
  final DateTime createdAt;

  factory AdminNotification.fromJson(Map<String, dynamic> json) => AdminNotification(
        id: json['id'] as int,
        title: json['title'] as String,
        content: json['content'] as String,
        audience: json['audience'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

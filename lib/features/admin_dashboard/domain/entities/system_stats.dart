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

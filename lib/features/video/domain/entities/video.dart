/// Maps the backend's `VideoOut` schema. Analysis runs server-side in the
/// background after upload (see `video_analysis_service.py`) — right after
/// upload [durationSeconds]/[totalReps]/[accuracyScore]/[analysisSummary]
/// are still null/0; poll `GET /videos/{id}` until [analysisSummary] is
/// non-null (it is ALWAYS set once the background job finishes, even for
/// an unsupported exercise or an unreadable file — see
/// `VideoUploadController`'s polling logic).
class Video {
  const Video({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.originalFilename,
    required this.durationSeconds,
    required this.totalReps,
    required this.accuracyScore,
    required this.analysisSummary,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String exercise;
  final String? originalFilename;
  final double? durationSeconds;
  final int totalReps;
  final double? accuracyScore;
  final String? analysisSummary;
  final DateTime createdAt;

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        exercise: json['exercise'] as String,
        originalFilename: json['original_filename'] as String?,
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
        totalReps: json['total_reps'] as int,
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        analysisSummary: json['analysis_summary'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

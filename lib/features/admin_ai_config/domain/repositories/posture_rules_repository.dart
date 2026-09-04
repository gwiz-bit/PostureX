import '../entities/posture_rules.dart';

abstract class PostureRulesRepository {
  /// Các bài tập có analyzer, kèm số ngưỡng đang ghi đè.
  Future<List<TunableExercise>> listExercises({String? search});

  /// Ngưỡng chỉnh được của một bài, kèm mặc định và giá trị hiện tại.
  Future<ExerciseRules> getRules(int exerciseId);

  /// Đặt lại ngưỡng ghi đè. [values] là trạng thái đầy đủ mong muốn — khoá
  /// vắng mặt sẽ bị xoá và bài quay về mặc định của analyzer.
  Future<ExerciseRules> saveRules(int exerciseId, Map<String, double> values);
}

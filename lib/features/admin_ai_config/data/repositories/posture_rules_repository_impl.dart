import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/posture_rules.dart';
import '../../domain/repositories/posture_rules_repository.dart';
import '../datasources/posture_rules_remote_data_source.dart';

class PostureRulesRepositoryImpl implements PostureRulesRepository {
  const PostureRulesRepositoryImpl(this._remote);

  final PostureRulesRemoteDataSource _remote;

  @override
  Future<List<TunableExercise>> listExercises({String? search}) =>
      _run(() => _remote.listExercises(search: search));

  @override
  Future<ExerciseRules> getRules(int exerciseId) => _run(() => _remote.getRules(exerciseId));

  @override
  Future<ExerciseRules> saveRules(int exerciseId, Map<String, double> values) =>
      _run(() => _remote.saveRules(exerciseId, values));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      // Giữ nguyên `e.message`: với lỗi 422 đó là câu giải thích của backend
      // nói rõ ngưỡng nào sai và khoảng hợp lệ là bao nhiêu. Thay bằng câu
      // chung chung là admin mất đúng thông tin cần để sửa.
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}

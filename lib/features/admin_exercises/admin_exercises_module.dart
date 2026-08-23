import '../../services/api_client.dart';
import 'data/datasources/admin_exercise_remote_data_source.dart';
import 'data/repositories/admin_exercise_repository_impl.dart';
import 'domain/repositories/admin_exercise_repository.dart';
import 'domain/usecases/create_admin_exercise.dart';
import 'domain/usecases/delete_admin_exercise.dart';
import 'domain/usecases/delete_admin_exercise_video.dart';
import 'domain/usecases/get_admin_exercises.dart';
import 'domain/usecases/update_admin_exercise.dart';
import 'domain/usecases/upload_admin_exercise_video.dart';
import 'domain/usecases/validate_exercise_video_file.dart';

class AdminExercisesModule {
  AdminExercisesModule._();

  static AdminExerciseRepository _repository() =>
      AdminExerciseRepositoryImpl(AdminExerciseRemoteDataSource(ApiClient.instance));

  static GetAdminExercises getAdminExercises() => GetAdminExercises(_repository());

  static CreateAdminExercise createAdminExercise() => CreateAdminExercise(_repository());

  static UpdateAdminExercise updateAdminExercise() => UpdateAdminExercise(_repository());

  static DeleteAdminExercise deleteAdminExercise() => DeleteAdminExercise(_repository());

  static UploadAdminExerciseVideo uploadAdminExerciseVideo() =>
      UploadAdminExerciseVideo(_repository());

  static DeleteAdminExerciseVideo deleteAdminExerciseVideo() =>
      DeleteAdminExerciseVideo(_repository());

  static const ValidateExerciseVideoFile validateExerciseVideoFile = ValidateExerciseVideoFile();
}

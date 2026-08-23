import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/usecases/get_exercises.dart';

class ExercisesController extends ChangeNotifier {
  ExercisesController({required GetExercises getExercises}) : _getExercises = getExercises;

  final GetExercises _getExercises;

  bool isLoading = true;
  String? errorMessage;
  List<Exercise> exercises = const [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      exercises = await _getExercises();
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

const kAdminExerciseVideoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv'];
const kAdminExerciseMaxVideoBytes = 500 * 1024 * 1024;

/// Pure validation, no I/O — extracted out of `_ExercisesScreenState` so the
/// extension/size rules are unit-testable without a widget pump.
class ValidateExerciseVideoFile {
  const ValidateExerciseVideoFile();

  /// Returns a user-facing error message, or `null` if [path]/[sizeBytes]
  /// are valid.
  String? call({required String path, required int sizeBytes}) {
    final dot = path.lastIndexOf('.');
    final extension = dot == -1 ? '' : path.substring(dot).toLowerCase();
    if (!kAdminExerciseVideoExtensions.contains(extension)) {
      return 'Unsupported format: $extension. Use mp4, mov, avi, webm, or mkv.';
    }
    if (sizeBytes > kAdminExerciseMaxVideoBytes) {
      return 'File is too large. Max size is 500 MB.';
    }
    return null;
  }
}

const kAllowedVideoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv'];
const kMaxVideoUploadBytes = 500 * 1024 * 1024;

/// Pure validation, no I/O — extracted out of the upload screen so the
/// format/size rules are unit-testable without picking a real file.
class ValidateVideoFile {
  const ValidateVideoFile();

  /// Returns a user-facing error message, or `null` if the file is valid.
  String? call({required String path, required int sizeBytes}) {
    final dot = path.lastIndexOf('.');
    final extension = dot == -1 ? '' : path.substring(dot).toLowerCase();

    if (!kAllowedVideoExtensions.contains(extension)) {
      return 'Unsupported format: $extension. Use mp4, mov, avi, webm, or mkv.';
    }
    if (sizeBytes > kMaxVideoUploadBytes) {
      return 'File is too large. Max size is 500 MB.';
    }
    return null;
  }
}

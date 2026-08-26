import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/features/video/domain/usecases/validate_video_file.dart';

void main() {
  const usecase = ValidateVideoFile();

  group('ValidateVideoFile', () {
    test('accepts a supported extension under the size cap', () {
      final error = usecase(path: '/tmp/squat.mp4', sizeBytes: 10 * 1024 * 1024);
      expect(error, isNull);
    });

    test('rejects an unsupported extension', () {
      final error = usecase(path: '/tmp/squat.avi_backup', sizeBytes: 1024);
      expect(error, contains('Unsupported format'));
    });

    test('rejects a file over the 50 MB cap', () {
      final error = usecase(path: '/tmp/squat.mp4', sizeBytes: kMaxVideoUploadBytes + 1);
      expect(error, contains('too large'));
    });

    test('extension match is case-insensitive', () {
      final error = usecase(path: '/tmp/SQUAT.MP4', sizeBytes: 1024);
      expect(error, isNull);
    });
  });
}

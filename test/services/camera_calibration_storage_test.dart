import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/services/camera_calibration_storage.dart';
import 'package:posturex/services/token_storage.dart';

class _FakeBackend implements SecureStorageBackend {
  final Map<String, String> data = {};
  bool failing = false;

  @override
  Future<String?> read({required String key}) async {
    if (failing) throw StateError('kho bảo mật lỗi');
    return data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failing) throw StateError('kho bảo mật lỗi');
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => data.remove(key);

  @override
  Future<void> deleteAll() async => data.clear();
}

void main() {
  late _FakeBackend fake;
  late SecureStorageBackend original;

  setUp(() {
    original = TokenStorage.backend;
    fake = _FakeBackend();
    TokenStorage.backend = fake;
  });
  tearDown(() => TokenStorage.backend = original);

  test('chưa lưu gì thì dùng mặc định', () async {
    expect(
      await CameraCalibrationStorage.readFrontPreviewMirroredByPlugin(),
      CameraCalibrationStorage.defaultFrontPreviewMirroredByPlugin,
    );
  });

  test('lưu rồi đọc lại đúng cả hai giá trị', () async {
    await CameraCalibrationStorage.writeFrontPreviewMirroredByPlugin(false);
    expect(
      await CameraCalibrationStorage.readFrontPreviewMirroredByPlugin(),
      isFalse,
    );
    await CameraCalibrationStorage.writeFrontPreviewMirroredByPlugin(true);
    expect(
      await CameraCalibrationStorage.readFrontPreviewMirroredByPlugin(),
      isTrue,
    );
  });

  test('kho bảo mật lỗi không ném ra ngoài — không chặn việc mở camera', () async {
    fake.failing = true;
    expect(
      await CameraCalibrationStorage.readFrontPreviewMirroredByPlugin(),
      CameraCalibrationStorage.defaultFrontPreviewMirroredByPlugin,
    );
    await CameraCalibrationStorage.writeFrontPreviewMirroredByPlugin(false);
  });

  test('đăng xuất (TokenStorage.clear) đưa hiệu chỉnh về mặc định', () async {
    await CameraCalibrationStorage.writeFrontPreviewMirroredByPlugin(false);
    await TokenStorage.clear();
    expect(
      await CameraCalibrationStorage.readFrontPreviewMirroredByPlugin(),
      CameraCalibrationStorage.defaultFrontPreviewMirroredByPlugin,
    );
  });
}

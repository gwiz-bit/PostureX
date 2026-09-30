import 'token_storage.dart';

/// Ghi nhớ kết quả hiệu chỉnh "plugin camera có tự lật gương preview camera
/// trước không" (xem `PreviewMirrorPlan`) để người dùng không phải bấm sửa lại ở
/// mỗi phiên tập.
///
/// Dùng chung kho bảo mật với [TokenStorage] (qua `TokenStorage.backend`, nên test
/// thay bằng bản giả được). Hệ quả: [TokenStorage.clear] lúc đăng xuất cũng xoá giá
/// trị này và nó quay về [defaultFrontPreviewMirroredByPlugin] — chấp nhận, vì đây
/// chỉ là một lần bấm.
class CameraCalibrationStorage {
  CameraCalibrationStorage._();

  /// Mặc định `true`: máy đầu tiên có ảnh chụp lỗi (30/09/2026) cho thấy plugin có
  /// tự lật texture preview camera trước. Máy nào cư xử ngược lại thì bấm nút sửa
  /// trên màn phân tích một lần.
  static const defaultFrontPreviewMirroredByPlugin = true;

  static const _key = 'front_preview_mirrored_by_plugin';

  static Future<bool> readFrontPreviewMirroredByPlugin() async {
    try {
      final value = await TokenStorage.backend.read(key: _key);
      if (value == null) return defaultFrontPreviewMirroredByPlugin;
      return value == '1';
    } catch (_) {
      // Kho bảo mật lỗi thì dùng mặc định — không được chặn việc mở camera.
      return defaultFrontPreviewMirroredByPlugin;
    }
  }

  static Future<void> writeFrontPreviewMirroredByPlugin(bool value) async {
    try {
      await TokenStorage.backend.write(key: _key, value: value ? '1' : '0');
    } catch (_) {
      // Không lưu được thì lần sau dùng lại mặc định; không ảnh hưởng phiên này.
    }
  }
}

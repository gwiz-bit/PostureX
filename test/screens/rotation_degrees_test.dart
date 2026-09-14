import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/screens/analyze_session_screen.dart';

/// `rotationDegreesFor` từng dùng công thức bù riêng cho camera trước
/// (`(360 - sensorOrientation) % 360`), với lý do "cảm biến camera trước
/// gắn ngược chiều vật lý". Lý do đó lẫn lộn hai việc khác nhau: xoay ảnh
/// (hàm này) và lật gương trái/phải (việc riêng, nay do `Transform` bọc
/// chung camera+khung xương trong `build()` lo, xem CHANGELOG 14/09/2026).
///
/// Công thức chuẩn của Android (giống code mẫu chính thức
/// `camera_view.dart` trong `google_ml_kit_flutter`) là:
/// - Camera trước: `(sensorOrientation + bùThiếtBị) % 360`
/// - Camera sau: `(sensorOrientation - bùThiếtBị + 360) % 360`
///
/// Với thiết bị khoá ở chiều dọc tự nhiên (duy nhất app này hỗ trợ),
/// `bùThiếtBị = 0`, nên CẢ HAI công thức rút gọn về đúng `sensorOrientation`
/// — không bù, không đảo. Công thức bù cũ sai lệch 180° cho camera trước,
/// đúng khớp với lỗi thật đã gặp trên máy: khớp mặt hiện ở ngang thắt lưng
/// thay vì gần đầu (xem CHANGELOG 14/09/2026).
CameraDescription _camera({required CameraLensDirection lens, required int sensorOrientation}) =>
    CameraDescription(name: 'test', lensDirection: lens, sensorOrientation: sensorOrientation);

void main() {
  group('rotationDegreesFor', () {
    test('camera sau: dùng thẳng sensorOrientation', () {
      final camera = _camera(lens: CameraLensDirection.back, sensorOrientation: 90);

      expect(rotationDegreesFor(camera), 90);
    });

    test('camera trước: cũng dùng thẳng sensorOrientation, KHÔNG lấy phần bù', () {
      // Trước khi sửa (14/09/2026), hàm này trả về phần bù 90 — sai 180° so
      // với giá trị đúng 270, gây khớp mặt hiện ở thắt lưng thay vì gần đầu.
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 270);

      expect(rotationDegreesFor(camera), 270);
    });

    test('camera trước với sensorOrientation = 90 vẫn dùng thẳng, không đổi thành 270', () {
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 90);

      expect(rotationDegreesFor(camera), 90);
    });

    test('camera trước với sensorOrientation = 0 vẫn dùng thẳng', () {
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 0);

      expect(rotationDegreesFor(camera), 0);
    });
  });
}

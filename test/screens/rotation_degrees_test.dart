import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/screens/analyze_session_screen.dart';

/// Khoá lại lỗi thứ hai phát hiện cùng lúc với lỗi khung xương không hiện:
/// công thức xoay ảnh dùng thẳng `sensorOrientation` cho MỌI camera, trong
/// khi camera trước gắn ngược chiều vật lý so với camera sau nên cần công
/// thức bù riêng — `(360 - sensorOrientation) % 360`, không phải chính nó.
///
/// Hai lỗi (xoay sai + lật gương sai, xem skeleton_painter_test.dart) cùng
/// gây một triệu chứng — "không thấy khung xương ở camera trước" — nên rất
/// dễ tưởng chỉ có một lỗi rồi sửa nửa vời.
CameraDescription _camera({required CameraLensDirection lens, required int sensorOrientation}) =>
    CameraDescription(name: 'test', lensDirection: lens, sensorOrientation: sensorOrientation);

void main() {
  group('rotationDegreesFor', () {
    test('camera sau: dùng thẳng sensorOrientation', () {
      final camera = _camera(lens: CameraLensDirection.back, sensorOrientation: 90);

      expect(rotationDegreesFor(camera), 90);
    });

    test('camera trước: lấy phần bù (360 - sensorOrientation), KHÔNG dùng thẳng', () {
      // Trước khi sửa, hàm này (thật ra là gán thẳng sensorOrientation) sẽ
      // trả về 270 — sai công thức, quay ảnh lệch hẳn hướng cần thiết.
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 270);

      expect(rotationDegreesFor(camera), 90);
    });

    test('camera trước với sensorOrientation = 90 vẫn ra kết quả đúng công thức', () {
      // Ca hiếm nhưng có thật trên một số thiết bị — chốt công thức tổng
      // quát (360 - x) % 360 thay vì chỉ nhớ "270 thì đổi thành 90".
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 90);

      expect(rotationDegreesFor(camera), 270);
    });

    test('camera trước với sensorOrientation = 0 không tràn âm', () {
      final camera = _camera(lens: CameraLensDirection.front, sensorOrientation: 0);

      expect(rotationDegreesFor(camera), 0);
    });
  });
}

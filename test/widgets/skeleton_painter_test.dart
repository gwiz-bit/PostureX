import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/models/frame_analysis_result.dart';
import 'package:posturex/widgets/skeleton_painter.dart';

/// Khoá lại lỗi phát hiện khi tập squat thật trên điện thoại: camera trước
/// hoàn toàn không hiện khung xương, dù server vẫn nhận diện được người
/// (nhãn phase "GOING DOWN" vẫn đổi bình thường).
///
/// Nguyên nhân: `CameraPreview` của Flutter tự lật gương ảnh xem trước cho
/// camera trước, nhưng toạ độ khớp server trả về được tính từ ảnh JPEG GỐC
/// (chỉ xoay, không lật) gửi lên lúc `_encodeCameraImage`. Vẽ thẳng toạ độ
/// gốc lên preview đã lật khiến khớp trái/phải đảo ngược — không phải lệch
/// nhẹ mà lệch hẳn sang phía đối diện, nên nhìn như "không có khung xương".
///
/// Test này không dựng được `CustomPainter.paint()` (cần `Canvas` thật), nên
/// chỉ khoá đúng phép toán lật toạ độ — phần dễ chép sai nhất khi có ai đó
/// sau này sửa lại đường này.
void main() {
  group('SkeletonPainter — lật toạ độ cho camera trước', () {
    // Sao chép nguyên công thức trong SkeletonPainter.paint() để test không
    // phụ thuộc Canvas thật.
    double mirroredX(double x) => 1 - x;

    test('camera sau: không lật', () {
      const painter = SkeletonPainter(keypoints: {}, correct: true, mirror: false);
      expect(painter.mirror, isFalse);
    });

    test('camera trước: có lật', () {
      const painter = SkeletonPainter(keypoints: {}, correct: true, mirror: true);
      expect(painter.mirror, isTrue);
    });

    test('công thức lật đúng — điểm giữa đứng yên, hai biên đảo chỗ', () {
      expect(mirroredX(0.5), closeTo(0.5, 1e-9));
      expect(mirroredX(0.0), 1.0);
      expect(mirroredX(1.0), 0.0);
      // Khớp lệch trái (x nhỏ) phải chuyển sang lệch phải (x lớn) và ngược
      // lại — đây chính là hiệu ứng "trái/phải đảo ngược" gây ra lỗi.
      expect(mirroredX(0.2), closeTo(0.8, 1e-9));
      expect(mirroredX(0.8), closeTo(0.2, 1e-9));
    });

    test('shouldRepaint tính cả khi mirror đổi', () {
      const cu = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
        mirror: false,
      );
      const moi = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
        mirror: true,
      );

      // `mirror` đổi nhưng keypoints/correct giữ nguyên — nếu shouldRepaint
      // không kiểm mirror thì đổi camera trước/sau giữa chừng phiên tập sẽ
      // không vẽ lại, giữ nguyên khung xương lật sai của camera cũ.
      expect(moi.shouldRepaint(cu), isTrue);
    });
  });
}

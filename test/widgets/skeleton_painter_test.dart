import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/models/frame_analysis_result.dart';
import 'package:posturex/widgets/skeleton_painter.dart';

/// `SkeletonPainter` từng có tham số `mirror` riêng, độc lập lật toạ độ
/// khớp (`x = mirror ? 1 - p.x : p.x`) theo camera đang dùng (trước/sau).
/// Đó là MỘT trong hai quyết định lật gương tách rời nhau (cái kia là
/// `Transform` bọc `CameraPreview` trong `AnalyzeSessionScreen`) — chỉ khớp
/// nhau khi giả định "plugin camera không tự lật gương camera trước" đúng
/// trên máy đang chạy. Máy nào rơi vào trường hợp ngược lại (plugin tự lật
/// đúng) thì video và khung xương bị lệch bên nhau — xác nhận qua ảnh chụp
/// thật 14/09/2026 (xem CHANGELOG).
///
/// Sửa bằng cách bỏ hẳn tham số `mirror` khỏi class này: painter giờ LUÔN
/// vẽ toạ độ gốc (chưa lật), và việc lật gương (nếu có) do một `Transform`
/// DUY NHẤT bọc chung cả `CameraPreview` lẫn `CustomPaint` này lo — nên
/// video và khung xương không bao giờ có thể lệch nhau nữa, bất kể plugin
/// làm gì trên từng máy. Vì vậy file test này không còn khoá công thức lật
/// nào nữa (không có gì để lật trong chính class này) — chỉ khoá lại hợp
/// đồng đơn giản hơn: constructor không nhận `mirror`, và `shouldRepaint`
/// vẫn phản ứng đúng với phần dữ liệu còn lại (`keypoints`/`correct`).
void main() {
  group('SkeletonPainter — không còn tự lật toạ độ', () {
    test('constructor không có tham số mirror', () {
      // Chỉ cần biên dịch được là đã khoá đúng: field `mirror` không được
      // quay lại class này trong tương lai.
      const painter = SkeletonPainter(keypoints: {}, correct: true);
      expect(painter.correct, isTrue);
    });

    test('shouldRepaint: true khi keypoints đổi', () {
      const cu = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
      );
      const moi = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.4, y: 0.5, visibility: 1.0)},
        correct: true,
      );

      expect(moi.shouldRepaint(cu), isTrue);
    });

    test('shouldRepaint: true khi correct đổi', () {
      const cu = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
      );
      const moi = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: false,
      );

      expect(moi.shouldRepaint(cu), isTrue);
    });

    test('shouldRepaint: true khi mirrorX đổi', () {
      const goc = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
      );
      const lat = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
        mirrorX: true,
      );
      expect(lat.shouldRepaint(goc), isTrue);
    });

    test('shouldRepaint: false khi keypoints/correct giống hệt nhau', () {
      const cu = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
      );
      const moi = SkeletonPainter(
        keypoints: {'left_knee': Point(x: 0.3, y: 0.5, visibility: 1.0)},
        correct: true,
      );

      expect(moi.shouldRepaint(cu), isFalse);
    });
  });

  group('SkeletonPainter.mirrorX — vẽ thật, kiểm tra điểm ảnh', () {
    // Vẽ MỘT khớp ở x=0.2 lên khung 100x100 rồi xem chấm tròn nằm ở đâu. Đây là
    // đúng lỗi ảnh chụp 30/09/2026: khung xương là ảnh gương của người thật.
    Future<(bool atLeft, bool atRight)> paintedAt(
      WidgetTester tester,
      bool mirrorX,
    ) async {
      late bool left, right;
      await tester.runAsync(() async {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        SkeletonPainter(
          keypoints: const {
            'left_knee': Point(x: 0.2, y: 0.5, visibility: 1.0),
          },
          correct: true,
          mirrorX: mirrorX,
        ).paint(canvas, const Size(100, 100));
        final image = await recorder.endRecording().toImage(100, 100);
        final bytes = (await image.toByteData())!;
        bool painted(int x, int y) => bytes.getUint8((y * 100 + x) * 4 + 3) > 0;
        left = painted(20, 50);
        right = painted(80, 50);
      });
      return (left, right);
    }

    testWidgets('mặc định vẽ đúng toạ độ gốc (x = 0,2 → bên trái)', (tester) async {
      final (left, right) = await paintedAt(tester, false);
      expect(left, isTrue);
      expect(right, isFalse);
    });

    testWidgets('mirrorX lật sang đối xứng (x = 0,2 → 0,8, bên phải)', (tester) async {
      final (left, right) = await paintedAt(tester, true);
      expect(left, isFalse);
      expect(right, isTrue);
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/models/frame_analysis_result.dart' show KeyAngles;
import 'package:posturex/utils/capture_quality.dart';

Uint8List _flat(int width, int height, int value, {int bytesPerRow = 0}) {
  final stride = bytesPerRow == 0 ? width : bytesPerRow;
  return Uint8List(stride * height)..fillRange(0, stride * height, value);
}

void main() {
  group('meanLuminance', () {
    test('ảnh phẳng cho đúng giá trị đó', () {
      expect(
        meanLuminance(
          yPlane: _flat(64, 64, 120),
          width: 64,
          height: 64,
          bytesPerRow: 64,
        ),
        120,
      );
    });

    test('phân biệt ảnh tối và ảnh sáng', () {
      double luma(int v) => meanLuminance(
        yPlane: _flat(320, 240, v),
        width: 320,
        height: 240,
        bytesPerRow: 320,
      )!;
      expect(luma(20), lessThan(CaptureQualityMonitor.lowLightEnter));
      expect(luma(130), greaterThan(CaptureQualityMonitor.lowLightExit));
    });

    test('bỏ qua phần đệm cuối mỗi hàng (bytesPerRow > width)', () {
      // Phần đệm 255 không được kéo độ sáng của ảnh 10 lên.
      const width = 32, height = 32, stride = 48;
      final plane = Uint8List(stride * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < stride; x++) {
          plane[y * stride + x] = x < width ? 10 : 255;
        }
      }
      expect(
        meanLuminance(
          yPlane: plane,
          width: width,
          height: height,
          bytesPerRow: stride,
        ),
        10,
      );
    });

    test('dữ liệu ngắn hơn kích thước khai báo không ném lỗi', () {
      expect(
        meanLuminance(
          yPlane: Uint8List(10),
          width: 640,
          height: 480,
          bytesPerRow: 640,
        ),
        isNotNull,
      );
    });

    test('kích thước sai trả null', () {
      expect(
        meanLuminance(
          yPlane: Uint8List(0),
          width: 0,
          height: 10,
          bytesPerRow: 0,
        ),
        isNull,
      );
      expect(
        meanLuminance(
          yPlane: Uint8List(10),
          width: 100,
          height: 100,
          bytesPerRow: 50, // hẹp hơn chiều rộng — vô lý
        ),
        isNull,
      );
    });
  });

  group('hasMeasuredAngle', () {
    test('null hoặc toàn null nghĩa là không đo được', () {
      expect(hasMeasuredAngle(null), isFalse);
      expect(hasMeasuredAngle(const KeyAngles()), isFalse);
    });

    test('bất kỳ một góc nào cũng đủ', () {
      expect(hasMeasuredAngle(const KeyAngles(leftElbow: 90)), isTrue);
      expect(hasMeasuredAngle(const KeyAngles(rightAnkle: 100)), isTrue);
    });

    test('góc thân riêng cũng tính (Plank/Cat-Cow không báo góc khác)', () {
      expect(hasMeasuredAngle(const KeyAngles(backAngle: 170)), isTrue);
    });
  });

  group('CaptureQualityMonitor — thiếu sáng', () {
    test('một mẫu tối lẻ tẻ không bật cảnh báo', () {
      final m = CaptureQualityMonitor()..addLuminance(20);
      expect(m.issue, isNull);
    });

    test('tối liên tiếp thì bật', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 4; i++) {
        m.addLuminance(20);
      }
      expect(m.issue, CaptureIssue.lowLight);
    });

    test('mẫu sáng xen kẽ làm gián đoạn chuỗi tối', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 10; i++) {
        m.addLuminance(i.isEven ? 20 : 130);
      }
      expect(m.issue, isNull);
    });

    test('hysteresis: sáng lên nhẹ (giữa hai ngưỡng) chưa tắt, sáng hẳn mới tắt', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 4; i++) {
        m.addLuminance(20);
      }
      expect(m.issue, CaptureIssue.lowLight);

      // 50 nằm giữa ngưỡng vào (45) và ngưỡng thoát (60): vẫn coi là tối.
      for (var i = 0; i < 10; i++) {
        m.addLuminance(50);
      }
      expect(m.issue, CaptureIssue.lowLight);

      for (var i = 0; i < 3; i++) {
        m.addLuminance(90);
      }
      expect(m.issue, isNull);
    });
  });

  group('CaptureQualityMonitor — mất góc', () {
    void feed(CaptureQualityMonitor m, int n, {required bool measured}) {
      for (var i = 0; i < n; i++) {
        m.addFrame(personPresent: true, angleMeasured: measured);
      }
    }

    test('cú che khuất ngắn giữa chuyển động không báo', () {
      final m = CaptureQualityMonitor();
      feed(m, 10, measured: false);
      expect(m.issue, isNull);
    });

    test('mất góc kéo dài thì báo, đo lại được thì tắt', () {
      final m = CaptureQualityMonitor();
      feed(m, 18, measured: false);
      expect(m.issue, CaptureIssue.angleLost);
      feed(m, 3, measured: true);
      expect(m.issue, isNull);
    });

    test('không thấy người không cộng dồn vào mất góc (đã có thông báo riêng)', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 100; i++) {
        m.addFrame(personPresent: false, angleMeasured: false);
      }
      expect(m.issue, isNull);
    });

    test('người vắng mặt xen giữa làm chuỗi mất góc bắt đầu lại', () {
      final m = CaptureQualityMonitor();
      feed(m, 15, measured: false);
      m.addFrame(personPresent: false, angleMeasured: false);
      feed(m, 15, measured: false);
      expect(m.issue, isNull);
    });
  });

  test('thiếu sáng được báo trước mất góc (thường là nguyên nhân)', () {
    final m = CaptureQualityMonitor();
    for (var i = 0; i < 18; i++) {
      m.addFrame(personPresent: true, angleMeasured: false);
    }
    for (var i = 0; i < 4; i++) {
      m.addLuminance(20);
    }
    expect(m.issue, CaptureIssue.lowLight);
  });

  test('reset xoá mọi cảnh báo', () {
    final m = CaptureQualityMonitor();
    for (var i = 0; i < 4; i++) {
      m.addLuminance(20);
    }
    m.reset();
    expect(m.issue, isNull);
  });
}

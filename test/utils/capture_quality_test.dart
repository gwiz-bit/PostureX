import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/models/frame_analysis_result.dart'
    show KeyAngles, Point;
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

  group('torsoLengthInFrameHeights', () {
    Point p(double x, double y, {double v = 1.0}) =>
        Point(x: x, y: y, visibility: v);

    Map<String, Point> standing({double scale = 1.0}) => {
      'left_shoulder': p(0.45, 0.30),
      'right_shoulder': p(0.55, 0.30),
      'left_hip': p(0.45, 0.30 + 0.25 * scale),
      'right_hip': p(0.55, 0.30 + 0.25 * scale),
    };

    test('người đứng: thân = khoảng cách trung điểm vai → hông', () {
      expect(
        torsoLengthInFrameHeights(standing(), aspect: 0.75),
        closeTo(0.25, 1e-9),
      );
    });

    test('người nhỏ hơn thì thân ngắn hơn theo đúng tỉ lệ', () {
      final to = torsoLengthInFrameHeights(standing(), aspect: 0.75)!;
      final nho = torsoLengthInFrameHeights(standing(scale: 0.5), aspect: 0.75)!;
      expect(nho, closeTo(to / 2, 1e-9));
    });

    test('người nằm ngang (plank) vẫn đo đúng nhờ nhân aspect cho trục x', () {
      // Thân nằm ngang dài 0,5 chiều RỘNG khung; khung 0,5 rộng/cao ⇒ 0,25 chiều cao.
      final plank = {
        'left_shoulder': p(0.2, 0.5),
        'right_shoulder': p(0.2, 0.5),
        'left_hip': p(0.7, 0.5),
        'right_hip': p(0.7, 0.5),
      };
      expect(torsoLengthInFrameHeights(plank, aspect: 0.5), closeTo(0.25, 1e-9));
      // Thiếu aspect (coi như 1) sẽ ra 0,5 — sai gấp đôi.
      expect(torsoLengthInFrameHeights(plank, aspect: 1.0), closeTo(0.5, 1e-9));
    });

    test('thiếu một bên thì dùng cặp vai–hông bên còn lại', () {
      final mot = {
        'left_shoulder': p(0.45, 0.30),
        'left_hip': p(0.45, 0.55),
        'right_shoulder': p(0.55, 0.30, v: 0.1),
        'right_hip': p(0.55, 0.55, v: 0.1),
      };
      expect(torsoLengthInFrameHeights(mot, aspect: 0.75), closeTo(0.25, 1e-9));
    });

    test('không đủ khớp nhìn rõ hoặc không có người thì trả null', () {
      expect(torsoLengthInFrameHeights(null, aspect: 0.75), isNull);
      expect(torsoLengthInFrameHeights({}, aspect: 0.75), isNull);
      final mo = {
        'left_shoulder': p(0.45, 0.30, v: 0.2),
        'left_hip': p(0.45, 0.55, v: 0.2),
      };
      expect(torsoLengthInFrameHeights(mo, aspect: 0.75), isNull);
      expect(torsoLengthInFrameHeights(standing(), aspect: 0), isNull);
    });
  });

  group('CaptureQualityMonitor — người quá nhỏ trong khung', () {
    test('một vài mẫu nhỏ thoáng qua không báo', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 10; i++) {
        m.addBodySize(0.08);
      }
      expect(m.issue, isNull);
    });

    test('nhỏ liên tục thì báo, to lại thì tắt', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 15; i++) {
        m.addBodySize(0.10);
      }
      expect(m.issue, CaptureIssue.tooSmall);
      for (var i = 0; i < 6; i++) {
        m.addBodySize(0.22);
      }
      expect(m.issue, isNull);
    });

    test('người vừa khung (thân ~0,20) không bao giờ bị báo', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 200; i++) {
        m.addBodySize(0.20);
      }
      expect(m.issue, isNull);
    });

    test('hysteresis: giữa hai ngưỡng (0,15) vẫn coi là nhỏ, vượt 0,16 mới tắt', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 15; i++) {
        m.addBodySize(0.10);
      }
      expect(m.issue, CaptureIssue.tooSmall);
      for (var i = 0; i < 30; i++) {
        m.addBodySize(0.15);
      }
      expect(m.issue, CaptureIssue.tooSmall);
      for (var i = 0; i < 6; i++) {
        m.addBodySize(0.17);
      }
      expect(m.issue, isNull);
    });

    test('mất người (null) xoá đà đếm, không cộng dồn qua lúc vắng mặt', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 10; i++) {
        m.addBodySize(0.08);
      }
      m.addBodySize(null);
      for (var i = 0; i < 10; i++) {
        m.addBodySize(0.08);
      }
      expect(m.issue, isNull);
    });

    test('ưu tiên: thiếu sáng > quá nhỏ > mất góc', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 18; i++) {
        m.addFrame(personPresent: true, angleMeasured: false);
      }
      expect(m.issue, CaptureIssue.angleLost);
      for (var i = 0; i < 15; i++) {
        m.addBodySize(0.08);
      }
      expect(m.issue, CaptureIssue.tooSmall);
      for (var i = 0; i < 4; i++) {
        m.addLuminance(20);
      }
      expect(m.issue, CaptureIssue.lowLight);
    });

    test('reset xoá cả cảnh báo quá nhỏ', () {
      final m = CaptureQualityMonitor();
      for (var i = 0; i < 15; i++) {
        m.addBodySize(0.08);
      }
      m.reset();
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

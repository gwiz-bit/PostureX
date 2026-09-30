import 'dart:typed_data';

import '../models/frame_analysis_result.dart' show KeyAngles;

/// Vì sao app đang đứng yên không đếm rep dù người dùng vẫn tập — để báo cho
/// họ biết thay vì im lặng.
///
/// Analyzer phía server bỏ qua LẶNG LẼ mọi frame mà khớp cần đo không đủ tin
/// cậy: góc trả về `null`, số rep đứng yên, và không có lỗi nào được báo. Với
/// người tập thì trông như "app hỏng" chứ không phải "thiếu sáng" hay "máy che
/// mất khớp".
enum CaptureIssue {
  /// Khung hình quá tối — ảnh nhiễu, nhận diện tư thế kém.
  lowLight,

  /// Thấy người nhưng không đo được góc khớp nào của bài này (khớp bị che khỏi
  /// khung hình, bị máy/vật che, hoặc quá tối để nhận rõ).
  angleLost,
}

/// Độ sáng trung bình (0..255) của khung hình, lấy mẫu thưa từ mặt phẳng Y
/// (độ chói) của `CameraImage`.
///
/// Cả NV21 (Android, một plane) lẫn YUV420 (ba plane) đều đặt mặt phẳng Y ở
/// đầu, xếp theo hàng với bước nhảy [bytesPerRow] — nên chỉ cần đọc byte ở đó,
/// không phải đổi màu. Lấy mẫu mỗi [step] điểm theo cả hai chiều nên tốn cỡ
/// vài nghìn phép đọc mỗi lần (rẻ hơn nhiều so với một frame nhận diện).
///
/// Trả `null` nếu không lấy được mẫu nào (kích thước sai hoặc dữ liệu rỗng).
double? meanLuminance({
  required Uint8List yPlane,
  required int width,
  required int height,
  required int bytesPerRow,
  int step = 16,
}) {
  if (width <= 0 || height <= 0 || bytesPerRow < width || step <= 0) {
    return null;
  }
  var sum = 0;
  var count = 0;
  for (var y = 0; y < height; y += step) {
    final rowStart = y * bytesPerRow;
    for (var x = 0; x < width; x += step) {
      final index = rowStart + x;
      if (index >= yPlane.length) continue;
      sum += yPlane[index];
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

/// Frame này có đo được ít nhất một góc khớp không.
///
/// Tính cả `backAngle`: một số analyzer (Plank, Cat-Cow) chỉ báo góc thân, và
/// coi đó là "không đo được" sẽ báo động giả liên tục ở các bài đó. Đổi lại
/// Squat/Lunge với gối bị che nhưng lưng vẫn thấy sẽ không bị báo — chấp nhận,
/// vì báo nhầm nghiêm trọng hơn bỏ sót ở đây.
bool hasMeasuredAngle(KeyAngles? angles) {
  if (angles == null) return false;
  return angles.leftKnee != null ||
      angles.rightKnee != null ||
      angles.leftHip != null ||
      angles.rightHip != null ||
      angles.leftElbow != null ||
      angles.rightElbow != null ||
      angles.leftShoulder != null ||
      angles.rightShoulder != null ||
      angles.leftAnkle != null ||
      angles.rightAnkle != null ||
      angles.backAngle != null;
}

/// Công tắc có độ trễ (hysteresis): chỉ bật sau [enterAfter] mẫu liên tiếp thoả
/// điều kiện và chỉ tắt sau [exitAfter] mẫu liên tiếp không thoả — để một frame
/// nhiễu không làm cảnh báo nhấp nháy.
class _Debounced {
  _Debounced({required this.enterAfter, required this.exitAfter});

  final int enterAfter;
  final int exitAfter;
  bool active = false;
  int _streak = 0;

  void feed(bool condition) {
    // Streak đếm số mẫu liên tiếp NGƯỢC với trạng thái hiện tại.
    if (condition != active) {
      _streak++;
      if (_streak >= (active ? exitAfter : enterAfter)) {
        active = condition;
        _streak = 0;
      }
    } else {
      _streak = 0;
    }
  }

  void reset() {
    active = false;
    _streak = 0;
  }
}

/// Theo dõi chất lượng ghi hình của MỘT phiên tập và cho biết có nên cảnh báo
/// người dùng không.
///
/// Mọi con số ngưỡng dưới đây là ƯỚC LƯỢNG, chưa đo trên máy thật — độ sáng
/// trung bình của cả khung hình còn phụ thuộc cảnh (tường tối, cửa sổ sáng), nên
/// cần hiệu chỉnh theo log `[capture-quality]` khi test thật.
class CaptureQualityMonitor {
  /// Độ sáng trung bình (0..255) dưới mức này là "tối". Ngưỡng thoát cao hơn
  /// ngưỡng vào để không nhấp nháy quanh một mức sáng ở giữa.
  static const lowLightEnter = 45.0;
  static const lowLightExit = 60.0;

  final _lowLight = _Debounced(enterAfter: 4, exitAfter: 3);

  /// ~1,5 giây liên tiếp ở 12 fps mới coi là mất góc: ngắn hơn thì chỉ là một
  /// cú che khuất thoáng qua giữa chuyển động.
  final _angleLost = _Debounced(enterAfter: 18, exitAfter: 3);

  /// Vấn đề đang cần báo, `null` nếu ổn. Tối ưu tiên hơn "mất góc" vì thường
  /// chính là nguyên nhân của nó.
  CaptureIssue? get issue {
    if (_lowLight.active) return CaptureIssue.lowLight;
    if (_angleLost.active) return CaptureIssue.angleLost;
    return null;
  }

  void addLuminance(double meanLuma) => _lowLight.feed(meanLuma < _lowLightThreshold());

  double _lowLightThreshold() => _lowLight.active ? lowLightExit : lowLightEnter;

  /// [personPresent] false (không thấy người) thì bỏ qua: đó đã là một thông báo
  /// riêng của server, và cộng dồn vào "mất góc" sẽ báo trùng.
  void addFrame({required bool personPresent, required bool angleMeasured}) {
    if (!personPresent) {
      _angleLost.reset();
      return;
    }
    _angleLost.feed(!angleMeasured);
  }

  void reset() {
    _lowLight.reset();
    _angleLost.reset();
  }
}

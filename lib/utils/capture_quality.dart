import 'dart:typed_data';

import 'dart:math' as math;

import '../models/frame_analysis_result.dart' show KeyAngles, Point;

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

  /// Người chiếm quá ít khung hình (đứng xa hoặc người nhỏ): cùng một độ nhiễu điểm
  /// ảnh thì góc khớp dao động mạnh hơn nhiều (mô phỏng 01/10/2026: nhiễu góc gối
  /// 5,2° ở người nhỏ so với 1,6° ở người to), dễ đếm hụt/thừa rep.
  tooSmall,

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

/// Chiều dài thân (trung điểm vai → trung điểm hông) tính theo CHIỀU CAO KHUNG HÌNH,
/// hay `null` nếu không đủ khớp nhìn rõ để đo.
///
/// Đo bằng khoảng cách Euclid có nhân [aspect] (rộng/cao) cho trục x để hai trục cùng
/// thang pixel — chỉ dùng độ chênh y sẽ hỏng khi người nằm ngang (plank) và x, y chuẩn
/// hoá theo hai chiều khác nhau. Dùng thân thay vì cả người vì vai và hông gần như luôn
/// nằm trong khung ở mọi bài (kể cả bài chỉ thấy nửa thân trên), trong khi chân/đầu
/// hay bị cắt. Thân người thật chiếm khoảng 30% chiều cao cơ thể.
///
/// Thiếu một bên thì dùng cặp vai–hông cùng bên còn lại.
double? torsoLengthInFrameHeights(
  Map<String, Point>? points, {
  required double aspect,
  double minVisibility = 0.5,
}) {
  if (points == null || aspect <= 0) return null;

  Point? ok(String name) {
    final p = points[name];
    return (p != null && p.visibility >= minVisibility) ? p : null;
  }

  double dist(Point a, Point b) {
    final dx = (a.x - b.x) * aspect;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  final ls = ok('left_shoulder'), rs = ok('right_shoulder');
  final lh = ok('left_hip'), rh = ok('right_hip');

  if (ls != null && rs != null && lh != null && rh != null) {
    final shoulder = Point(
      x: (ls.x + rs.x) / 2,
      y: (ls.y + rs.y) / 2,
      visibility: 1,
    );
    final hip = Point(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2, visibility: 1);
    return dist(shoulder, hip);
  }
  if (ls != null && lh != null) return dist(ls, lh);
  if (rs != null && rh != null) return dist(rs, rh);
  return null;
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

  /// Thân người (vai → hông) ngắn hơn mức này (tính theo chiều cao khung) thì coi là
  /// quá nhỏ/xa. Thân thật chiếm ~30% chiều cao người, nên 0,14 ≈ người cao chưa tới
  /// ~47% khung; người đứng vừa khung (~65%) có thân ~0,20. Ngưỡng thoát cao hơn để
  /// không nhấp nháy. ƯỚC LƯỢNG — chỉnh theo dữ liệu thật (log phiên có cột `issue`).
  static const tooSmallEnter = 0.14;
  static const tooSmallExit = 0.16;

  /// Đo ~12 lần/giây ⇒ 15 mẫu ≈ 1,2 giây mới cảnh báo: người bước ra xa thoáng qua
  /// giữa động tác không đáng làm phiền.
  final _tooSmall = _Debounced(enterAfter: 15, exitAfter: 6);

  /// ~1,5 giây liên tiếp ở 12 fps mới coi là mất góc: ngắn hơn thì chỉ là một
  /// cú che khuất thoáng qua giữa chuyển động.
  final _angleLost = _Debounced(enterAfter: 18, exitAfter: 3);

  /// Vấn đề đang cần báo, `null` nếu ổn. Tối ưu tiên hơn "mất góc" vì thường
  /// chính là nguyên nhân của nó.
  CaptureIssue? get issue {
    if (_lowLight.active) return CaptureIssue.lowLight;
    // Quá xa thường là NGUYÊN NHÂN của "không đo được khớp", nên báo trước.
    if (_tooSmall.active) return CaptureIssue.tooSmall;
    if (_angleLost.active) return CaptureIssue.angleLost;
    return null;
  }

  /// [torso] từ [torsoLengthInFrameHeights]; `null` (không thấy người hoặc không đo
  /// được) thì xoá đà đếm — không cộng dồn qua lúc vắng người.
  void addBodySize(double? torso) {
    if (torso == null) {
      _tooSmall.reset();
      return;
    }
    _tooSmall.feed(torso < (_tooSmall.active ? tooSmallExit : tooSmallEnter));
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
    _tooSmall.reset();
    _angleLost.reset();
  }
}

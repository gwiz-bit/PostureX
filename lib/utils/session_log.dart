import 'dart:collection';

import '../models/frame_analysis_result.dart' show KeyAngles;

/// Ghi lại diễn biến một phiên phân tích thành văn bản gọn để người thử nghiệm
/// sao chép rồi dán cho lập trình viên — đúng hoàn cảnh test thật ở phòng tập:
/// điện thoại không cắm được máy tính (`adb logcat` không dùng được) và kênh gửi
/// duy nhất là chat văn bản.
///
/// Định dạng CSV, mỗi dòng bắt đầu bằng một chữ cái cho biết loại dòng:
///   `# ...`  siêu dữ liệu (bài tập, chế độ nhận diện, thời gian ML Kit, ...)
///   `R,...`  mẫu định kỳ (mỗi [rowInterval]) — pha, số rep, các góc khớp
///   `E,...`  sự kiện (rep đổi, cảnh báo, lỗi nhắc, đổi camera, ...), luôn ghi
///
/// Bộ nhớ có trần [maxLines]: đầy thì bỏ dòng CŨ NHẤT (giữ đoạn mới, vì người
/// dùng thường bấm sao chép ngay sau khi tập xong set). Số dòng bị bỏ được ghi
/// trong phần đầu để người đọc biết log không còn nguyên vẹn.
class SessionLogRecorder {
  SessionLogRecorder({
    this.rowInterval = const Duration(milliseconds: 250),
    this.maxLines = 3000,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? _defaultClock();

  final Duration rowInterval;
  final int maxLines;
  final int Function() _nowMs;

  final Queue<String> _lines = Queue<String>();
  int _lastRowMs = -1 << 30;
  int _dropped = 0;

  static int Function() _defaultClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMilliseconds;
  }

  /// Tên các cột góc, theo đúng thứ tự trong dòng `R` — cố định để phân tích
  /// bằng bảng tính/script không phải đoán cột nào là cột nào.
  static const angleColumns = [
    'shoulder_l',
    'shoulder_r',
    'elbow_l',
    'elbow_r',
    'hip_l',
    'hip_r',
    'knee_l',
    'knee_r',
    'ankle_l',
    'ankle_r',
    'back',
  ];

  static const columnsHeader =
      'R,t_s,phase,reps,ok,'
      'shoulder_l,shoulder_r,elbow_l,elbow_r,hip_l,hip_r,'
      'knee_l,knee_r,ankle_l,ankle_r,back,'
      'similarity,luma,issue,detect_ms,roundtrip_ms';

  int get lineCount => _lines.length;

  String _t() => (_nowMs() / 1000).toStringAsFixed(2);

  void _push(String line) {
    _lines.add(line);
    while (_lines.length > maxLines) {
      _lines.removeFirst();
      _dropped++;
    }
  }

  /// Ghi một sự kiện — không bị giới hạn tần suất.
  void event(String text) {
    // Xuống dòng sẽ phá cấu trúc một-dòng-một-bản-ghi.
    _push('E,${_t()},${text.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
  }

  /// Ghi một mẫu định kỳ. Trả `true` nếu thực sự ghi, `false` nếu bị bỏ vì chưa
  /// tới [rowInterval] kể từ mẫu trước (frame đến ~12 lần/giây, ghi hết thì log
  /// phình gấp 3 mà không thêm thông tin).
  bool row({
    required String phase,
    required int reps,
    required bool correct,
    KeyAngles? angles,
    double? similarity,
    String? issue,
    double? luma,
    int? detectMs,
    int? roundTripMs,
  }) {
    final now = _nowMs();
    if (now - _lastRowMs < rowInterval.inMilliseconds) return false;
    _lastRowMs = now;

    String a(double? v) => v == null ? '' : v.toStringAsFixed(0);
    final cols = <String>[
      'R',
      _t(),
      phase,
      '$reps',
      correct ? '1' : '0',
      a(angles?.leftShoulder),
      a(angles?.rightShoulder),
      a(angles?.leftElbow),
      a(angles?.rightElbow),
      a(angles?.leftHip),
      a(angles?.rightHip),
      a(angles?.leftKnee),
      a(angles?.rightKnee),
      a(angles?.leftAnkle),
      a(angles?.rightAnkle),
      a(angles?.backAngle),
      similarity == null ? '' : similarity.toStringAsFixed(0),
      luma == null ? '' : luma.toStringAsFixed(0),
      issue ?? '',
      detectMs == null ? '' : '$detectMs',
      roundTripMs == null ? '' : '$roundTripMs',
    ];
    _push(cols.join(','));
    return true;
  }

  /// Toàn bộ log dạng văn bản, sẵn sàng đưa vào clipboard. [header] là các dòng
  /// siêu dữ liệu do bên gọi cung cấp (bài tập, chế độ, thống kê hiệu năng...).
  String toText({Map<String, String> header = const {}}) {
    final out = StringBuffer('# posturex session log\n');
    header.forEach((k, v) => out.writeln('# $k: $v'));
    if (_dropped > 0) {
      out.writeln('# dropped_oldest_lines: $_dropped (log dài hơn $maxLines dòng)');
    }
    out.writeln('# $columnsHeader');
    for (final line in _lines) {
      out.writeln(line);
    }
    return out.toString();
  }

  void clear() {
    _lines.clear();
    _dropped = 0;
    _lastRowMs = -1 << 30;
  }
}

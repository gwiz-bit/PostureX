import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/frame_analysis_result.dart' show Point;

/// Số khớp backend mong đợi trong mỗi frame keypoint — 33 khớp BlazePose,
/// đúng thứ tự `PoseEstimator.LANDMARK_NAMES` phía server
/// (`backend/app/ml/pose_estimator.py`).
const int poseLandmarkCount = 33;

/// Kích thước khung ảnh SAU KHI đã xoay thẳng đứng, suy từ kích thước thô của
/// `CameraImage` và góc xoay cảm biến.
///
/// ML Kit trả toạ độ khớp bằng pixel của ảnh đã xoay (không phải ảnh thô), nên
/// khi cảm biến xoay 90°/270° (chân dung trên hầu hết điện thoại) thì chiều
/// rộng thẳng đứng chính là chiều CAO của ảnh thô. Chia nhầm cho chiều thô sẽ
/// làm khung xương co giãn sai tỉ lệ mà không có lỗi nào báo.
Size uprightImageSize(int rawWidth, int rawHeight, int rotationDegrees) {
  final swapped = rotationDegrees == 90 || rotationDegrees == 270;
  return swapped
      ? Size(rawHeight.toDouble(), rawWidth.toDouble())
      : Size(rawWidth.toDouble(), rawHeight.toDouble());
}

/// Chuyển landmark của ML Kit sang định dạng backend nhận (xem
/// `backend/app/ml/client_keypoints.py`): danh sách 33 phần tử
/// `[x, y, z, visibility]`, x/y chuẩn hoá 0..1 theo [imageSize].
///
/// - z LUÔN gửi bằng 0 — ML Kit không đưa ra được độ sâu dùng được. Tài liệu
///   nói z "cùng thang với x", nhưng đo thực tế (webcam, bài Squat, 21/09/2026)
///   thì chênh z dọc cẳng chân lớn gấp ~2,6 lần chiều dài cẳng chân trong ảnh, và
///   góc gối 3D đọc 110° khi người đứng thẳng (thật ≈175°). Các analyzer như
///   Squat tính góc gối bằng `calculate_angle_3d` nên z hỏng làm góc không bao
///   giờ chạm ngưỡng "đã đứng thẳng" và bỏ sót rep. z = 0 đưa mọi góc về 2D
///   (x, y), cho đúng 175,5° khi đứng thẳng trên cùng dữ liệu đó.
/// - `likelihood` của ML Kit (khớp có nằm trong khung hình không) đóng vai
///   `visibility` của MediaPipe.
///
/// Trả `null` khi không đủ 33 khớp — coi như không thấy người, đúng như phía
/// server xử lý `PoseEstimator.estimate` trả `None`.
List<List<double>>? encodeLandmarks(
  Map<PoseLandmarkType, PoseLandmark> landmarks,
  Size imageSize,
) {
  if (imageSize.width <= 0 || imageSize.height <= 0) return null;

  final out = <List<double>>[];
  for (final type in PoseLandmarkType.values) {
    final landmark = landmarks[type];
    if (landmark == null) return null;
    out.add([
      _round(landmark.x / imageSize.width),
      _round(landmark.y / imageSize.height),
      0.0, // z — xem doc ở trên
      _round(landmark.likelihood.clamp(0.0, 1.0)),
    ]);
  }
  return out;
}

/// Tên 33 khớp theo đúng thứ tự BlazePose — trùng `PoseEstimator.LANDMARK_NAMES`
/// phía server, và là khoá mà `SkeletonPainter` tra khi vẽ.
const _landmarkNames = [
  'nose', 'left_eye_inner', 'left_eye', 'left_eye_outer',
  'right_eye_inner', 'right_eye', 'right_eye_outer',
  'left_ear', 'right_ear', 'mouth_left', 'mouth_right',
  'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow',
  'left_wrist', 'right_wrist', 'left_pinky', 'right_pinky',
  'left_index', 'right_index', 'left_thumb', 'right_thumb',
  'left_hip', 'right_hip', 'left_knee', 'right_knee',
  'left_ankle', 'right_ankle', 'left_heel', 'right_heel',
  'left_foot_index', 'right_foot_index',
];

/// Đầu ngón tay: quá nhỏ và nhiễu để đáng vẽ — server cũng loại chúng khỏi
/// `all_keypoints` (`_FINE_HAND_LANDMARKS` trong `pose_estimator.py`).
const _handLandmarks = {
  'left_pinky', 'right_pinky',
  'left_index', 'right_index',
  'left_thumb', 'right_thumb',
};

/// Dựng khung xương HIỂN THỊ ngay từ kết quả ML Kit trên máy (đầu ra của
/// [encodeLandmarks]), không chờ server trả `all_keypoints` về.
///
/// Vì sao: server phải nhận → làm mượt (EMA) → gửi lại, cộng trần ~12fps, nên
/// khung xương vẽ từ phản hồi của server luôn trễ vài frame so với người đang
/// chuyển động — đúng cảm giác "khung xương không khớp người". Toạ độ ở đây là
/// của chính frame vừa nhận diện, cùng hệ toạ độ với `all_keypoints`.
Map<String, Point> displayPointsFromEncoded(List<List<double>> encoded) {
  assert(encoded.length == _landmarkNames.length);
  return {
    for (var i = 0; i < _landmarkNames.length; i++)
      if (!_handLandmarks.contains(_landmarkNames[i]))
        _landmarkNames[i]: Point(
          x: encoded[i][0],
          y: encoded[i][1],
          visibility: encoded[i][3],
        ),
  };
}

/// Làm mượt nhẹ (EMA) khung xương hiển thị, giữ trạng thái cho MỘT phiên.
///
/// Chỉ dành cho việc VẼ. Phía server vẫn có bộ làm mượt riêng cho việc tính góc
/// (`KeypointSmoother`), nên đây không làm đổi góc/đếm rep. [alpha] cao hơn của
/// server (0,25) vì ML Kit chế độ `stream` đã tự làm mượt và ở đây độ trễ là thứ
/// đang cần tránh — 0,6 là ƯỚC LƯỢNG chưa đo trên người thật.
class KeypointEma {
  KeypointEma({this.alpha = 0.6}) : assert(alpha > 0 && alpha <= 1);

  final double alpha;
  Map<String, Point>? _prev;

  Map<String, Point> smooth(Map<String, Point> next) {
    final prev = _prev;
    if (prev == null) return _prev = next;
    return _prev = {
      for (final entry in next.entries)
        entry.key: prev[entry.key] == null
            ? entry.value
            : Point(
                x: alpha * entry.value.x + (1 - alpha) * prev[entry.key]!.x,
                y: alpha * entry.value.y + (1 - alpha) * prev[entry.key]!.y,
                // Giữ độ tin cậy của frame mới — cùng lý do như phía server.
                visibility: entry.value.visibility,
              ),
    };
  }

  /// Mất người: bỏ trạng thái cũ, để lần thấy lại không bị kéo về vị trí cũ.
  void reset() => _prev = null;
}

/// 5 chữ số thập phân là thừa sức (1 pixel trên ảnh 1000px ≈ 0,001) và giảm
/// gần một nửa dung lượng JSON so với in đủ số double.
double _round(double value) => double.parse(value.toStringAsFixed(5));

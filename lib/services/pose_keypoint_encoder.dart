import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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

/// 5 chữ số thập phân là thừa sức (1 pixel trên ảnh 1000px ≈ 0,001) và giảm
/// gần một nửa dung lượng JSON so với in đủ số double.
double _round(double value) => double.parse(value.toStringAsFixed(5));

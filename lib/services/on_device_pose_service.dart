import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_keypoint_encoder.dart';

/// Frame camera không dùng được cho ML Kit (định dạng/số plane lạ, góc xoay
/// không hợp lệ). Khác lỗi ném ra từ chính ML Kit — cái này là "thiết bị
/// không cấp ảnh đúng dạng", nên thử lại các frame sau cũng vô ích.
class UnsupportedCameraFrameException implements Exception {
  const UnsupportedCameraFrameException(this.message);
  final String message;
  @override
  String toString() => 'UnsupportedCameraFrameException: $message';
}

/// Chạy pose estimation NGAY TRÊN ĐIỆN THOẠI bằng ML Kit, thay cho việc gửi
/// ảnh JPEG lên server chạy MediaPipe.
///
/// Vì sao: đường cũ mỗi frame phải đổi màu YUV→RGB bằng vòng lặp Dart, nén
/// JPEG, đi qua mạng tới VPS 2 vCPU, xếp hàng chờ MediaPipe rồi mới quay về —
/// độ trễ cộng dồn vì chỉ một frame được bay tại một thời điểm. Ở đây ảnh đi
/// thẳng từ camera vào ML Kit (không đổi màu, không nén), và chỉ ~1KB toạ độ
/// khớp mới lên server.
///
/// CHỈ bật cho Android (xem [isSupported]). iOS cần Xcode/thiết bị thật để
/// kiểm chứng định dạng ảnh và góc xoay, và plugin đòi iOS ≥ 15.5 — chưa ai
/// thử nên giữ nguyên đường ảnh JPEG cũ ở đó.
class OnDevicePoseService {
  OnDevicePoseService()
    : _detector = PoseDetector(
        // `base` + `stream` là cặp plugin thiết kế cho luồng video (có theo
        // dõi giữa các frame, nên ổn định hơn từng frame độc lập). Model
        // `accurate` trong plugin này ghi rõ là dành cho ẢNH TĨNH — không
        // dùng cho camera trực tiếp.
        options: PoseDetectorOptions(
          model: PoseDetectionModel.base,
          mode: PoseDetectionMode.stream,
        ),
      );

  /// Chỉ Android: ML Kit không có trên web/desktop, và iOS chưa được kiểm chứng.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// ML Kit trên Android chỉ nhận NV21 (một plane duy nhất). Mặc định của
  /// plugin camera là YUV420 ba plane — không dùng được trực tiếp.
  static const ImageFormatGroup imageFormatGroup = ImageFormatGroup.nv21;

  final PoseDetector _detector;

  /// Nhận diện tư thế trong [image]; `null` nếu không thấy người.
  ///
  /// [sensorOrientation] là góc xoay cần để ảnh thô thành thẳng đứng — với
  /// điện thoại khoá dọc chính là `CameraDescription.sensorOrientation`
  /// (xem `rotationDegreesFor` trong `analyze_session_screen.dart`, cùng một
  /// giá trị mà đường JPEG dùng để xoay ảnh trước khi gửi).
  ///
  /// Ném [UnsupportedCameraFrameException] nếu frame sai dạng; các lỗi khác là
  /// từ ML Kit và được để nguyên cho người gọi quyết định.
  Future<List<List<double>>?> detect(
    CameraImage image,
    int sensorOrientation,
  ) async {
    if (image.format.group != imageFormatGroup || image.planes.length != 1) {
      throw UnsupportedCameraFrameException(
        'Cần NV21 một plane, nhận ${image.format.group} '
        'với ${image.planes.length} plane.',
      );
    }
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) {
      throw UnsupportedCameraFrameException(
        'Góc xoay cảm biến không hợp lệ: $sensorOrientation.',
      );
    }

    final plane = image.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );

    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;

    return encodeLandmarks(
      poses.first.landmarks,
      uprightImageSize(image.width, image.height, sensorOrientation),
    );
  }

  Future<void> close() => _detector.close();
}

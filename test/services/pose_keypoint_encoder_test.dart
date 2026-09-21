import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:posturex/services/pose_keypoint_encoder.dart';

/// Thứ tự 33 khớp mà BACKEND mong đợi (`PoseEstimator.LANDMARK_NAMES`). Nếu
/// một bản nâng cấp plugin ML Kit đổi thứ tự enum, mọi khớp trái/phải và
/// trên/dưới sẽ hoán đổi âm thầm — test này là cái phát hiện ra.
const _backendOrder = [
  'nose', 'leftEyeInner', 'leftEye', 'leftEyeOuter',
  'rightEyeInner', 'rightEye', 'rightEyeOuter',
  'leftEar', 'rightEar', 'leftMouth', 'rightMouth',
  'leftShoulder', 'rightShoulder', 'leftElbow', 'rightElbow',
  'leftWrist', 'rightWrist', 'leftPinky', 'rightPinky',
  'leftIndex', 'rightIndex', 'leftThumb', 'rightThumb',
  'leftHip', 'rightHip', 'leftKnee', 'rightKnee',
  'leftAnkle', 'rightAnkle', 'leftHeel', 'rightHeel',
  'leftFootIndex', 'rightFootIndex',
];

Map<PoseLandmarkType, PoseLandmark> _allLandmarks({
  double x = 100,
  double y = 200,
  double z = -50,
  double likelihood = 0.9,
}) => {
  for (final type in PoseLandmarkType.values)
    type: PoseLandmark(type: type, x: x, y: y, z: z, likelihood: likelihood),
};

void main() {
  test('thứ tự enum ML Kit khớp đúng thứ tự khớp của backend', () {
    expect(PoseLandmarkType.values.map((t) => t.name).toList(), _backendOrder);
    expect(PoseLandmarkType.values.length, poseLandmarkCount);
  });

  group('uprightImageSize', () {
    test('cảm biến xoay 90/270° thì hoán đổi rộng-cao (chân dung)', () {
      expect(uprightImageSize(640, 480, 90), const Size(480, 640));
      expect(uprightImageSize(640, 480, 270), const Size(480, 640));
    });

    test('xoay 0/180° giữ nguyên', () {
      expect(uprightImageSize(640, 480, 0), const Size(640, 480));
      expect(uprightImageSize(640, 480, 180), const Size(640, 480));
    });
  });

  group('encodeLandmarks', () {
    test('chuẩn hoá x, y theo kích thước ảnh', () {
      final out = encodeLandmarks(
        _allLandmarks(x: 240, y: 320, z: -48),
        const Size(480, 640),
      )!;

      expect(out, hasLength(poseLandmarkCount));
      expect(out.first.sublist(0, 2), [0.5, 0.5]);
      expect(out.first[3], 0.9);
    });

    test('z luôn bằng 0 — z của ML Kit làm sai góc 3D (xem doc encodeLandmarks)',
        () {
      // Cả giá trị nhỏ lẫn rất lớn đều phải ra 0, không được lọt z thô qua.
      for (final z in [-300.0, -48.0, 0.0, 12.0, 500.0]) {
        final out = encodeLandmarks(
          _allLandmarks(z: z),
          const Size(480, 640),
        )!;
        expect(out.every((point) => point[2] == 0.0), isTrue, reason: 'z=$z');
        // Không được là -0.0 (jsonEncode ra "-0.0", vô nghĩa và dễ gây nhầm).
        expect(out.every((point) => !point[2].isNegative), isTrue);
      }
    });

    test('giữ đúng thứ tự khớp trong đầu ra', () {
      final landmarks = {
        for (final type in PoseLandmarkType.values)
          type: PoseLandmark(
            type: type,
            x: type.index.toDouble(),
            y: 0,
            z: 0,
            likelihood: 1,
          ),
      };
      final out = encodeLandmarks(landmarks, const Size(100, 100))!;

      for (var i = 0; i < poseLandmarkCount; i++) {
        expect(out[i][0], closeTo(i / 100, 1e-9), reason: _backendOrder[i]);
      }
    });

    test('kẹp likelihood vào 0..1', () {
      final low = encodeLandmarks(
        _allLandmarks(likelihood: -0.2),
        const Size(100, 100),
      )!;
      final high = encodeLandmarks(
        _allLandmarks(likelihood: 1.4),
        const Size(100, 100),
      )!;
      expect(low.first[3], 0.0);
      expect(high.first[3], 1.0);
    });

    test('làm tròn còn 5 chữ số thập phân', () {
      final out = encodeLandmarks(
        _allLandmarks(x: 1, y: 1, z: 0),
        const Size(3, 3),
      )!;
      expect(out.first[0], 0.33333);
    });

    test('thiếu khớp nào thì coi như không thấy người', () {
      final partial = _allLandmarks()..remove(PoseLandmarkType.leftKnee);
      expect(encodeLandmarks(partial, const Size(100, 100)), isNull);
      expect(encodeLandmarks({}, const Size(100, 100)), isNull);
    });

    test('kích thước ảnh không hợp lệ thì trả null, không chia cho 0', () {
      expect(encodeLandmarks(_allLandmarks(), Size.zero), isNull);
    });
  });
}

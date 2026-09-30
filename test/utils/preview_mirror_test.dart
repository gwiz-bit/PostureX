import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/utils/preview_mirror.dart';

/// Mô hình đại số của bài toán: số lần mỗi thứ bị lật gương (mod 2).
///  - texture preview: P (plugin) + T (app bọc Transform)
///  - khung xương:     S (tự lật x) + T
/// Khớp hình ⇔ hai số bằng nhau; hiển thị đúng kiểu gương ⇔ texture bị lật lẻ lần.
bool _previewShownAsMirror(bool pluginMirrors, PreviewMirrorPlan plan) =>
    ((pluginMirrors ? 1 : 0) + (plan.flipWholeStack ? 1 : 0)).isOdd;

bool _skeletonAlignedWithPreview(bool pluginMirrors, PreviewMirrorPlan plan) =>
    ((plan.mirrorSkeleton ? 1 : 0) + (plan.flipWholeStack ? 1 : 0)) % 2 ==
    ((pluginMirrors ? 1 : 0) + (plan.flipWholeStack ? 1 : 0)) % 2;

void main() {
  group('PreviewMirrorPlan — camera trước', () {
    test('plugin ĐÃ lật preview: không bọc Transform, chỉ lật khung xương', () {
      final plan = PreviewMirrorPlan.forCamera(
        isFront: true,
        pluginMirrorsFrontPreview: true,
      );
      expect(plan.flipWholeStack, isFalse);
      expect(plan.mirrorSkeleton, isTrue);
    });

    test('plugin CHƯA lật preview: bọc Transform, không lật riêng khung xương', () {
      final plan = PreviewMirrorPlan.forCamera(
        isFront: true,
        pluginMirrorsFrontPreview: false,
      );
      expect(plan.flipWholeStack, isTrue);
      expect(plan.mirrorSkeleton, isFalse);
    });

    for (final pluginMirrors in [true, false]) {
      test(
        'plugin lật=$pluginMirrors: preview hiện như gương VÀ khung xương khớp hình',
        () {
          final plan = PreviewMirrorPlan.forCamera(
            isFront: true,
            pluginMirrorsFrontPreview: pluginMirrors,
          );
          expect(_previewShownAsMirror(pluginMirrors, plan), isTrue);
          expect(_skeletonAlignedWithPreview(pluginMirrors, plan), isTrue);
        },
      );
    }
  });

  test('camera sau không bao giờ lật gì, bất kể hiệu chỉnh', () {
    for (final pluginMirrors in [true, false]) {
      final plan = PreviewMirrorPlan.forCamera(
        isFront: false,
        pluginMirrorsFrontPreview: pluginMirrors,
      );
      expect(plan.flipWholeStack, isFalse);
      expect(plan.mirrorSkeleton, isFalse);
    }
  });

  test('đảo bit hiệu chỉnh đảo cả hai quyết định (nút sửa có tác dụng)', () {
    final a = PreviewMirrorPlan.forCamera(
      isFront: true,
      pluginMirrorsFrontPreview: true,
    );
    final b = PreviewMirrorPlan.forCamera(
      isFront: true,
      pluginMirrorsFrontPreview: false,
    );
    expect(a.flipWholeStack, isNot(b.flipWholeStack));
    expect(a.mirrorSkeleton, isNot(b.mirrorSkeleton));
  });
}

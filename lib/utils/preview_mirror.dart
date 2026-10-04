/// Cách bố trí lật gương cho preview camera + khung xương, suy ra từ MỘT điều
/// chưa biết duy nhất: plugin camera có TỰ lật gương preview camera trước hay
/// không ([pluginMirrorsFrontPreview]).
///
/// Vì sao cần: ảnh đưa cho ML Kit (và toạ độ khớp nhận về) luôn ở không gian
/// GỐC, chưa lật. Còn texture của `CameraPreview` thì tuỳ phiên bản plugin/thiết
/// bị mà có thể đã bị lật (đúng kiểu gương selfie) hoặc không
/// (flutter/flutter#156974). Hai cách sửa trước đây đều hỏng trên một loại máy:
///  - 11/09/2026: luôn lật preview bằng `Transform` + luôn lật khung xương bằng
///    cờ riêng → sai trên máy plugin đã tự lật (lật hai lần).
///  - 14/09/2026: bọc preview + khung xương chung một `Transform` (giả định "hai
///    thứ luôn cùng chiều nên lật cùng nhau là khớp") → SAI khi plugin chỉ lật
///    texture mà không lật toạ độ khớp: khung xương thành ảnh gương của người thật
///    (xác nhận bằng ảnh chụp thật 30/09/2026: thân người ở x≈160/429, cột sống
///    khung xương ở x≈270 ≈ 429−160).
///
/// Mục tiêu cuối: camera trước hiển thị như GƯƠNG (người dùng giơ tay phải thì tay
/// hiện bên phải màn hình), và khung xương khớp đúng với hình. Gọi P = plugin đã
/// lật texture (0/1), T = app tự bọc `Transform` lật cả preview lẫn khung xương
/// (0/1), S = khung xương tự lật x (0/1):
///  - preview hiển thị lật gương ⇔ P + T lẻ  → T = 1 − P
///  - khung xương khớp hình      ⇔ S + T ≡ P + T (mod 2) → S = P
/// Camera sau không bao giờ lật gương: không làm gì cả.
class PreviewMirrorPlan {
  const PreviewMirrorPlan({
    required this.flipWholeStack,
    required this.mirrorSkeleton,
  });

  /// App tự bọc `Transform(rotationY(pi))` quanh cả preview lẫn khung xương.
  final bool flipWholeStack;

  /// `SkeletonPainter` tự lật toạ độ x (`1 - x`) — chỉ để khớp với texture mà
  /// plugin đã lật.
  final bool mirrorSkeleton;

  factory PreviewMirrorPlan.forCamera({
    required bool isFront,
    required bool pluginMirrorsFrontPreview,
  }) {
    if (!isFront) {
      return const PreviewMirrorPlan(
        flipWholeStack: false,
        mirrorSkeleton: false,
      );
    }
    return PreviewMirrorPlan(
      flipWholeStack: !pluginMirrorsFrontPreview,
      mirrorSkeleton: pluginMirrorsFrontPreview,
    );
  }

  @override
  String toString() =>
      'flipWholeStack=$flipWholeStack, mirrorSkeleton=$mirrorSkeleton';
}

/// Ánh xạ tên bài tập → video hướng dẫn đóng gói sẵn trong app
/// (`assets/video/`, khai trong `pubspec.yaml`).
///
/// Đây là nguồn **dự phòng**, chỉ dùng khi bài tập không có `DemoVideoUrl`
/// trong DB. Đường chính là video tải từ server: 412 trong 417 bài của thư
/// viện đều có video riêng.
///
/// LỊCH SỬ: TRẢ VỀ NULL, KHÔNG PHẢI SQUAT
/// ---------------------------------------
/// Bản trước có một hằng số `_defaultGuideVideo = 'assets/video/squat.mp4'`
/// làm giá trị mặc định. Vì bảng dưới đây chỉ có đúng một mục, hàm này trả
/// video squat cho **mọi** bài tập — nên bất kỳ bài nào chưa có `DemoVideoUrl`
/// đều phát nhầm động tác squat. Lỗi lộ ra khi thử app với DB local (6 bài
/// seed, không bài nào có video): mở "Bicep Curl" cũng ra squat.
///
/// Chú thích cũ biện minh rằng fallback đó "nhất quán chứ không đánh lừa", vì
/// backend cũng fallback sang `SquatAnalyzer` cho bài lạ. Lập luận đó **không
/// còn đúng**: nay đã có cờ `supports_analysis`, và tab Exercises hiện huy
/// hiệu LIVE ANALYSIS đúng những bài phân tích được. Bài không có huy hiệu đó
/// chẳng nhận phản hồi squat nào cả — chiếu video squat cho chúng chỉ đơn giản
/// là sai, và tệ hơn im lặng: người dùng tưởng đó là động tác đúng của bài
/// mình đang xem.
///
/// Thà không hiện video nào còn hơn hiện video của bài khác. Vì vậy hàm trả
/// `null` cho bài chưa có video, và phía giao diện hiện thông báo thay cho
/// khung video.
///
/// Thêm mục mới vào bảng khi có video đóng gói **đã kiểm chứng** cho bài đó —
/// đúng động tác, không phải chỉ đúng tên file.
const Map<String, String> _guideVideoByExercise = {
  'squat': 'assets/video/squat.mp4',
};

/// Video đóng gói cho [exercise], hoặc `null` nếu không có.
///
/// `null` nghĩa là "app không có video cho bài này" — người gọi phải xử lý
/// đàng hoàng (hiện thông báo), tuyệt đối không thay bằng video của bài khác.
String? guideVideoAssetFor(String exercise) =>
    _guideVideoByExercise[exercise.toLowerCase()];

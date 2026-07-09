# PostureX — Flutter prototype

Bản mẫu Flutter cho ứng dụng PostureX, dựng lại đúng các màn hình đã thiết kế trong bản demo tương tác: trang chủ, bài tập, camera, tiến trình, hồ sơ.

## Cấu trúc

```
lib/
  main.dart                  điểm khởi chạy app
  theme/app_theme.dart       bảng màu và ThemeData dùng chung
  data/exercises_data.dart   dữ liệu mẫu: nhóm cơ và bài tập
  widgets/
    activity_rings.dart      vòng tròn tiến trình (activity rings)
    skeleton_painter.dart    vẽ khung xương overlay cho camera
    bottom_nav_scaffold.dart Scaffold gốc quản lý 5 tab
  screens/
    home_screen.dart         trang chủ
    workout_screen.dart      bài tập: tìm kiếm, lọc độ khó, nhóm thu gọn
    camera_screen.dart       video mẫu (trên) + camera theo dõi (dưới)
    progress_screen.dart     biểu đồ tuần và lịch sử
    profile_screen.dart      hồ sơ và cài đặt
```

## Chạy thử

Cần cài Flutter SDK (flutter.dev/docs/get-started/install).

```bash
cd posturex_flutter
flutter pub get
flutter run
```

## Trạng thái hiện tại

Đây là bản mẫu giao diện (UI prototype), chưa nối:
- Camera thật (package `camera`) và mô hình nhận diện tư thế (ví dụ ML Kit Pose Detection hoặc MediaPipe)
- Backend lưu lịch sử tập luyện, tài khoản người dùng
- Video mẫu thật (hiện đang là hình minh họa khung xương tĩnh)

Rep counter ở màn hình camera hiện tăng tự động theo thời gian để mô phỏng, không dựa trên phân tích chuyển động thật.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:posturex/utils/exercise_videos.dart';
import 'package:posturex/widgets/guide_video_player.dart';

/// Khoá lại bản sửa lỗi "mọi bài tập đều phát video hướng dẫn của Squat".
///
/// Nguyên nhân cũ: `exercise_videos.dart` có hằng số
/// `_defaultGuideVideo = 'assets/video/squat.mp4'` làm giá trị mặc định, mà
/// bảng ánh xạ chỉ có đúng một mục — nên hàm trả video squat cho MỌI bài. Bất
/// kỳ bài nào chưa có `DemoVideoUrl` đều phát nhầm động tác squat, và người
/// dùng tưởng đó là động tác đúng của bài mình đang xem.
///
/// Test ở đây chốt hai điều: hàm trả `null` chứ không phải squat, và giao diện
/// hiện thông báo chứ không dựng trình phát rỗng.

void main() {
  group('guideVideoAssetFor', () {
    test('squat có video đóng gói sẵn', () {
      expect(guideVideoAssetFor('squat'), 'assets/video/squat.mp4');
    });

    test('không phân biệt hoa thường', () {
      expect(guideVideoAssetFor('SQUAT'), 'assets/video/squat.mp4');
      expect(guideVideoAssetFor('Squat'), 'assets/video/squat.mp4');
    });

    test('bài khác trả null, KHÔNG trả video squat', () {
      // Đây chính là lỗi cũ. Trước bản sửa, mọi dòng dưới đây đều trả
      // 'assets/video/squat.mp4'.
      for (final ten in [
        'Bicep Curl',
        'Jumping Jack',
        'Plank',
        'Lunge',
        'Barbell Bent Over Row',
      ]) {
        expect(
          guideVideoAssetFor(ten),
          isNull,
          reason: '$ten không được rơi về video squat',
        );
      }
    });

    test('tên rỗng hoặc lạ cũng trả null', () {
      expect(guideVideoAssetFor(''), isNull);
      expect(guideVideoAssetFor('   '), isNull);
      expect(guideVideoAssetFor('Bài Không Có Thật'), isNull);
    });
  });

  group('GuideVideoPlayer.hasVideo', () {
    test('có nguồn nào cũng tính là có', () {
      expect(
        const GuideVideoPlayer(networkUrl: 'http://x/a.mp4').hasVideo,
        isTrue,
      );
      expect(
        const GuideVideoPlayer(assetPath: 'assets/video/squat.mp4').hasVideo,
        isTrue,
      );
    });

    test('không nguồn nào thì false', () {
      expect(const GuideVideoPlayer().hasVideo, isFalse);
    });
  });

  group('GuideVideoPlayer khi không có video', () {
    // Chỉ kiểm nhánh KHÔNG có video: hai nhánh kia dựng
    // `VideoPlayerController` thật, vốn cần platform channel mà `flutter test`
    // không có — chúng phải kiểm trên máy thật.

    Widget boc(Widget child) => MaterialApp(
          home: Scaffold(body: SizedBox(height: 220, child: child)),
        );

    testWidgets('hiện thông báo thay vì khung video', (tester) async {
      await tester.pumpWidget(boc(const GuideVideoPlayer()));

      expect(find.text('Bài này chưa có video hướng dẫn.'), findsOneWidget);
    });

    testWidgets('KHÔNG dựng trình phát nào', (tester) async {
      // Điểm mấu chốt của cả bản sửa. Trước đây người gọi luôn truyền video
      // squat làm mặc định nên luôn có một VideoPlayer — phát nhầm động tác.
      await tester.pumpWidget(boc(const GuideVideoPlayer()));

      expect(find.byType(VideoPlayer), findsNothing);
    });

    testWidgets('không hiện nút phát / toàn màn hình', (tester) async {
      // Nút điều khiển cho một trình phát không tồn tại chỉ khiến người dùng
      // bấm vào rồi thấy không có gì xảy ra.
      await tester.pumpWidget(boc(const GuideVideoPlayer()));

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    });

    testWidgets('không kẹt ở vòng xoay chờ', (tester) async {
      // Nếu vẫn dựng controller rồi chờ initialize() không bao giờ xong thì
      // người dùng nhìn vòng xoay vĩnh viễn — tệ hơn cả một thông báo rõ ràng.
      await tester.pumpWidget(boc(const GuideVideoPlayer()));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

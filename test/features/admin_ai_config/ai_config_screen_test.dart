import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:posturex/features/admin_ai_config/presentation/screens/ai_config_screen.dart';
import 'package:posturex/services/api_client.dart';
import 'package:posturex/theme/app_theme.dart';

/// Widget test cho màn admin chỉnh ngưỡng tư thế.
///
/// Các test entity ở `posture_rules_test.dart` chứng minh phần tính toán đúng.
/// File này kiểm thứ còn lại: hai màn hình có THẬT SỰ VẼ RA ĐƯỢC không, và có
/// hiển thị đúng thứ backend gửi xuống không — đặc biệt là đơn vị, vì ghi cứng
/// "°" cho một tỉ lệ sẽ hiện "0.05°" và khiến admin hiểu sai.

Map<String, dynamic> _tunable(
  String key,
  String label,
  double def, {
  double? current,
  double min = 40,
  double max = 180,
  bool repCount = false,
  String unit = '°',
  double step = 1.0,
}) =>
    {
      'key': key,
      'label': label,
      'default': def,
      'current': current,
      'minimum': min,
      'maximum': max,
      'affects_rep_count': repCount,
      'unit': unit,
      'step': step,
    };

/// Backend giả: một bài đã chỉnh riêng, một bài còn mặc định.
http.Client _fakeBackend({List<Map<String, dynamic>>? tunables}) {
  return MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/admin/posture-rules')) {
      final search = request.url.queryParameters['search'];
      final all = [
        {'id': 1, 'name': 'Squat', 'analyzer': 'SquatAnalyzer', 'override_count': 2},
        {'id': 4, 'name': 'Plank', 'analyzer': 'PlankAnalyzer', 'override_count': 0},
      ];
      final rows = search == null || search.isEmpty
          ? all
          : all.where((e) => (e['name']! as String).toLowerCase().contains(search.toLowerCase()));
      return http.Response(jsonEncode(rows.toList()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }

    if (path.contains('/admin/posture-rules/')) {
      return http.Response(
        jsonEncode({
          'exercise_id': 1,
          'exercise_name': 'Squat',
          'analyzer': 'SquatAnalyzer',
          'tunables': tunables ??
              [
                _tunable('knee_depth', 'Độ sâu gối', 95, current: 88, repCount: true),
                _tunable('back_straight_min', 'Lưng thẳng', 150),
              ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return http.Response('{"detail":"khong mong doi: $path"}', 404,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Widget _app() => MaterialApp(theme: AppTheme.dark, home: const AIConfigScreen());

void main() {
  setUp(() {
    ApiClient.instance = ApiClient(httpClient: _fakeBackend());
  });

  group('màn chọn bài tập', () {
    testWidgets('liệt kê bài kèm analyzer và số ngưỡng riêng', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('SquatAnalyzer'), findsOneWidget);
      expect(find.text('2 ngưỡng riêng'), findsOneWidget);

      // Bài chưa đụng vào phải phân biệt được ngay từ danh sách.
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
    });

    testWidgets('tóm tắt đúng số bài đã chỉnh riêng', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // `SectionLabel` tự `.toUpperCase()` nội dung, nên phải khớp bản in hoa
      // chứ không phải chuỗi truyền vào.
      expect(
        find.text('2 BÀI PHÂN TÍCH ĐƯỢC · 1 BÀI ĐÃ CHỈNH RIÊNG'),
        findsOneWidget,
      );
    });

    testWidgets('mở được màn chỉnh ngưỡng của một bài', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      expect(find.text('Độ sâu gối'), findsOneWidget);
      expect(find.text('Lưng thẳng'), findsOneWidget);
    });
  });

  group('màn chỉnh ngưỡng', () {
    Future<void> moManChinh(WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();
    }

    testWidgets('phân biệt ngưỡng đã chỉnh với ngưỡng mặc định', (tester) async {
      await moManChinh(tester);

      // `knee_depth` đang ghi đè 88 (mặc định 95) — phải nói rõ cả hai số,
      // nếu không admin không biết mình đã lệch khỏi mặc định bao nhiêu.
      expect(find.text('Đã chỉnh · mặc định 95°'), findsOneWidget);
      expect(find.text('88°'), findsOneWidget);

      // `back_straight_min` chưa đụng vào.
      expect(find.text('150°'), findsOneWidget);
    });

    testWidgets('đánh dấu ngưỡng ảnh hưởng bộ đếm rep', (tester) async {
      await moManChinh(tester);

      expect(find.text('Ảnh hưởng đếm rep'), findsOneWidget);
    });

    testWidgets('chỉ ngưỡng đang ghi đè mới có nút Về mặc định', (tester) async {
      await moManChinh(tester);

      // Hai ngưỡng trên màn hình, chỉ một cái đang ghi đè.
      expect(find.text('Về mặc định'), findsOneWidget);
    });

    testWidgets('bấm Về mặc định thì giá trị quay lại mặc định', (tester) async {
      await moManChinh(tester);

      await tester.tap(find.text('Về mặc định'));
      await tester.pumpAndSettle();

      expect(find.text('88°'), findsNothing);
      expect(find.text('Về mặc định'), findsNothing);
      expect(find.text('95°'), findsOneWidget);
    });

    testWidgets('ngưỡng tỉ lệ KHÔNG bị gắn đơn vị độ', (tester) async {
      // Đây là lý do `unit` phải đến từ backend. Ghi cứng "°" trong giao diện
      // sẽ hiện "0.05°" — admin đọc xong tưởng mình đang chỉnh một góc.
      ApiClient.instance = ApiClient(
        httpClient: _fakeBackend(tunables: [
          _tunable('knee_overshoot', 'Gối vượt mũi chân', 0.05,
              min: 0, max: 0.30, unit: '', step: 0.01),
        ]),
      );

      await moManChinh(tester);

      expect(find.text('0.05'), findsOneWidget);
      expect(find.text('0.05°'), findsNothing);
      // Hai đầu thanh trượt cũng phải theo đơn vị đó.
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('0.30'), findsOneWidget);
    });

    testWidgets('giải thích cơ chế mặc định/ghi đè cho admin', (tester) async {
      await moManChinh(tester);

      expect(
        find.textContaining('chỉ áp cho riêng bài này'),
        findsOneWidget,
      );
    });
  });

  group('lỗi mạng', () {
    testWidgets('hiện thông báo và nút thử lại thay vì màn trắng', (tester) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((_) async => http.Response('{"detail":"Server sap"}', 500,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Server sap'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}

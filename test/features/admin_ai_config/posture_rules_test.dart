import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/features/admin_ai_config/domain/entities/posture_rules.dart';

/// Unit test thuần cho entity ngưỡng tư thế — không mạng, không pump widget.
///
/// Phần đáng test nhất là cách phân biệt "chưa đụng vào" với "đã đặt bằng đúng
/// giá trị mặc định". Gộp hai trạng thái đó lại thì nút "Về mặc định" mất tác
/// dụng: `overrides` vẫn gửi con số lên, backend vẫn ghi một dòng, và bài tập
/// không bao giờ quay lại chạy bằng mặc định của analyzer được nữa.

Tunable _tunable({
  String key = 'knee_depth',
  double defaultValue = 95.0,
  double? current,
  bool affectsRepCount = true,
  double minimum = 40,
  double maximum = 140,
  String unit = '°',
  double step = 1.0,
}) =>
    Tunable(
      key: key,
      label: 'Độ sâu gối',
      defaultValue: defaultValue,
      current: current,
      minimum: minimum,
      maximum: maximum,
      affectsRepCount: affectsRepCount,
      unit: unit,
      step: step,
    );

ExerciseRules _rules(List<Tunable> tunables) => ExerciseRules(
      exerciseId: 1,
      exerciseName: 'Squat',
      analyzer: 'SquatAnalyzer',
      tunables: tunables,
    );

void main() {
  group('Tunable', () {
    test('chưa ghi đè thì giá trị hiệu lực là mặc định', () {
      final t = _tunable(current: null);

      expect(t.effective, 95.0);
      expect(t.isOverridden, isFalse);
    });

    test('đã ghi đè thì giá trị hiệu lực là giá trị ghi đè', () {
      final t = _tunable(current: 88.0);

      expect(t.effective, 88.0);
      expect(t.isOverridden, isTrue);
    });

    test('đặt đúng bằng mặc định vẫn tính là đã ghi đè', () {
      // Nếu coi hai trạng thái này là một thì không có cách nào biểu diễn
      // "admin cố ý ghim con số này lại" — và quan trọng hơn, không phân biệt
      // được với "chưa ai đụng tới".
      final t = _tunable(current: 95.0);

      expect(t.isOverridden, isTrue);
    });

    test('clearCurrent gỡ ghi đè, không phải gán 0', () {
      final t = _tunable(current: 88.0).copyWith(clearCurrent: true);

      expect(t.current, isNull);
      expect(t.effective, 95.0);
    });

    test('copyWith không có tham số thì giữ nguyên ghi đè', () {
      // Bẫy của kiểu `current ?? this.current`: gọi `copyWith()` rỗng phải
      // giữ nguyên chứ không được âm thầm xoá.
      final t = _tunable(current: 88.0).copyWith();

      expect(t.current, 88.0);
    });
  });

  group('đơn vị và bước nhảy', () {
    test('ngưỡng góc hiện kèm "°", không có phần thập phân', () {
      final t = _tunable(current: 88.0);

      expect(t.format(t.effective), '88°');
    });

    test('ngưỡng tỉ lệ KHÔNG được gắn "°"', () {
      // `knee_overshoot` là tỉ lệ theo chiều rộng khung hình. Hiện "0.05°"
      // khiến admin hiểu sai hoàn toàn thứ mình đang chỉnh — đây là lý do
      // đơn vị phải đến từ backend chứ không ghi cứng trong giao diện.
      final t = _tunable(
        key: 'knee_overshoot',
        defaultValue: 0.05,
        minimum: 0,
        maximum: 0.30,
        unit: '',
        step: 0.01,
      );

      expect(t.format(t.effective), '0.05');
    });

    test('số nấc thanh trượt tính theo bước, không theo khoảng', () {
      // Bẫy: `(max - min).round()` cho khoảng 0–0.3 ra 0 nấc — thanh trượt
      // chỉ nhảy được giữa hai đầu, admin không chọn được giá trị nào ở giữa.
      final goc = _tunable(minimum: 40, maximum: 140, step: 1);
      final tiLe = _tunable(minimum: 0, maximum: 0.30, step: 0.01);

      expect(goc.divisions, 100);
      expect(tiLe.divisions, 30);
    });
  });

  group('ExerciseRules.overrides', () {
    test('chỉ gửi lên ngưỡng đang ghi đè', () {
      final rules = _rules([
        _tunable(key: 'knee_depth', current: 88.0),
        _tunable(key: 'stand_up_min', defaultValue: 155.0, current: null),
      ]);

      expect(rules.overrides, {'knee_depth': 88.0});
    });

    test('không ghi đè gì thì gửi map rỗng', () {
      // Backend hiểu map rỗng là "xoá hết ghi đè, quay về mặc định" — nên đây
      // vừa là trạng thái ban đầu vừa là cách hoàn tác.
      final rules = _rules([_tunable(current: null)]);

      expect(rules.overrides, isEmpty);
    });

    test('gỡ một ngưỡng thì nó biến mất khỏi phần gửi lên', () {
      final rules = _rules([
        _tunable(key: 'knee_depth', current: 88.0),
        _tunable(key: 'back_straight_min', defaultValue: 150.0, current: 145.0),
      ]);

      final sau = rules.withTunable(
        rules.tunables.first.copyWith(clearCurrent: true),
      );

      expect(sau.overrides, {'back_straight_min': 145.0});
    });
  });

  group('ExerciseRules.withTunable', () {
    test('chỉ thay đúng ngưỡng có cùng khoá', () {
      final rules = _rules([
        _tunable(key: 'knee_depth', current: null),
        _tunable(key: 'stand_up_min', defaultValue: 155.0, current: null),
      ]);

      final sau = rules.withTunable(rules.tunables[1].copyWith(current: 150.0));

      expect(sau.tunables[0].current, isNull);
      expect(sau.tunables[1].current, 150.0);
    });

    test('giữ nguyên thứ tự — thứ tự quyết định bố cục màn hình', () {
      final rules = _rules([
        _tunable(key: 'knee_depth'),
        _tunable(key: 'stand_up_min'),
        _tunable(key: 'back_straight_min'),
      ]);

      final sau = rules.withTunable(rules.tunables[1].copyWith(current: 150.0));

      expect(sau.tunables.map((t) => t.key).toList(),
          ['knee_depth', 'stand_up_min', 'back_straight_min']);
    });
  });

  group('parse JSON', () {
    test('current null nghĩa là đang chạy bằng mặc định', () {
      final t = Tunable.fromJson(const {
        'key': 'knee_depth',
        'label': 'Độ sâu gối',
        'default': 95.0,
        'current': null,
        'minimum': 40.0,
        'maximum': 140.0,
        'affects_rep_count': true,
        'unit': '°',
        'step': 1.0,
      });

      expect(t.current, isNull);
      expect(t.effective, 95.0);
    });

    test('số nguyên từ JSON vẫn đọc được thành double', () {
      // Backend trả Decimal; JSON có thể ra `95` chứ không phải `95.0`, và
      // `as double` trên một int là lỗi lúc chạy.
      final t = Tunable.fromJson(const {
        'key': 'knee_depth',
        'label': 'Độ sâu gối',
        'default': 95,
        'current': 88,
        'minimum': 40,
        'maximum': 140,
        'affects_rep_count': false,
        'unit': '°',
        'step': 1.0,
      });

      expect(t.defaultValue, 95.0);
      expect(t.current, 88.0);
    });

    test('ExerciseRules đọc đủ danh sách ngưỡng', () {
      final rules = ExerciseRules.fromJson(const {
        'exercise_id': 3,
        'exercise_name': 'Plank',
        'analyzer': 'PlankAnalyzer',
        'tunables': [
          {
            'key': 'hip_sag',
            'label': 'Võng hông',
            'default': 150.0,
            'current': null,
            'minimum': 100.0,
            'maximum': 180.0,
            'affects_rep_count': false,
            'unit': '°',
            'step': 1.0,
          },
        ],
      });

      expect(rules.analyzer, 'PlankAnalyzer');
      expect(rules.tunables.single.key, 'hip_sag');
    });

    test('TunableExercise đọc được số ngưỡng đã ghi đè', () {
      final e = TunableExercise.fromJson(const {
        'id': 1,
        'name': 'Barbell Squat',
        'analyzer': 'SquatAnalyzer',
        'override_count': 2,
      });

      expect(e.name, 'Barbell Squat');
      expect(e.overrideCount, 2);
    });
  });
}

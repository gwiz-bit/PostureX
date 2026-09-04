/// Ngưỡng phân tích tư thế theo từng bài tập — thay cho entity `AIConfig` cũ.
///
/// Bản cũ là một đối tượng phẳng gồm 7 trường ghi cứng cho riêng squat, khớp
/// 1-1 với một biến nằm trong RAM của server. Nó sai theo ba hướng: chỉnh xong
/// restart là mất, chỉnh một bài thì cả 21 biến thể squat đổi theo, và 4 trong
/// 7 trường không có đường nào tới analyzer.
///
/// Bản này khớp với bảng `ExercisePostureRules` — đúng bảng mà backend đọc khi
/// mở phiên phân tích — nên mọi bài có analyzer đều chỉnh được, riêng từng bài,
/// và lưu bền.
library;

/// Một bài tập trong danh sách chọn.
class TunableExercise {
  const TunableExercise({
    required this.id,
    required this.name,
    required this.analyzer,
    required this.overrideCount,
  });

  final int id;
  final String name;

  /// Tên class analyzer phụ trách. Hai bài cùng analyzer chỉnh được cùng bộ
  /// ngưỡng, nhưng giá trị thì riêng từng bài.
  final String analyzer;

  /// Số ngưỡng đang ghi đè. 0 nghĩa là bài này chạy hoàn toàn bằng mặc định.
  final int overrideCount;

  factory TunableExercise.fromJson(Map<String, dynamic> json) => TunableExercise(
        id: json['id'] as int,
        name: json['name'] as String,
        analyzer: json['analyzer'] as String,
        overrideCount: json['override_count'] as int,
      );
}

/// Một ngưỡng chỉnh được, kèm đủ thông tin để dựng ô nhập.
///
/// Giao diện KHÔNG ghi cứng nhãn hay khoảng giá trị nào — tất cả đến từ
/// backend. Nhờ vậy thêm một ngưỡng mới cho analyzer chỉ phải khai ở
/// `backend/app/ml/analyzers/tunables.py`, không phải sửa song song hai bên
/// rồi quên mất một bên.
class Tunable {
  const Tunable({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.affectsRepCount,
    required this.unit,
    required this.step,
  });

  final String key;
  final String label;

  /// Giá trị analyzer dùng khi bài này chưa được ghi đè.
  final double defaultValue;

  /// Giá trị đang ghi đè; `null` = đang chạy bằng [defaultValue].
  ///
  /// Phân biệt `null` với "bằng đúng mặc định" là điều kiện để nút gỡ ghi đè
  /// có nghĩa — nếu gộp hai trạng thái đó thì không cách nào quay về mặc định.
  final double? current;

  final double minimum;
  final double maximum;

  /// Đổi ngưỡng này là đổi cách ĐẾM rep, không chỉ cách chấm điểm.
  final bool affectsRepCount;

  /// Đơn vị hiển thị — `'°'` cho góc, chuỗi rỗng cho tỉ lệ.
  ///
  /// Không được tự gắn `'°'` vào mọi giá trị: `knee_overshoot` là tỉ lệ theo
  /// chiều rộng khung hình, hiện `0.05°` khiến admin hiểu sai hoàn toàn thứ
  /// mình đang chỉnh.
  final String unit;

  /// Bước nhảy của thanh trượt: 1 cho góc, 0.01 cho tỉ lệ.
  final double step;

  /// Giá trị đang có hiệu lực — thứ analyzer thật sự dùng.
  double get effective => current ?? defaultValue;

  /// Số nấc của thanh trượt. Backend đảm bảo khoảng chia hết cho bước.
  int get divisions => ((maximum - minimum) / step).round();

  /// Định dạng một giá trị kèm đơn vị, với số chữ số thập phân hợp với bước.
  String format(double value) {
    final decimals = step >= 1 ? 0 : 2;
    return '${value.toStringAsFixed(decimals)}$unit';
  }

  /// Bài này có đang chạy khác mặc định không.
  bool get isOverridden => current != null;

  factory Tunable.fromJson(Map<String, dynamic> json) => Tunable(
        key: json['key'] as String,
        label: json['label'] as String,
        defaultValue: (json['default'] as num).toDouble(),
        current: (json['current'] as num?)?.toDouble(),
        minimum: (json['minimum'] as num).toDouble(),
        maximum: (json['maximum'] as num).toDouble(),
        affectsRepCount: json['affects_rep_count'] as bool,
        unit: json['unit'] as String,
        step: (json['step'] as num).toDouble(),
      );

  Tunable copyWith({double? current, bool clearCurrent = false}) => Tunable(
        key: key,
        label: label,
        defaultValue: defaultValue,
        current: clearCurrent ? null : (current ?? this.current),
        minimum: minimum,
        maximum: maximum,
        affectsRepCount: affectsRepCount,
        unit: unit,
        step: step,
      );
}

/// Toàn bộ ngưỡng chỉnh được của một bài tập.
class ExerciseRules {
  const ExerciseRules({
    required this.exerciseId,
    required this.exerciseName,
    required this.analyzer,
    required this.tunables,
  });

  final int exerciseId;
  final String exerciseName;
  final String analyzer;
  final List<Tunable> tunables;

  factory ExerciseRules.fromJson(Map<String, dynamic> json) => ExerciseRules(
        exerciseId: json['exercise_id'] as int,
        exerciseName: json['exercise_name'] as String,
        analyzer: json['analyzer'] as String,
        tunables: (json['tunables'] as List)
            .map((e) => Tunable.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Phần gửi lên khi lưu: chỉ những ngưỡng đang ghi đè.
  ///
  /// Đây là trạng thái ĐẦY ĐỦ mong muốn — khoá vắng mặt sẽ bị backend xoá và
  /// bài quay về mặc định. Nhờ vậy "gỡ ghi đè" chỉ là bỏ khoá ra khỏi map,
  /// không cần endpoint xoá riêng.
  Map<String, double> get overrides => {
        for (final t in tunables)
          if (t.current != null) t.key: t.current!,
      };

  ExerciseRules withTunable(Tunable updated) => ExerciseRules(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        analyzer: analyzer,
        tunables: [
          for (final t in tunables) t.key == updated.key ? updated : t,
        ],
      );
}

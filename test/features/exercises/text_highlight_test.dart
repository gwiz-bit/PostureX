import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posturex/utils/text_highlight.dart';

/// `highlightSpans` tô phần tên bài tập khớp với ô search bằng màu chủ đạo —
/// dùng ở tab Exercises. Test chốt: chia span đúng chỗ, giữ nguyên hoa/thường
/// của chuỗi gốc, so khớp không phân biệt hoa thường, và không search thì trả
/// đúng một span màu thường.

void main() {
  const base = TextStyle(color: Color(0xFF111111));
  const hi = TextStyle(color: Color(0xFFFF6F4F));

  List<TextSpan> run(String text, String query) =>
      highlightSpans(text, query, baseStyle: base, highlightStyle: hi);

  group('highlightSpans', () {
    test('query rỗng → đúng 1 span màu thường, nguyên văn', () {
      final spans = run('Barbell Back Squat', '');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Barbell Back Squat');
      expect(spans.single.style, base);
    });

    test('query chỉ có khoảng trắng cũng coi như rỗng', () {
      final spans = run('Barbell Back Squat', '   ');
      expect(spans, hasLength(1));
      expect(spans.single.style, base);
    });

    test('không khớp → đúng 1 span màu thường', () {
      final spans = run('Barbell Back Squat', 'deadlift');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Barbell Back Squat');
      expect(spans.single.style, base);
    });

    test('khớp giữa chuỗi → base / highlight / base', () {
      final spans = run('Barbell Back Squat', 'back');
      expect(spans.map((s) => s.text).toList(), ['Barbell ', 'Back', ' Squat']);
      expect(spans.map((s) => s.style).toList(), [base, hi, base]);
    });

    test('giữ nguyên hoa/thường của chuỗi gốc, chỉ so khớp lower-case', () {
      final spans = run('Barbell Back Squat', 'SQUAT');
      expect(spans.last.text, 'Squat');
      expect(spans.last.style, hi);
    });

    test('khớp ở đầu → highlight / base', () {
      final spans = run('Squat Jump', 'squat');
      expect(spans.map((s) => s.text).toList(), ['Squat', ' Jump']);
      expect(spans.map((s) => s.style).toList(), [hi, base]);
    });

    test('khớp ở cuối → base / highlight', () {
      final spans = run('Jump Squat', 'squat');
      expect(spans.map((s) => s.text).toList(), ['Jump ', 'Squat']);
      expect(spans.map((s) => s.style).toList(), [base, hi]);
    });

    test('nhiều lần xuất hiện → tô hết', () {
      final spans = run('Row Row Row', 'row');
      expect(spans.map((s) => s.text).toList(), ['Row', ' ', 'Row', ' ', 'Row']);
      expect(spans.map((s) => s.style).toList(), [hi, base, hi, base, hi]);
    });

    test('toàn bộ chuỗi khớp → đúng 1 span màu highlight', () {
      final spans = run('Squat', 'squat');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Squat');
      expect(spans.single.style, hi);
    });
  });
}

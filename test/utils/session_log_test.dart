import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/models/frame_analysis_result.dart' show KeyAngles;
import 'package:posturex/utils/session_log.dart';

void main() {
  late int now;
  SessionLogRecorder make({int maxLines = 3000}) => SessionLogRecorder(
    nowMs: () => now,
    maxLines: maxLines,
  );

  setUp(() => now = 0);

  List<String> body(SessionLogRecorder log) => log
      .toText()
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  test('mẫu định kỳ bị giới hạn tần suất, sự kiện thì không', () {
    final log = make();
    expect(log.row(phase: 'top', reps: 0, correct: true), isTrue);
    now = 80; // 12 fps: chưa tới 250ms
    expect(log.row(phase: 'top', reps: 0, correct: true), isFalse);
    log.event('rep 0->1');
    log.event('rep 1->2');
    now = 260;
    expect(log.row(phase: 'top', reps: 0, correct: true), isTrue);

    final lines = body(log);
    expect(lines.where((l) => l.startsWith('R,')).length, 2);
    expect(lines.where((l) => l.startsWith('E,')).length, 2);
  });

  test('dòng R có đủ cột theo đúng tiêu đề, góc thiếu để trống', () {
    final log = make();
    now = 1500;
    log.row(
      phase: 'bottom',
      reps: 3,
      correct: false,
      angles: const KeyAngles(leftKnee: 94.6, rightKnee: 96.2, backAngle: 150),
      similarity: 71.4,
      luma: 88.9,
      issue: 'lowLight',
      detectMs: 42,
      roundTripMs: 55,
    );
    final row = body(log).single.split(',');
    final headerCols = SessionLogRecorder.columnsHeader.split(',');

    expect(row.length, headerCols.length);
    String at(String name) => row[headerCols.indexOf(name)];
    expect(at('t_s'), '1.50');
    expect(at('phase'), 'bottom');
    expect(at('reps'), '3');
    expect(at('ok'), '0');
    expect(at('knee_l'), '95'); // 94.6 làm tròn
    expect(at('knee_r'), '96');
    expect(at('back'), '150');
    expect(at('elbow_l'), ''); // không có góc khuỷu ở bài này
    expect(at('similarity'), '71');
    expect(at('luma'), '89');
    expect(at('issue'), 'lowLight');
    expect(at('detect_ms'), '42');
    expect(at('roundtrip_ms'), '55');
  });

  test('tiêu đề cột khớp danh sách cột góc', () {
    final header = SessionLogRecorder.columnsHeader.split(',');
    final start = header.indexOf('shoulder_l');
    expect(
      header.sublist(start, start + SessionLogRecorder.angleColumns.length),
      SessionLogRecorder.angleColumns,
    );
  });

  test('sự kiện có xuống dòng không phá cấu trúc một dòng một bản ghi', () {
    final log = make()..event('lỗi\nhai dòng\r\nba dòng');
    expect(body(log), hasLength(1));
  });

  test('vượt trần thì bỏ dòng CŨ NHẤT và báo số dòng đã bỏ', () {
    final log = make(maxLines: 3);
    for (var i = 0; i < 5; i++) {
      log.event('sự kiện $i');
    }
    final text = log.toText();
    expect(log.lineCount, 3);
    expect(text, contains('sự kiện 4'));
    expect(text, isNot(contains('sự kiện 0')));
    expect(text, contains('dropped_oldest_lines: 2'));
  });

  test('phần đầu chứa siêu dữ liệu do bên gọi cung cấp', () {
    final text = make().toText(header: {'exercise': 'squat', 'mode': 'on-device'});
    expect(text, contains('# exercise: squat'));
    expect(text, contains('# mode: on-device'));
  });

  test('clear xoá sạch và cho ghi lại mẫu ngay', () {
    final log = make();
    log.row(phase: 'top', reps: 0, correct: true);
    log.event('x');
    log.clear();
    expect(log.lineCount, 0);
    expect(log.row(phase: 'top', reps: 0, correct: true), isTrue);
  });
}

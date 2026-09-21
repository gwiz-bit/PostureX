import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/services/analyze_socket_service.dart';

/// Server WebSocket giả chạy ngay trên máy, nói đúng giao thức của
/// `/api/v1/ws/analyze` — đủ để kiểm phía client mà không cần backend thật.
class _FakeAnalyzeServer {
  _FakeAnalyzeServer({this.echoInput = true});

  /// `false` mô phỏng server CŨ chưa biết chế độ keypoint: không echo `input`.
  final bool echoInput;

  late final HttpServer _http;
  final received = <String>[];
  final _got = StreamController<String>.broadcast();

  Uri get uri => Uri.parse('ws://${_http.address.host}:${_http.port}/ws/analyze');

  Future<void> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((message) {
        final text = message as String;
        received.add(text);
        _got.add(text);
        if (received.length == 1) {
          final init = jsonDecode(text) as Map<String, dynamic>;
          socket.add(jsonEncode({
            'status': 'ready',
            'exercise': init['exercise'],
            if (echoInput) 'input': init['input'] ?? 'image',
            'message': 'sẵn sàng',
          }));
        } else {
          socket.add(jsonEncode({'error': 'lỗi giả lập'}));
        }
      });
    });
  }

  Future<void> stop() => _http.close(force: true);

  /// Chờ tới khi server đã nhận đủ [count] message.
  Future<void> waitForMessages(int count) async {
    while (received.length < count) {
      await _got.stream.first.timeout(const Duration(seconds: 5));
    }
  }
}

void main() {
  // Lưu ý thứ tự trong mọi test: `socket.events` chỉ tồn tại SAU `connect`, và
  // luồng là broadcast (không phát lại). Lấy `events.first` ngay sau `connect`
  // vẫn kịp vì tin `ready` phải đi một vòng I/O mới tới nơi.
  late _FakeAnalyzeServer server;
  late AnalyzeSocketService socket;

  Future<void> boot({bool echoInput = true}) async {
    server = _FakeAnalyzeServer(echoInput: echoInput);
    await server.start();
    socket = AnalyzeSocketService(endpoint: server.uri);
  }

  tearDown(() async {
    await socket.close();
    await server.stop();
  });

  test('mặc định KHÔNG xin chế độ keypoint — client cũ hành xử y hệt trước', () async {
    await boot();
    await socket.connect('squat');
    final ready = socket.events.first;

    expect((await ready).input, analyzeInputImage);
    expect(jsonDecode(server.received.first), {'exercise': 'squat'});
  });

  test('xin chế độ keypoint và đọc lại chế độ server xác nhận', () async {
    await boot();
    await socket.connect('squat', onDevicePose: true);
    final ready = socket.events.first;

    expect((await ready).input, analyzeInputKeypoints);
    expect(jsonDecode(server.received.first), {
      'exercise': 'squat',
      'input': 'keypoints',
    });
  });

  test('server cũ không echo input thì input là null (client phải rơi về ảnh)',
      () async {
    await boot(echoInput: false);
    await socket.connect('squat', onDevicePose: true);
    final ready = socket.events.first;

    final event = await ready;
    expect(event.readyMessage, isNotNull);
    expect(event.input, isNull);
  });

  test('sendKeypoints gửi JSON đúng hình dạng backend mong đợi', () async {
    await boot();
    await socket.connect('squat', onDevicePose: true);
    final ready = socket.events.first;
    await ready;

    final pose = List.generate(33, (i) => [i / 100, 0.5, -0.1, 0.9]);
    socket.sendKeypoints(pose);
    await server.waitForMessages(2);

    final sent = jsonDecode(server.received[1]) as Map<String, dynamic>;
    expect((sent['keypoints'] as List), hasLength(33));
    expect((sent['keypoints'] as List)[7], [0.07, 0.5, -0.1, 0.9]);
  });

  test('null nghĩa là không thấy người và vẫn được gửi đi', () async {
    await boot();
    await socket.connect('squat', onDevicePose: true);
    final ready = socket.events.first;
    await ready;

    socket.sendKeypoints(null);
    await server.waitForMessages(2);

    expect(jsonDecode(server.received[1]), {'keypoints': null});
  });

  test('phản hồi lỗi của server thành sự kiện error', () async {
    await boot();
    await socket.connect('squat', onDevicePose: true);
    await socket.events.first; // ready

    final errorEvent = socket.events.firstWhere((e) => e.error != null);
    socket.sendKeypoints(null);

    expect((await errorEvent).error, 'lỗi giả lập');
  });
}

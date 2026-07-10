import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/frame_analysis_result.dart';

/// One of the three message shapes the analyze socket can emit for a given
/// inbound WebSocket message. Exactly one field is non-null.
class AnalyzeSocketEvent {
  const AnalyzeSocketEvent.ready(this.readyMessage)
      : frame = null,
        error = null;
  const AnalyzeSocketEvent.frame(FrameAnalysisResult this.frame)
      : readyMessage = null,
        error = null;
  const AnalyzeSocketEvent.error(String this.error)
      : readyMessage = null,
        frame = null;

  final String? readyMessage;
  final FrameAnalysisResult? frame;
  final String? error;
}

/// Wraps the `/api/v1/ws/analyze` protocol: connect, announce the exercise,
/// stream frames, and receive per-frame pose analysis. See BA.md /
/// app/api/v1/routes/realtime.py on the backend for the wire protocol —
/// there is no auth on this endpoint (a known backend gap, not fixed here).
class AnalyzeSocketService {
  WebSocketChannel? _channel;
  StreamController<AnalyzeSocketEvent>? _events;

  Stream<AnalyzeSocketEvent> get events => _events!.stream;

  Future<void> connect(String exercise) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('${ApiConfig.wsUrl}/api/v1/ws/analyze'),
    );
    await channel.ready;
    _channel = channel;
    _events = StreamController<AnalyzeSocketEvent>.broadcast();

    channel.stream.listen(
      _onMessage,
      onError: (Object e) => _events?.add(AnalyzeSocketEvent.error(e.toString())),
      onDone: () => _events?.close(),
    );

    channel.sink.add(jsonEncode({'exercise': exercise}));
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (json.containsKey('status')) {
      _events?.add(AnalyzeSocketEvent.ready(json['message'] as String? ?? ''));
      return;
    }
    if (json.containsKey('error')) {
      _events?.add(AnalyzeSocketEvent.error(json['error'] as String));
      return;
    }
    if (json.containsKey('rep_count')) {
      _events?.add(AnalyzeSocketEvent.frame(FrameAnalysisResult.fromJson(json)));
    }
  }

  void sendFrame(Uint8List jpegBytes) {
    _channel?.sink.add(base64Encode(jpegBytes));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    await _events?.close();
    _channel = null;
    _events = null;
  }
}

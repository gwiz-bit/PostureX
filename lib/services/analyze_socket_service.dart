import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/frame_analysis_result.dart';
import '../models/user_session.dart';

/// One of the three message shapes the analyze socket can emit for a given
/// inbound WebSocket message. Exactly one field is non-null.
class AnalyzeSocketEvent {
  const AnalyzeSocketEvent.ready(this.readyMessage, {this.input})
      : frame = null,
        error = null;
  const AnalyzeSocketEvent.frame(FrameAnalysisResult this.frame)
      : readyMessage = null,
        input = null,
        error = null;
  const AnalyzeSocketEvent.error(String this.error)
      : readyMessage = null,
        input = null,
        frame = null;

  final String? readyMessage;

  /// Cách server THẬT SỰ nhận tư thế cho phiên này (`"image"` hoặc
  /// `"keypoints"`), chỉ có ở sự kiện `ready`. `null` khi server cũ chưa biết
  /// trường này — người gọi phải coi đó là `"image"`: một server cũ nhận yêu
  /// cầu `keypoints` sẽ lặng lẽ bỏ qua nó và vẫn chờ ảnh JPEG.
  final String? input;
  final FrameAnalysisResult? frame;
  final String? error;
}

/// Hai cách client đưa tư thế cho server — xem `analyze_realtime` trong
/// `backend/app/api/v1/routes/realtime.py`.
const String analyzeInputImage = 'image';
const String analyzeInputKeypoints = 'keypoints';

/// Wraps the `/api/v1/ws/analyze` protocol: connect, announce the exercise,
/// stream frames, and receive per-frame pose analysis. See BA.md /
/// app/api/v1/routes/realtime.py on the backend for the wire protocol —
/// the endpoint requires the current session's access token as a `token`
/// query param (checked before the server accepts the handshake).
class AnalyzeSocketService {
  /// [endpoint] chỉ để test trỏ tới một server giả cục bộ; app thật luôn dùng
  /// `ApiConfig.wsUrl`.
  AnalyzeSocketService({this._endpoint});

  final Uri? _endpoint;
  WebSocketChannel? _channel;
  StreamController<AnalyzeSocketEvent>? _events;

  Stream<AnalyzeSocketEvent> get events => _events!.stream;

  /// Với [onDevicePose] = true, đề nghị server nhận keypoint đã nhận diện sẵn
  /// trên máy thay vì ảnh JPEG. Đây chỉ là ĐỀ NGHỊ: kết quả thật nằm trong
  /// [AnalyzeSocketEvent.input] của sự kiện `ready`.
  Future<void> connect(String exercise, {bool onDevicePose = false}) async {
    final uri = _endpoint ??
        Uri.parse('${ApiConfig.wsUrl}/api/v1/ws/analyze').replace(
          queryParameters: UserSession.accessToken != null
              ? {'token': UserSession.accessToken}
              : null,
        );
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _events = StreamController<AnalyzeSocketEvent>.broadcast();

    channel.stream.listen(
      _onMessage,
      onError: (Object e) => _events?.add(AnalyzeSocketEvent.error(e.toString())),
      onDone: () => _events?.close(),
    );

    channel.sink.add(jsonEncode({
      'exercise': exercise,
      if (onDevicePose) 'input': analyzeInputKeypoints,
    }));
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
      _events?.add(AnalyzeSocketEvent.ready(
        json['message'] as String? ?? '',
        input: json['input'] as String?,
      ));
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

  /// Gửi một frame keypoint đã nhận diện trên máy (chỉ dùng khi `ready` xác
  /// nhận `input == "keypoints"`). [keypoints] là 33 phần tử
  /// `[x, y, z, visibility]` (xem `encodeLandmarks`), hoặc `null` khi không
  /// thấy người — server vẫn trả đúng một phản hồi cho cả hai trường hợp.
  void sendKeypoints(List<List<double>>? keypoints) {
    _channel?.sink.add(jsonEncode({'keypoints': keypoints}));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    await _events?.close();
    _channel = null;
    _events = null;
  }
}

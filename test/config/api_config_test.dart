import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/config/api_config.dart';

/// Pins the two things about [ApiConfig] that have actually gone wrong.
///
/// The default host matters more than it looks: `API_BASE_URL` is a
/// compile-time constant, so a build that forgets `--dart-define` silently
/// falls back to whatever is hardcoded here. When that fallback was a dev
/// address, forgetting the flag produced an app that could never reach any
/// server — three separate debugging sessions went into exactly that, and a
/// release build with the same mistake would have shipped broken to every
/// user. These tests fail loudly if the default drifts back.
void main() {
  group('ApiConfig', () {
    test('defaults to the real server when no --dart-define is passed', () {
      // Run without --dart-define (the normal case for `flutter test`), so
      // this asserts the compiled-in fallback, not an override.
      expect(ApiConfig.baseUrl, 'https://api.posturex1.com');
      expect(
        ApiConfig.baseUrl,
        isNot(contains('10.0.2.2')),
        reason: '10.0.2.2 only resolves on an Android emulator — useless in a released app',
      );
      expect(ApiConfig.baseUrl, isNot(contains('localhost')));
    });

    test('wsUrl keeps baseUrl host and port, swapping only the scheme', () {
      final base = Uri.parse(ApiConfig.baseUrl);
      final ws = Uri.parse(ApiConfig.wsUrl);

      expect(ws.host, base.host);
      // `Uri.port` chỉ biết cổng mặc định cho http/https, không biết ws/wss —
      // so `hasPort` (có ghi cổng tường minh trong chuỗi URL hay không) thay
      // vì so số `.port`, để không vỡ khi baseUrl không ghi cổng (domain thật
      // dùng cổng mặc định 443, khác lúc trước dùng IP:9000 tường minh).
      expect(ws.hasPort, base.hasPort);
      if (base.hasPort) expect(ws.port, base.port);
      expect(ws.scheme, base.scheme == 'https' ? 'wss' : 'ws');
    });
  });
}

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posturex/services/api_client.dart';
import 'package:posturex/services/api_exception.dart';

/// Pins that a stalled request fails instead of hanging forever.
///
/// `package:http` has no default timeout, so before this the app would spin
/// indefinitely whenever the server accepted the connection and then went
/// quiet — a dead VPS, a captive-portal Wi-Fi, a backend stuck on a slow
/// upstream call. The only way out was force-quitting the app.
///
/// Uses `fakeAsync` so the 20s budget elapses instantly instead of making the
/// suite wait for real.
void main() {
  /// A client that accepts the request and then never answers.
  ApiClient stalling() => ApiClient(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(minutes: 10));
          return http.Response('{}', 200);
        }),
      );

  test('a request that never answers throws ApiException 408', () {
    fakeAsync((async) {
      Object? thrown;
      stalling().fetchExercises().catchError((Object e) {
        thrown = e;
        return <Never>[];
      });

      // Ngay trước hạn vẫn còn chờ — chưa được bỏ cuộc sớm.
      async.elapse(const Duration(seconds: 19));
      expect(thrown, isNull);

      async.elapse(const Duration(seconds: 2));
      expect(thrown, isA<ApiException>());
      expect((thrown! as ApiException).statusCode, ApiClient.timeoutStatusCode);
    });
  });

  test('AI Coach gets a longer budget than an ordinary call', () {
    fakeAsync((async) {
      Object? thrown;
      stalling()
          .sendCoachMessage(message: 'xin chào', history: const [])
          .catchError((Object e) {
        thrown = e;
        return '';
      });

      // Quá hạn của một request thường mà vẫn phải chờ: Gemini hay mất
      // 5-20s, áp hạn 20s vào đây là cắt ngang những lượt sắp thành công.
      async.elapse(const Duration(seconds: 30));
      expect(thrown, isNull);

      async.elapse(const Duration(seconds: 65));
      expect(thrown, isA<ApiException>());
    });
  });

  test('a normal response is unaffected', () async {
    final client = ApiClient(
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(await client.fetchExercises(), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/core/errors/failures.dart';
import 'package:posturex/features/coach/domain/entities/chat_message.dart';
import 'package:posturex/features/coach/domain/repositories/coach_repository.dart';
import 'package:posturex/features/coach/domain/usecases/clear_coach_history.dart';
import 'package:posturex/features/coach/domain/usecases/fetch_coach_history.dart';
import 'package:posturex/features/coach/domain/usecases/report_coach_message.dart';
import 'package:posturex/features/coach/domain/usecases/send_coach_message.dart';
import 'package:posturex/features/coach/presentation/controllers/ai_coach_controller.dart';

class _FakeRepository implements CoachRepository {
  _FakeRepository({this.failReport = false});

  final bool failReport;
  final List<(String, String)> reports = [];

  @override
  Future<void> reportMessage({required String reason, required String content}) async {
    if (failReport) throw const ServerFailure('boom');
    reports.add((reason, content));
  }

  @override
  Future<String> sendMessage({required String message}) async => 'reply';

  @override
  Future<List<ChatMessage>> fetchHistory() async => const [];

  @override
  Future<void> clearHistory() async {}
}

AiCoachController _controller(CoachRepository repo) => AiCoachController(
      sendCoachMessage: SendCoachMessage(repo),
      fetchCoachHistory: FetchCoachHistory(repo),
      clearCoachHistory: ClearCoachHistory(repo),
      reportCoachMessage: ReportCoachMessage(repo),
    );

void main() {
  test('report sends the reason and the AI reply text to the repository', () async {
    final repo = _FakeRepository();
    final controller = _controller(repo);

    final ok = await controller.report(reason: 'unsafe', content: 'Fast for 3 days.');

    expect(ok, isTrue);
    expect(repo.reports, [('unsafe', 'Fast for 3 days.')]);
  });

  test('a failed report returns false and surfaces the server message', () async {
    final controller = _controller(_FakeRepository(failReport: true));

    final ok = await controller.report(reason: 'other', content: 'x');

    expect(ok, isFalse);
    expect(controller.errorMessage, 'boom');
  });
}

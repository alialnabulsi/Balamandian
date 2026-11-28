import 'dart:async';

import 'package:balamandian/data/repositories/ai_assistant_repository.dart';
import 'package:balamandian/domain/models/ai_conversation.dart';
import 'package:balamandian/domain/models/guide_article_ref.dart';

const chatId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherChatId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const articleId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const arabicQuestion = 'كيف فيني قدّم طلب Official Transcript يا Registrar؟';
const englishAnswer = '''
## Official transcript

Contact the **Office of the Registrar** to ask about an official transcript. [1]

- Check your student ID.
- Confirm the request details.
''';
const mixedAnswer = '''
## طلب إفادة رسمية

إذا كنت بحاجة إلى **Official Transcript**، يمكنك مراجعة Office of the Registrar. تأكد من رقم الطالب Student ID قبل تقديم الطلب. [1]

١. افتح صفحة المسجّل.
   - تحقّق من بريدك الجامعي student@balamand.edu.lb.
٢. تأكّد من رمز المقرر ENGL 203 والتاريخ 03/12/2026. [2]

> احتفظ بالنسخة الأصلية للرجوع إليها.

| الخدمة | المكتب | التاريخ |
| --- | --- | --- |
| الإفادة | Registrar | 03/12/2026 |
| نموذج الطلب | Student Affairs | 15/12/2026 |

For help with delivery, ask which options apply to your request.
''';

final citedSources = [
  AiCitation(
    const GuideArticleRef(
      articleId: articleId,
      version: 4,
      title: 'Registrar services',
    ),
    'Official transcripts',
    AiAvailability.current,
    AiSource(
      'University of Balamand',
      Uri.parse('https://www.balamand.edu.lb/'),
    ),
  ),
  AiCitation(
    const GuideArticleRef(
      articleId: articleId,
      version: 2,
      title: 'Student forms',
    ),
    'Request forms',
    AiAvailability.updated,
    AiSource(
      'University of Balamand',
      Uri.parse('https://www.balamand.edu.lb/'),
    ),
  ),
];

AiTurn fixtureTurn(
  int number,
  String question,
  String body, {
  List<AiCitation> citations = const [],
}) => AiTurn(number, 'user-$number', question, [
  AiAttempt(
    id: 'answer-$number',
    generationId: 'generation-$number',
    number: 1,
    status: AiStatus.completed,
    body: body,
    citations: citations,
  ),
]);

class FixtureAiRepository implements AiAssistantRepository {
  final items = <AiConversation>[];
  final threads = <String, List<AiTurn>>{};
  final older = <String, List<AiTurn>>{};
  final requests = <FixtureRun>[];
  final fetched = <(String, String?)>[];
  final historyCursors = <String?>[];
  final votes = <(String, String, int?)>[];
  final lookup = <String>[];
  final cancellations = <String>[];
  AiGeneration? saved;
  Object? historyFailure;
  Object? generationFailure;
  Object? sendFailure;
  int created = 0;

  @override
  Future<AiConversation> create({String? title}) async {
    created++;
    final result = AiConversation(
      chatId,
      title ?? 'New conversation',
      DateTime.utc(2026, 12, 3),
    );
    items.insert(0, result);
    return result;
  }

  @override
  Future<AiPage<AiConversation>> conversations({String? cursor}) async {
    historyCursors.add(cursor);
    if (historyFailure case final failure?) throw failure;
    return cursor == null
        ? AiPage(
            items.take(1).toList(),
            items.length > 1 ? 'history-cursor' : null,
          )
        : AiPage(items.skip(1).toList(), null);
  }

  @override
  Future<AiConversation> rename(String conversationId, String title) async {
    final index = items.indexWhere((item) => item.id == conversationId);
    return items[index] = AiConversation(
      conversationId,
      title,
      DateTime.utc(2026, 12, 3),
    );
  }

  @override
  Future<void> delete(String conversationId) async {
    items.removeWhere((item) => item.id == conversationId);
    threads.remove(conversationId);
  }

  @override
  Future<AiPage<AiTurn>> turns(String conversationId, {String? before}) async {
    fetched.add((conversationId, before));
    if (historyFailure case final failure?) throw failure;
    final past = older[conversationId];
    return before == null
        ? AiPage(
            threads[conversationId] ?? [],
            past == null ? null : 'turn-cursor',
          )
        : AiPage(past ?? [], null);
  }

  @override
  Future<AiGeneration> generation(
    String conversationId,
    String generationId,
  ) async {
    lookup.add(generationId);
    if (generationFailure case final failure?) throw failure;
    return saved!;
  }

  @override
  Future<AiGeneration> cancel(
    String conversationId,
    String generationId,
  ) async {
    cancellations.add(generationId);
    return AiGeneration(
      requests.last.ids,
      AiStatus.cancelled,
      null,
      const [],
      'AI_CANCELLED',
    );
  }

  @override
  Future<void> feedback(
    String conversationId,
    String assistantId,
    int? vote,
  ) async => votes.add((conversationId, assistantId, vote));

  @override
  Future<void> generate({
    required String conversationId,
    required String requestKey,
    required Future<void> abort,
    required void Function(AiStreamEvent) onEvent,
    String? text,
    String? locale,
    String? contextArticleId,
    String? regenerateUserId,
  }) {
    final serial = requests.length + 1;
    final run = FixtureRun(
      AiGenerationIds(
        'stream-$serial',
        regenerateUserId ?? 'prompt-$serial',
        'reply-$serial',
      ),
      onEvent,
      requestKey,
      text,
      locale,
      contextArticleId,
      regenerateUserId,
    );
    requests.add(run);
    unawaited(
      abort.then((_) {
        run.aborted = true;
        if (!run.finished.isCompleted) run.finished.complete();
      }),
    );
    if (sendFailure case final failure?) run.finished.completeError(failure);
    return run.finished.future;
  }

  void complete(String body, {List<AiCitation> citations = const []}) {
    final run = requests.last;
    final result = AiGeneration(
      run.ids,
      AiStatus.completed,
      body,
      citations,
      null,
    );
    run.emit(AiTerminal(result));
    if (!run.finished.isCompleted) run.finished.complete();
  }
}

class FixtureRun {
  FixtureRun(
    this.ids,
    this.emit,
    this.key,
    this.text,
    this.locale,
    this.context,
    this.regenerate,
  );
  final AiGenerationIds ids;
  final void Function(AiStreamEvent) emit;
  final String key;
  final String? text, locale, context, regenerate;
  final finished = Completer<void>();
  bool aborted = false;

  void start() => emit(AiStart(ids));
  void delta(String text) => emit(AiDelta(text));
  void interrupt() =>
      finished.completeError(const AiFailure('STREAM_INTERRUPTED'));
}

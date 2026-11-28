import 'dart:async';
import 'dart:convert';

import 'package:balamandian/data/repositories/api_ai_assistant_repository.dart';
import 'package:balamandian/data/services/ai_assistant_api_service.dart';
import 'package:balamandian/domain/models/ai_conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth_test_support.dart';

const ids = {
  'generationId': 'generation',
  'userMessageId': 'question',
  'assistantMessageId': 'answer',
};

String frame(String name, Map<String, Object?> data) =>
    'event: $name\r\ndata: ${jsonEncode(data)}\r\n\r\n';

Stream<List<int>> pieces(String text) =>
    Stream.fromIterable(utf8.encode(text).map((byte) => [byte]));

void main() {
  test(
    'authenticated POST consumes a real streamed response without buffering',
    () async {
      final body = StreamController<List<int>>();
      final started = Completer<void>();
      final received = <AiStreamEvent>[];
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('F', 'test');
      final transport = AiAssistantApiService(
        MockClient.streaming((request, bytes) async {
          expect(
            request.url.path,
            '/api/v1/ai/conversations/chat/messages:stream',
          );
          expect(request.headers['accept'], contains('text/event-stream'));
          expect(
            jsonDecode(utf8.decode(await bytes.toBytes()))['locale'],
            'ar',
          );
          return http.StreamedResponse(
            body.stream,
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
        Uri.parse('https://api.example.test'),
      );
      addTearDown(transport.close);
      final result = ApiAiAssistantRepository(transport, auth.repository)
          .generate(
            conversationId: 'chat',
            requestKey: 'test-key',
            abort: Completer<void>().future,
            text: 'التقويم الأكاديمي',
            locale: 'ar',
            onEvent: (event) {
              received.add(event);
              if (event is AiStart) started.complete();
            },
          );
      body.add(utf8.encode(frame('start', ids)));
      await started.future;
      expect(received, hasLength(1));
      body.add(
        utf8.encode(
          frame('done', {
            'generationId': 'generation',
            'status': 'completed',
            'body': 'التقويم الجامعي',
            'citations': [],
          }),
        ),
      );
      await body.close();
      await result;
      expect((received.last as AiTerminal).result.body, 'التقويم الجامعي');
    },
  );

  test('decodes byte-split Arabic, CRLF, heartbeats, and a canonical done', () async {
    final events = await parseAiEvents(
      pieces(
        ': heartbeat\r\n\r\n'
        '${frame('start', ids)}'
        '${frame('delta', {'sequence': 1, 'text': 'إذا احتجت '})}'
        '${frame('delta', {'sequence': 2, 'text': 'Official Transcript [[E1]]'})}'
        '${frame('done', {
          'generationId': 'generation',
          'status': 'completed',
          'body': 'النسخة الرسمية [1]',
          'citations': [
            {
              'articleId': 'article',
              'version': 4,
              'title': 'السجل',
              'heading': 'Transcript',
              'availability': 'updated',
              'source': {'label': 'University of Balamand', 'url': 'https://www.balamand.edu.lb/'},
            },
          ],
        })}',
      ),
    ).toList();
    expect(events.first, isA<AiStart>());
    expect(
      events.whereType<AiDelta>().map((event) => event.text).join(),
      'إذا احتجت Official Transcript [[E1]]',
    );
    final saved = (events.last as AiTerminal).result;
    expect(saved.body, 'النسخة الرسمية [1]');
    expect(saved.citations.single.article.version, 4);
    expect(saved.citations.single.availability, AiAvailability.updated);
  });

  test('rejects a sequence gap and an unterminated done frame', () async {
    await expectLater(
      parseAiEvents(
        pieces(
          frame('start', ids) + frame('delta', {'sequence': 2, 'text': 'x'}),
        ),
      ),
      emitsInOrder([isA<AiStart>(), emitsError(isA<AiFailure>())]),
    );
    await expectLater(
      parseAiEvents(
        pieces(
          frame('start', ids) +
              frame('done', {
                'generationId': 'generation',
                'status': 'completed',
                'body': 'x',
                'citations': [],
              }).trimRight(),
        ),
      ),
      emitsInOrder([
        isA<AiStart>(),
        emitsError(
          isA<AiFailure>().having((e) => e.code, 'code', 'STREAM_INTERRUPTED'),
        ),
      ]),
    );
  });

  test('terminal error carries persisted cancellation and discards provisional body', () async {
    final events = await parseAiEvents(
      pieces(
        frame('start', ids) +
            frame('error', {
              'generationId': 'generation',
              'status': 'cancelled',
              'code': 'AI_CANCELLED',
              'message': 'ignored',
            }),
      ),
    ).toList();
    expect((events.last as AiTerminal).result.status, AiStatus.cancelled);
    expect((events.last as AiTerminal).result.body, isNull);
  });

  test('API uses bearer POST, opaque cursors, replay, and a safe rate-limit message', () async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('F', 'test');
    final calls = <http.Request>[];
    final api = AiAssistantApiService(
      MockClient((request) async {
        calls.add(request);
        expect(
          request.headers['authorization'],
          'Bearer ${List.filled(43, 'A').join()}',
        );
        if (request.url.path.endsWith('messages:stream')) {
          expect(request.method, 'POST');
          expect(jsonDecode(utf8.decode(request.bodyBytes)), {
            'text': 'كيف أطلب Official Transcript؟',
            'locale': 'ar',
            'contextArticleId': 'article',
          });
          expect(request.headers['idempotency-key'], 'request-key');
          return http.Response(
            jsonEncode({
              'data': {...ids, 'status': 'completed'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith(':regenerate')) {
          return failure('RATE_LIMITED', status: 429, retryAfter: 15);
        }
        return success({'items': [], 'nextCursor': 'next-page'}, 200);
      }),
      Uri.parse('https://api.example.test'),
    );
    addTearDown(api.close);
    final repository = ApiAiAssistantRepository(api, auth.repository);
    final output = <AiStreamEvent>[];
    await repository.generate(
      conversationId: 'conversation',
      requestKey: 'request-key',
      abort: Completer<void>().future,
      onEvent: output.add,
      text: 'كيف أطلب Official Transcript؟',
      locale: 'ar',
      contextArticleId: 'article',
    );
    expect((output.single as AiStart).replay, isTrue);
    expect(
      (await repository.conversations(cursor: 'token+next')).nextCursor,
      'next-page',
    );
    expect(calls.last.url.queryParameters, {'cursor': 'token+next'});
    await repository.turns('conversation', before: 'token+older');
    expect(calls.last.url.queryParameters, {'before': 'token+older'});
    await expectLater(
      repository.generate(
        conversationId: 'conversation',
        regenerateUserId: 'question',
        requestKey: 'regen-key',
        abort: Completer<void>().future,
        onEvent: output.add,
      ),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.retryAfter,
          'Retry-After',
          const Duration(seconds: 15),
        ),
      ),
    );
    expect(
      calls.last.url.path,
      '/api/v1/ai/conversations/conversation/messages/question:regenerate',
    );
  });

  test(
    'unavailable source drops the URL and external link validation uses HTTPS',
    () {
      final citation = AiCitation.fromJson({
        'articleId': 'article',
        'version': 2,
        'title': 'Article',
        'heading': null,
        'availability': 'unavailable',
        'source': {'label': 'Should be dropped', 'url': 'https://example.com'},
      });
      expect(citation.source, isNull);
      expect(safeAiUrl('javascript:alert(1)'), isNull);
      expect(safeAiUrl('https://student@example.edu'), isNull);
      expect(safeAiUrl('https://example.edu/registrar'), isNotNull);
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:balamandian/data/services/guide_api_service.dart';
import 'package:balamandian/data/repositories/api_guide_repository.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/guide_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../guide_test_support.dart';

void main() {
  test('all seven endpoints use exact queries, UTF-8, bearer sessions and empty 204', () async {
    final requests = <http.Request>[];
    final api = GuideApiService(
      client: MockClient((r) async {
        requests.add(r);
        expect(r.headers['Authorization'], 'Bearer private-test-token');
        expect(r.followRedirects, isFalse);
        expect(r.body, isEmpty);
        Object? data;
        if (r.method != 'GET') return http.Response('', 204);
        if (r.url.path.endsWith('/sections')) {
          data = [guideSectionJson()];
        } else if (r.url.path.contains('/sections/')) {
          final d = guideSectionDetail();
          data = {
            'section': guideSectionJson(),
            'breadcrumb': [guideSectionJson()],
            'subsections': [guideSectionJson(child: true)],
            'articles': {
              'items': d.articles.items.map((_) => guideSummaryJson()).toList(),
              'nextCursor': null,
            },
          };
        } else if (r.url.path.contains('/articles/')) {
          data = guideArticleJson(locale: 'ar', title: 'التقويم الأكاديمي');
        } else {
          data = {
            'items': [guideSummaryJson()],
            'nextCursor': 'opaque_-cursor',
          };
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'data': data})),
          200,
        );
      }),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    addTearDown(api.close);
    expect(
      (await api.sections('private-test-token', GuideLocale.ar)).single.id,
      guideRootId,
    );
    expect(
      (await api.section(
        'private-test-token',
        guideRootId,
        GuideLocale.en,
        'opaque+query&',
      )).section.id,
      guideRootId,
    );
    final article = await api.article('private-test-token', guideArticleId);
    expect(article.summary.title, 'التقويم الأكاديمي');
    expect(article.sources.single.locator, isNull);
    expect(article.academicYear, isNull);
    expect(article.validFrom, isNull);
    expect(article.validUntil, isNull);
    expect(
      (await api.search(
        'private-test-token',
        'التقويم',
        GuideLocale.ar,
        'cursor',
      )).nextCursor,
      'opaque_-cursor',
    );
    await api.bookmarks('private-test-token', 'saved');
    await api.save('private-test-token', guideArticleId);
    await api.remove('private-test-token', guideArticleId);
    expect(requests.map((r) => r.method), [
      'GET',
      'GET',
      'GET',
      'GET',
      'GET',
      'PUT',
      'DELETE',
    ]);
    expect(requests[0].url.queryParameters, {'locale': 'ar'});
    expect(requests[1].url.queryParameters, {
      'locale': 'en',
      'articleCursor': 'opaque+query&',
    });
    expect(requests[2].url.queryParameters, isEmpty);
    expect(requests[3].url.queryParameters, {
      'q': 'التقويم',
      'locale': 'ar',
      'cursor': 'cursor',
    });
    expect(requests[4].url.queryParameters, {'cursor': 'saved'});
    expect(
      requests.every((r) => r.url.path.startsWith('/api/v1/guide/')),
      isTrue,
    );
  });

  test(
    'errors are allowlisted, with 401 delegated to the real session lifecycle',
    () async {
      var code = 'INVALID_REQUEST', status = 400;
      final api = GuideApiService(
        client: MockClient((_) async => failure(code, status: status)),
        baseUrl: Uri.parse('https://api.example.test'),
      );
      addTearDown(api.close);
      for (final pair in [
        ('INVALID_REQUEST', 400),
        ('ARTICLE_NOT_FOUND', 404),
        ('SECTION_NOT_FOUND', 404),
        ('private stack', 500),
      ]) {
        code = pair.$1;
        status = pair.$2;
        await expectLater(
          api.article('token', guideArticleId),
          throwsA(
            isA<GuideFailure>().having(
              (e) => e.message.contains('Untrusted'),
              'safe message',
              false,
            ),
          ),
        );
      }
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final repo = ApiGuideRepository(
        api: api,
        withSession: auth.repository.withSession,
      );
      code = 'UNAUTHENTICATED';
      status = 401;
      await expectLater(
        repo.article(guideArticleId),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.repository.user, isNull);
      expect(auth.store.session, isNull);
    },
  );

  test('malformed payloads, timeout and network errors remain safe', () async {
    for (final body in ['<private proxy html>', '{}', '{"data":{}}']) {
      final api = GuideApiService(
        client: MockClient((_) async => http.Response(body, 200)),
        baseUrl: Uri.parse('https://api.example.test'),
      );
      await expectLater(
        api.article('token', guideArticleId),
        throwsA(
          isA<GuideFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
      api.close();
    }
    final wait = Completer<http.Response>();
    final slow = GuideApiService(
      client: MockClient((_) => wait.future),
      baseUrl: Uri.parse('https://api.example.test'),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      slow.sections('token', GuideLocale.en),
      throwsA(isA<GuideFailure>().having((e) => e.code, 'code', 'NETWORK')),
    );
    wait.complete(http.Response('{}', 200));
    slow.close();
    final offline = GuideApiService(
      client: MockClient((_) async => throw http.ClientException('private')),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    await expectLater(
      offline.bookmarks('token', null),
      throwsA(isA<GuideFailure>()),
    );
    offline.close();
  });

  test(
    'repository rejects a late response after cancellation/account change',
    () async {
      final wait = Completer<http.Response>();
      final api = GuideApiService(
        client: MockClient((_) => wait.future),
        baseUrl: Uri.parse('https://api.example.test'),
      );
      addTearDown(api.close);
      final repo = ApiGuideRepository(
        api: api,
        withSession: <T>(request) => request('token'),
      );
      final result = repo.article(guideArticleId);
      final check = expectLater(result, throwsA(isA<GuideFailure>()));
      repo.cancelPending();
      wait.complete(
        http.Response(jsonEncode({'data': guideArticleJson()}), 200),
      );
      await check;
    },
  );

  test('model parsing preserves shared references, optional excerpt and nullable applicability', () {
    final json = guideArticleJson()
      ..['academicYear'] = '2026-2027'
      ..['validFrom'] = '2026-09-01T00:00:00+03:00'
      ..['validUntil'] = '2027-09-01T00:00:00+03:00';
    final article = GuideArticle.fromJson(json);
    expect(article.summary.ref.articleId, guideArticleId);
    expect(article.validFrom!.isUtc, isTrue);
    expect(article.validFrom!.hour, 21);
    expect(article.summary.excerpt, isNull);
    expect(article.academicYear, '2026-2027');
    expect(() => article.sources.clear(), throwsUnsupportedError);
    final page = GuidePage.fromJson({
      'items': [
        {...guideSummaryJson(), 'excerpt': 'Visible text'},
      ],
      'nextCursor': null,
    });
    expect(page.items.single.excerpt, 'Visible text');
    expect(
      () => GuidePage.fromJson({'items': [], 'nextCursor': 'loop'}),
      throwsFormatException,
    );
  });
}

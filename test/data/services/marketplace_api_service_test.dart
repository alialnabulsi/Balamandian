import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:balamandian/data/services/marketplace_api_service.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../marketplace_test_support.dart';

MarketplaceApiService api(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 20),
}) => MarketplaceApiService(
  client: MockClient(handler),
  baseUrl: Uri.parse('https://api.example.test'),
  timeout: timeout,
);
http.Response envelope(Object? data, {int status = 200}) =>
    http.Response(jsonEncode({'data': data}), status);
void main() {
  test('validates origin and timeout using auth-compatible policy', () {
    for (final url in [
      'http://api.example.test',
      'https://user:secret@example.test',
      'https://api.example.test/api',
      'https://api.example.test?q=1',
      'https://api.example.test/#x',
    ]) {
      expect(
        () => MarketplaceApiService(
          client: MockClient((_) async => envelope([])),
          baseUrl: Uri.parse(url),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => api((_) async => envelope([]), timeout: Duration.zero),
      throwsArgumentError,
    );
  });
  test('all reads use authenticated exact paths, query encoding and data contracts', () async {
    final requests = <http.Request>[];
    final service = api((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer private-test-token');
      expect(request.headers['Accept'], 'application/json');
      expect(request.followRedirects, isFalse);
      expect(request.body, isEmpty);
      expect(request.headers['Content-Type'], isNull);
      final path = request.url.path;
      if (path.endsWith('categories')) return envelope([categoryJson()]);
      if (path.endsWith('/$marketPlaceId')) return envelope(detailJson());
      return envelope({
        'items': [path.endsWith('posts') ? postJson() : placeJson()],
        'pagination': paginationJson(
          page: int.parse(request.url.queryParameters['page']!),
          limit: int.parse(request.url.queryParameters['limit']!),
        ),
      });
    });
    addTearDown(service.close);
    expect(
      (await service.categories('private-test-token')).single.name,
      'Coffee & bites',
    );
    await service.places(
      'private-test-token',
      search: '  coffee & bites + books  ',
      category: 'fictional-coffee',
      page: 2,
      limit: 5,
    );
    expect(requests.last.url.path, '/api/marketplace/places');
    expect(requests.last.url.queryParameters, {
      'search': 'coffee & bites + books',
      'category': 'fictional-coffee',
      'page': '2',
      'limit': '5',
    });
    expect(
      (await service.place('private-test-token', marketPlaceId)).latitude,
      34.1,
    );
    await service.posts(
      'private-test-token',
      type: 'advertisement',
      placeId: marketPlaceId,
      page: 2,
      limit: 5,
    );
    expect(requests.last.url.queryParameters, {
      'type': 'advertisement',
      'placeId': marketPlaceId,
      'page': '2',
      'limit': '5',
    });
  });
  test('favorites and rating DELETE have no body or JSON headers; rating PUT sends exactly rating JSON', () async {
    final requests = <http.Request>[];
    final service = api((r) async {
      requests.add(r);
      return envelope(
        r.url.path.endsWith('favorite')
            ? {'placeId': marketPlaceId, 'isFavorite': r.method == 'PUT'}
            : {
                'placeId': marketPlaceId,
                'myRating': r.method == 'PUT' ? 4 : null,
                'averageRating': r.method == 'PUT' ? 4 : 0,
                'ratingCount': r.method == 'PUT' ? 1 : 0,
              },
      );
    });
    addTearDown(service.close);
    await service.favorite('token', marketPlaceId, true);
    await service.favorite('token', marketPlaceId, false);
    await service.rating('token', marketPlaceId, 4);
    await service.rating('token', marketPlaceId, null);
    expect(requests.map((r) => r.method), ['PUT', 'DELETE', 'PUT', 'DELETE']);
    for (final i in [0, 1, 3]) {
      expect(requests[i].body, isEmpty);
      expect(requests[i].headers['Content-Type'], isNull);
    }
    expect(jsonDecode(requests[2].body), {'rating': 4});
    expect(requests[2].headers['Content-Type'], contains('application/json'));
  });
  for (final status in [201, 204, 302, 500]) {
    test('only documented 200 status is accepted ($status)', () async {
      final service = api((_) async => envelope([], status: status));
      addTearDown(service.close);
      await expectLater(
        service.categories('t'),
        throwsA(isA<MarketplaceFailure>()),
      );
    });
  }
  test('safe errors ignore server text, clamp Retry-After and preserve unauthenticated AuthFailure', () async {
    for (final seconds in ['999999', '0', '-1', 'invalid']) {
      final service = api(
        (_) async => http.Response(
          '{"error":{"code":"RATE_LIMITED","message":"private token SQL"}}',
          429,
          headers: {'retry-after': seconds},
        ),
      );
      try {
        await service.categories('t');
        fail('Expected failure');
      } on MarketplaceFailure catch (e) {
        expect(e.code, 'RATE_LIMITED');
        expect(e.message, isNot(contains('private')));
        expect(
          e.retryAfter,
          seconds == '999999' ? const Duration(seconds: 900) : isNull,
        );
      } finally {
        service.close();
      }
    }
    final service = api(
      (_) async => http.Response(
        '{"error":{"code":"UNAUTHENTICATED","message":"private"}}',
        401,
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.categories('t'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.invalidSession,
          'invalid session',
          true,
        ),
      ),
    );
  });
  for (final payload in ['{', '{}', '{"data":null}', '{"data":[{}]}']) {
    test(
      'malformed response becomes safe invalid-response failure $payload',
      () async {
        final service = api((_) async => http.Response(payload, 200));
        addTearDown(service.close);
        await expectLater(
          service.categories('t'),
          throwsA(
            isA<MarketplaceFailure>().having(
              (e) => e.code,
              'code',
              'INVALID_RESPONSE',
            ),
          ),
        );
      },
    );
  }
  test('socket, client and timeout failures become local safe failures with no mutation retry', () async {
    for (final error in [
      const SocketException('private host'),
      http.ClientException('private url'),
      TimeoutException('private timeout'),
    ]) {
      var calls = 0;
      final service = api((_) async {
        calls++;
        throw error;
      });
      await expectLater(
        service.favorite('t', marketPlaceId, true),
        throwsA(
          isA<MarketplaceFailure>().having(
            (e) => e.code,
            'code',
            'NETWORK_ERROR',
          ),
        ),
      );
      expect(calls, 1);
      service.close();
    }
    final gate = Completer<http.Response>();
    final service = api(
      (_) => gate.future,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      service.rating('t', marketPlaceId, 4),
      throwsA(
        isA<MarketplaceFailure>().having(
          (e) => e.code,
          'code',
          'NETWORK_ERROR',
        ),
      ),
    );
    gate.complete(envelope({}));
    service.close();
  });
}

import 'dart:convert';

import 'package:balamandian/data/repositories/api_marketplace_repository.dart';
import 'package:balamandian/data/services/marketplace_api_service.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';

void main() {
  test('every repository operation uses only the injected authenticated capability', () async {
    var capabilities = 0, requests = 0;
    Future<T> authenticated<T>(Future<T> Function(String) callback) async {
      capabilities++;
      return callback('capability-token');
    }

    final service = MarketplaceApiService(
      baseUrl: Uri.parse('https://api.example.test'),
      client: MockClient((r) async {
        requests++;
        expect(r.headers['Authorization'], 'Bearer capability-token');
        Object data;
        if (r.url.path.endsWith('categories')) {
          data = [categoryJson()];
        } else if (r.url.path.endsWith('favorite')) {
          data = {'placeId': marketPlaceId, 'isFavorite': r.method == 'PUT'};
        } else if (r.url.path.endsWith('rating')) {
          data = {
            'placeId': marketPlaceId,
            'myRating': r.method == 'PUT' ? 3 : null,
            'averageRating': r.method == 'PUT' ? 3 : 0,
            'ratingCount': r.method == 'PUT' ? 1 : 0,
          };
        } else if (r.url.path.endsWith('/$marketPlaceId')) {
          data = detailJson();
        } else {
          data = {
            'items': r.url.path.endsWith('posts')
                ? [postJson()]
                : [placeJson()],
            'pagination': paginationJson(),
          };
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
    addTearDown(service.close);
    final repo = ApiMarketplaceRepository(
      api: service,
      withSession: authenticated,
    );
    await repo.categories();
    await repo.places(search: 'coffee', category: 'fictional-coffee');
    await repo.place(marketPlaceId);
    await repo.posts(type: 'news', placeId: marketPlaceId);
    await repo.favorite(marketPlaceId, true);
    await repo.favorite(marketPlaceId, false);
    await repo.rating(marketPlaceId, 3);
    await repo.rating(marketPlaceId, null);
    expect(capabilities, 8);
    expect(requests, 8);
  });
  test(
    'backend 401 reaches ApiAuthRepository and invalidates the saved session',
    () async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('fiction', 'test');
      final service = MarketplaceApiService(
        baseUrl: Uri.parse('https://api.example.test'),
        client: MockClient(
          (_) async => failure('UNAUTHENTICATED', status: 401),
        ),
      );
      addTearDown(service.close);
      final repo = ApiMarketplaceRepository(
        api: service,
        withSession: auth.repository.withSession,
      );
      await expectLater(repo.categories(), throwsA(isA<AuthFailure>()));
      expect(auth.repository.status, SessionStatus.unauthenticated);
      expect(auth.store.session, isNull);
      expect(auth.store.deletes, 1);
    },
  );
  test('unexpected capability errors are safe and failed mutations are never retried', () async {
    var calls = 0;
    Future<T> broken<T>(Future<T> Function(String) _) async {
      calls++;
      throw StateError('private token');
    }

    final service = MarketplaceApiService(
      baseUrl: Uri.parse('https://api.example.test'),
      client: MockClient((_) async {
        fail('No network without capability');
      }),
    );
    addTearDown(service.close);
    final repo = ApiMarketplaceRepository(api: service, withSession: broken);
    await expectLater(
      repo.favorite(marketPlaceId, true),
      throwsA(
        isA<MarketplaceFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('private')),
        ),
      ),
    );
    expect(calls, 1);
  });
}

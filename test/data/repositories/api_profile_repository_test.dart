import 'dart:async';
import 'dart:convert';

import 'package:balamandian/data/repositories/api_profile_repository.dart';
import 'package:balamandian/data/services/profile_api_service.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';

void main() {
  test('public and owner contracts parse separately with immutable role and academic lists', () {
    final own = UserProfile.fromJson(profileJson());
    expect(own.account!.sisId, 'FICTION001');
    expect(own.account!.programs.single.name, 'Computer Science');
    final public = UserProfile.fromJson(profileJson(id: otherId, own: false));
    expect(public.account, isNull);
    expect(public.identity.username, 'maya.haddad');
    expect(() => own.identity.roles.add('fake'), throwsUnsupportedError);
    expect(() => UserProfile.fromJson({'id': ownId}), throwsFormatException);
    expect(
      () => UserProfile.fromJson({...profileJson(), 'followersCount': -1}),
      throwsFormatException,
    );
  });
  test('profile requests use the session boundary, correct origin and allowlisted bodies; cache prevents repeated reads', () async {
    final h = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(h.close);
    await h.repository.login('F', 'test');
    final calls = <http.Request>[];
    final service = ProfileApiService(
      client: MockClient((r) async {
        calls.add(r);
        return http.Response(jsonEncode({'data': profileJson()}), 200);
      }),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    addTearDown(service.close);
    final repo = ApiProfileRepository(
      api: service,
      withSession: h.repository.withSession,
    );
    addTearDown(repo.dispose);
    repo.bindSession(ownId, h.repository.user);
    await repo.loadOwn();
    await repo.loadOwn();
    expect(calls.length, 1);
    await repo.saveBiography('New biography');
    expect(calls.last.method, 'PATCH');
    expect(jsonDecode(calls.last.body), {'biography': 'New biography'});
    expect(calls.last.headers['authorization'], startsWith('Bearer '));
    expect(calls.last.url.origin, 'https://api.example.test');
    repo.bindSession(null, null);
    expect(repo.currentUser, isNull);
    expect(repo.cached(ownId), isNull);
  });
  test(
    'avatar references reject arbitrary origins before attaching authorization',
    () async {
      var calls = 0;
      final api = ProfileApiService(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
        baseUrl: Uri.parse('https://api.example.test'),
      );
      addTearDown(api.close);
      for (final value in [
        'https://attacker.example/avatar',
        '//attacker.example/avatar',
        '/api/v1/users/$ownId/avatar',
        '/api/v1/auth/me',
      ]) {
        await expectLater(api.avatar('private', value), throwsFormatException);
      }
      expect(calls, 0);
    },
  );
  test('transient hydration errors retain valid credentials; confirmed 401 uses existing invalidation', () async {
    final h = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(h.close);
    await h.repository.login('F', 'test');
    var invalid = false;
    final api = ProfileApiService(
      client: MockClient(
        (_) async => failure(
          invalid ? 'UNAUTHENTICATED' : 'PROFILE_UNAVAILABLE',
          status: invalid ? 401 : 503,
        ),
      ),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    addTearDown(api.close);
    final repo = ApiProfileRepository(
      api: api,
      withSession: h.repository.withSession,
    );
    addTearDown(repo.dispose);
    repo.bindSession(ownId, h.repository.user);
    await expectLater(repo.loadOwn(), throwsA(isA<ProfileFailure>()));
    expect(h.repository.status, SessionStatus.authenticated);
    expect(h.store.session, isNotNull);
    invalid = true;
    await expectLater(repo.loadOwn(refresh: true), throwsA(isA<AuthFailure>()));
    expect(h.repository.status, SessionStatus.unauthenticated);
    expect(h.store.session, isNull);
  });
  test('late requests cannot publish a previous session identity', () async {
    final pending = Completer<http.Response>();
    final api = ProfileApiService(
      client: MockClient((_) => pending.future),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    addTearDown(api.close);
    Future<T> withSession<T>(Future<T> Function(String) request) =>
        request('test');
    final repo = ApiProfileRepository(api: api, withSession: withSession);
    addTearDown(repo.dispose);
    repo.bindSession(ownId, Object());
    final request = repo.loadOwn();
    final rejected = expectLater(request, throwsA(isA<ProfileFailure>()));
    repo.bindSession(otherId, Object());
    pending.complete(http.Response(jsonEncode({'data': profileJson()}), 200));
    await rejected;
    expect(repo.currentUser, isNull);
    expect(repo.cached(ownId), isNull);
    expect(repo.error, isNull);
  });
}

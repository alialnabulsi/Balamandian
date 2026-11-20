import 'dart:convert';

import 'package:balamandian/data/repositories/api_profile_repository.dart';
import 'package:balamandian/data/services/profile_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../profile_test_support.dart';

void main() {
  test('following from a list retains the profile that is behind it', () async {
    const thirdId = '33333333-3333-4333-8333-333333333333';
    final api = ProfileApiService(
      client: MockClient((request) async {
        final path = request.url.path;
        final data = path.endsWith('/me')
            ? profileJson()
            : profileJson(
                id: path.contains(thirdId) ? thirdId : otherId,
                own: false,
              );
        return http.Response(jsonEncode({'data': data}), 200);
      }),
      baseUrl: Uri.parse('https://api.example.test'),
    );
    addTearDown(api.close);
    Future<T> session<T>(Future<T> Function(String) request) =>
        request('fiction');
    final repo = ApiProfileRepository(api: api, withSession: session);
    addTearDown(repo.dispose);
    repo.bindSession(ownId, Object());
    await repo.profile(otherId);
    await repo.follow(thirdId, true);
    expect(repo.cached(otherId)?.identity.id, otherId);
    expect(repo.cached(thirdId)?.identity.id, thirdId);
  });
}

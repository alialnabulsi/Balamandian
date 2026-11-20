import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:balamandian/ui/profile/view_models/user_profile_view_model.dart';
import 'package:balamandian/domain/models/profile_models.dart';

import '../../profile_network_support.dart';
import '../../profile_test_support.dart';

void main() {
  test(
    'pushed owner profile drops private data when the session changes directly',
    () async {
      final network = ProfileNetworkHarness();
      addTearDown(network.close);
      final model = UserProfileViewModel(
        repository: network.repository,
        userId: ownId,
      );
      addTearDown(model.dispose);
      await model.load();
      expect(model.profile!.account, isNotNull);
      network.repository.bindSession(otherId, Object());
      expect(model.profile, isNull);
    },
  );

  test(
    'identical concurrent member pages share one transport request',
    () async {
      final network = ProfileNetworkHarness();
      addTearDown(network.close);
      final gate = Completer<http.Response>();
      network.intercept = (_) => gate.future;
      final first = network.repository.members(kind: MemberListKind.discover);
      final second = network.repository.members(kind: MemberListKind.discover);
      await Future<void>.delayed(Duration.zero);
      expect(network.calls, hasLength(1));
      gate.complete(
        http.Response(
          jsonEncode({
            'data': {'items': [], 'page': 1, 'total': 0, 'hasMore': false},
          }),
          200,
        ),
      );
      await Future.wait([first, second]);
    },
  );
  test('public profile and avatar GETs coalesce and versioned avatars invalidate after removal', () async {
    final network = ProfileNetworkHarness();
    addTearDown(network.close);
    final profile = Completer<http.Response>();
    final avatar = Completer<http.Response>();
    network.intercept = (r) async => r.url.path.endsWith('/profile')
        ? profile.future
        : r.url.path.endsWith('/avatar') && r.method == 'GET'
        ? avatar.future
        : null;
    final one = network.repository.profile(otherId),
        two = network.repository.profile(otherId);
    const path = '/api/v1/users/$otherId/avatar?v=$ownId';
    final a = network.repository.avatar(path),
        b = network.repository.avatar(path);
    await Future<void>.delayed(Duration.zero);
    expect(network.calls, hasLength(2));
    profile.complete(
      http.Response(
        jsonEncode({'data': profileJson(id: otherId, own: false)}),
        200,
      ),
    );
    avatar.complete(
      http.Response.bytes(
        [1, 2, 3],
        200,
        headers: {'content-type': 'image/webp'},
      ),
    );
    await Future.wait([one, two, a, b]);
    await network.repository.avatar(path);
    expect(network.calls, hasLength(2));
    await network.repository.removeAvatar();
    await network.repository.avatar(path);
    expect(
      network.calls.where(
        (r) => r.method == 'GET' && r.url.path.endsWith('/avatar'),
      ),
      hasLength(2),
    );
  });

  test('late public GET cannot overwrite a newer follow result', () async {
    final network = ProfileNetworkHarness();
    addTearDown(network.close);
    final stale = Completer<http.Response>();
    network.intercept = (r) async =>
        r.url.path.endsWith('/profile') ? stale.future : null;
    final loading = network.repository.profile(otherId);
    await network.repository.follow(otherId, true);
    stale.complete(
      http.Response(
        jsonEncode({'data': profileJson(id: otherId, own: false)}),
        200,
      ),
    );
    await loading;
    expect(network.repository.cached(otherId)!.isFollowing, true);
    expect(network.repository.currentUser!.followingCount, 1);
  });
}

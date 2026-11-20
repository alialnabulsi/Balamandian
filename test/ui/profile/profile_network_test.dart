import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/loading/skeleton.dart';
import 'package:balamandian/ui/profile/view_models/edit_profile_view_model.dart';
import 'package:balamandian/ui/profile/view_models/member_list_view_model.dart';
import 'package:balamandian/ui/profile/view_models/user_profile_view_model.dart';
import 'package:balamandian/ui/profile/widgets/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../profile_network_support.dart';
import '../../profile_test_support.dart';

void main() {
  for (final ms in [0, 500, 1500, 3000, 8000]) {
    testWidgets(
      'profile resolves at ${ms}ms with delayed skeleton and truthful counts',
      (tester) async {
        final network = ProfileNetworkHarness()
          ..delay = Duration(milliseconds: ms);
        addTearDown(network.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: ProfileScreen(repository: network.repository),
          ),
        );
        await tester.pump();
        expect(find.byType(SkeletonGroup), findsNothing);
        expect(
          find.text('No posts yet'),
          ms == 0 ? findsOneWidget : findsNothing,
        );
        if (ms > 0) {
          await tester.pump(const Duration(milliseconds: 199));
          expect(find.byType(SkeletonGroup), findsNothing);
          await tester.pump(const Duration(milliseconds: 2));
          expect(find.byType(SkeletonGroup), findsOneWidget);
          expect(find.text('No members yet'), findsNothing);
          await tester.pump(Duration(milliseconds: ms));
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text('Ali Al Nabulsi'), findsOneWidget);
        expect(find.byType(SkeletonGroup), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'cached refresh remains visible through offline failure and recovery',
    (tester) async {
      final network = ProfileNetworkHarness();
      addTearDown(network.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ProfileScreen(repository: network.repository),
        ),
      );
      await tester.pumpAndSettle();
      network.delay = const Duration(seconds: 3);
      network.offline = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ali Al Nabulsi'), findsOneWidget);
      expect(find.byType(SkeletonGroup), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await refresh;
      await tester.pump();
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.text('Ali Al Nabulsi'), findsOneWidget);
      network.offline = false;
      network.delay = Duration.zero;
      final retry = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await retry;
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your connection'), findsNothing);
    },
  );

  testWidgets('initial failure gives retry, never a false empty state', (
    tester,
  ) async {
    final network = ProfileNetworkHarness()..fail = true;
    addTearDown(network.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ProfileScreen(repository: network.repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.text('No posts yet'), findsNothing);
    network.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Al Nabulsi'), findsOneWidget);
  });

  testWidgets('leaving an 8 second request disposes loading animation safely', (
    tester,
  ) async {
    final network = ProfileNetworkHarness()..delay = const Duration(seconds: 8);
    addTearDown(network.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ProfileScreen(repository: network.repository),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SkeletonGroup), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('service timeout exits loading and offers recovery', (
    tester,
  ) async {
    final network = ProfileNetworkHarness();
    final response = Completer<http.Response>();
    network.intercept = (_) => response.future;
    addTearDown(network.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ProfileScreen(repository: network.repository),
      ),
    );
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.byType(SkeletonGroup), findsNothing);
    response.complete(http.Response(jsonEncode({'data': profileJson()}), 200));
    await tester.pump();
    expect(find.text('Ali Al Nabulsi'), findsNothing);
  });

  test('pending follow blocks duplicates and confirmed failure preserves relationship', () async {
    final network = ProfileNetworkHarness();
    addTearDown(network.close);
    final model = UserProfileViewModel(
      repository: network.repository,
      userId: otherId,
    );
    addTearDown(model.dispose);
    await model.load();
    final gate = Completer<http.Response>();
    network.intercept = (r) async =>
        r.url.path.endsWith('/follow') ? gate.future : null;
    final follow = model.toggleFollow();
    await model.toggleFollow();
    expect(model.following, true);
    expect(model.profile!.isFollowing, false);
    gate.complete(http.Response('{"error":{"code":"NETWORK_ERROR"}}', 503));
    await follow;
    expect(model.following, false);
    expect(model.profile!.isFollowing, false);
    expect(model.error, isNotNull);
    expect(
      network.calls.where((r) => r.url.path.endsWith('/follow')).length,
      1,
    );
  });

  test(
    'partial save retries biography without reuploading confirmed photo',
    () async {
      final network = ProfileNetworkHarness();
      addTearDown(network.close);
      final model = EditProfileViewModel(repository: network.repository);
      addTearDown(model.dispose);
      await model.initialize();
      model.biography = 'Draft preserved';
      model.photo.preview = Uint8List.fromList([137, 80, 78, 71, 0, 0, 0, 0]);
      var failBio = true;
      network.intercept = (r) async {
        if (r.url.path.endsWith('/me/avatar')) {
          network.own = {
            ...network.own,
            'avatarPath': '/api/v1/users/$ownId/avatar?v=$otherId',
          };
          return http.Response(jsonEncode({'data': network.own}), 200);
        }
        if (r.method == 'PATCH' && failBio) {
          return http.Response('{"error":{"code":"NETWORK_ERROR"}}', 503);
        }
        return null;
      };
      expect(await model.save(), false);
      expect(model.biography, 'Draft preserved');
      expect(model.photo.preview, isNull);
      expect(model.error, contains('photo change was saved'));
      failBio = false;
      expect(await model.save(), true);
      expect(
        network.calls.where((r) => r.url.path.endsWith('/me/avatar')).length,
        1,
      );
      expect(network.repository.currentUser!.biography, 'Draft preserved');
    },
  );

  test(
    'failed avatar upload retains selected image and last persisted avatar',
    () async {
      final network = ProfileNetworkHarness();
      addTearDown(network.close);
      final model = EditProfileViewModel(repository: network.repository);
      addTearDown(model.dispose);
      await model.initialize();
      final draft = Uint8List.fromList([137, 80, 78, 71, 0, 0, 0, 0]);
      model.photo.preview = draft;
      network.fail = true;
      expect(await model.save(), false);
      expect(model.photo.preview, same(draft));
      expect(model.profile!.identity.avatarPath, isNull);
      expect(network.calls.where((r) => r.method == 'PATCH'), isEmpty);
    },
  );

  test(
    'member refresh retains rows and failed pagination is recoverable',
    () async {
      final repo = FakeProfileRepository()..moreMembers = true;
      addTearDown(repo.dispose);
      final model = MemberListViewModel(
        repository: repo,
        kind: MemberListKind.discover,
      );
      addTearDown(model.dispose);
      await model.load(refresh: true);
      final gate = Completer<MemberPage>();
      repo.memberRequest = (_, _) => gate.future;
      final request = model.load(refresh: true);
      expect(model.items, hasLength(1));
      gate.completeError(const ProfileFailure('NETWORK_ERROR', 'Offline'));
      await request;
      expect(model.items, hasLength(1));
      expect(model.error, 'Offline');
      repo.memberRequest = null;
      await model.load();
      expect(model.items, hasLength(1));
      expect(model.hasMore, false);
    },
  );

  test('logout clears rows and discards in-flight member results', () async {
    final network = ProfileNetworkHarness();
    addTearDown(network.close);
    final model = MemberListViewModel(
      repository: network.repository,
      kind: MemberListKind.discover,
    );
    addTearDown(model.dispose);
    await model.load(refresh: true);
    final gate = Completer<http.Response>();
    network.intercept = (_) => gate.future;
    final pending = model.load(refresh: true);
    network.repository.bindSession(null, null);
    expect(model.items, isEmpty);
    gate.complete(
      http.Response(
        jsonEncode({
          'data': {
            'items': [profileJson(id: otherId, own: false)],
            'page': 1,
            'total': 1,
            'hasMore': false,
          },
        }),
        200,
      ),
    );
    await pending;
    expect(model.items, isEmpty);
    expect(network.repository.currentUser, isNull);
  });
}

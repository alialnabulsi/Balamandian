import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/community_repository.dart';
import 'package:balamandian/data/services/community_api_service.dart';
import 'package:balamandian/ui/community/widgets/community_composer.dart';
import 'package:balamandian/ui/community/widgets/community_entry_screen.dart';
import 'package:balamandian/ui/community/widgets/community_post_card.dart';
import 'package:balamandian/ui/community/widgets/community_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../startup_test_support.dart';

const _postId = '33333333-3333-4333-8333-333333333333';
const _storyId = '44444444-4444-4444-8444-444444444444';
const _mediaId = '55555555-5555-4555-8555-555555555555';
const _secondMediaId = '66666666-6666-4666-8666-666666666666';

class _Fixture {
  _Fixture(this.photo);
  final Uint8List photo;
  bool liked = false, failLike = false, stories = true, multiplePhotos = false;
  bool offline = false;
  int likeRequests = 0;
  final feedModes = <String>[];
  Map<String, Object?> entry({bool story = false}) => {
    'id': story ? _storyId : _postId,
    'kind': story ? 'story' : 'post',
    'caption': story
        ? 'A quiet afternoon on campus'
        : 'A small campus moment worth keeping.',
    'author': profileJson(id: otherId, own: false),
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    'expiresAt': story
        ? DateTime.now().add(const Duration(hours: 12)).toIso8601String()
        : null,
    'media': [
      {'id': _mediaId, 'width': 1200, 'height': 850},
      if (!story && multiplePhotos)
        {'id': _secondMediaId, 'width': 750, 'height': 1100},
    ],
    'isOwn': false,
    'liked': liked,
    'saved': false,
    'seen': false,
    'likeCount': liked ? 5 : 4,
    'commentCount': 1,
    'canComment': true,
    'canLike': true,
  };
  http.Response json(Object data) =>
      http.Response(jsonEncode({'data': data}), 200);
  Future<http.Response> respond(http.Request request) async {
    final parts = request.url.pathSegments.skip(3).join('/');
    expect(request.headers['authorization'], startsWith('Bearer '));
    switch (parts) {
      case 'feed':
        if (offline) throw const SocketException('Fixture is offline');
        final mode = request.url.queryParameters['mode']!;
        feedModes.add(mode);
        return json({
          'items': mode == 'following' ? [] : [entry()],
          'next': null,
        });
      case 'stories':
        return json(stories ? [entry(story: true)] : []);
      case 'entries/$_postId':
        return json(entry());
      case 'entries/$_storyId':
        return json(entry(story: true));
      case 'media/$_mediaId' || 'media/$_secondMediaId':
        return http.Response.bytes(
          photo,
          200,
          headers: {'content-type': 'image/webp'},
        );
      case 'entries/$_postId/like':
        likeRequests++;
        if (failLike) {
          return http.Response('{"error":{"code":"MEDIA_UNAVAILABLE"}}', 503);
        }
        liked = request.method == 'PUT';
        return json({'ok': true});
      case 'entries/$_postId/comments':
        final reply = request.url.queryParameters['parent'] == 'one';
        return json({
          'items': [
            {
              'id': reply ? 'two' : 'one',
              'body': reply
                  ? 'We stopped to take photos too.'
                  : 'I love this corner of campus.',
              'author': profileJson(id: otherId, own: false),
              'isOwn': false,
              'liked': false,
              'likeCount': 0,
              'replyCount': reply ? 0 : 1,
              'createdAt': '2026-11-26T12:00:00Z',
            },
          ],
          'next': null,
        });
      case 'notifications' || 'notifications/sync':
        return json({
          'items': [],
          'next': null,
          'unread': 0,
          'revision': 'revision',
          'visibility': '0',
        });
      case 'settings':
        return json({
          'privateAccount': false,
          'storyAudience': 'followers',
          'storyLikes': true,
          'postComments': true,
          'notifyInteractions': true,
          'notifyRelationships': true,
        });
      case 'entries/$_postId/seen' || 'entries/$_storyId/seen':
        return json({'ok': true});
      default:
        fail('Unexpected community request $parts');
    }
  }
}

Future<_Fixture> _app(
  WidgetTester tester, {
  bool dark = false,
  Size size = const Size(390, 844),
  double scale = 1,
  bool stories = true,
  bool signedIn = true,
  bool multiplePhotos = false,
  String location = '/',
}) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  final auth = AuthTestHarness((_) async => success(sessionData(), 200));
  addTearDown(auth.close);
  if (signedIn) await auth.repository.login('FICTION001', 'fictional');
  final photo = await rootBundle.load(
    'assets/onboarding/images/onboarding-main-campus.png',
  );
  final fixture = _Fixture(photo.buffer.asUint8List())
    ..stories = stories
    ..multiplePhotos = multiplePhotos;
  final repo = CommunityRepository(
    CommunityApiService(
      MockClient(fixture.respond),
      Uri.parse('https://api.example.test'),
    ),
    auth.repository,
  );
  addTearDown(repo.dispose);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('community-capture'),
      child: MainApp(
        authRepository: auth.repository,
        profileRepository: FakeProfileRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        communityRepository: repo,
        onboardingRepository: testOnboardingRepository(completed: true),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        initialLocation: location,
      ),
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('community-capture')),
  );
  if (const bool.fromEnvironment('CAPTURE_UI')) {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final file = File('build/community-verification/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  }
}

void main() {
  setUpAll(loadHomeFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'community feed, creation and comment surfaces in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        final fixture = await _app(tester, dark: dark);
        final theme = dark ? 'dark' : 'light';
        expect(find.text('Campus moments'), findsOneWidget);
        expect(find.text('Maya Haddad'), findsWidgets);
        expect(find.text('For you'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        try {
          expect(find.bySemanticsLabel('Like post, 4'), findsOneWidget);
          expect(find.bySemanticsLabel('Comments, 1'), findsOneWidget);
        } finally {
          semantics.dispose();
        }
        await _capture(tester, 'feed-$theme');
        final like = find.byTooltip('Like post');
        await tester.ensureVisible(like);
        fixture.failLike = true;
        await tester.tap(like);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Like post'), findsOneWidget);
        expect(fixture.likeRequests, 1);
        fixture.failLike = false;
        await tester.tap(like);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Unlike post'), findsOneWidget);
        await tester.tap(find.byTooltip('Comments'));
        await tester.pumpAndSettle();
        expect(find.text('I love this corner of campus.'), findsOneWidget);
        await _capture(tester, 'comments-$theme');
        await tester.tap(find.byTooltip('Close comments'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Create post'), findsOneWidget);
        await _capture(tester, 'create-$theme');
        await tester.tap(find.text('Create story'));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityComposer), findsOneWidget);
        expect(find.text('Choose a story photo'), findsOneWidget);
        await _capture(tester, 'composer-$theme');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'two-times text, no other stories, Following and shared composer',
    (tester) async {
      final fixture = await _app(
        tester,
        size: const Size(320, 720),
        scale: 2,
        stories: false,
      );
      expect(find.text('Your story'), findsOneWidget);
      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(fixture.feedModes.last, 'following');
      expect(find.text('No posts from your circle yet'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(StoryTile),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommunityComposer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('signed-in shared post link resolves through startup', (
    tester,
  ) async {
    await _app(tester, location: '/posts/$_postId');
    expect(find.text('A small campus moment worth keeping.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('signed-out shared post link survives an interactive login', (
    tester,
  ) async {
    await _app(tester, location: '/posts/$_postId', signedIn: false);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'FICTION001');
    await tester.enterText(find.byType(TextField).last, 'fictional');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityEntryScreen), findsOneWidget);
    expect(find.text('A small campus moment worth keeping.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening a swiped carousel keeps the selected photo', (
    tester,
  ) async {
    await _app(tester, multiplePhotos: true);
    final gallery = find.byType(CommunityGallery);
    await tester.drag(gallery, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(gallery);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityEntryScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CommunityEntryScreen),
        matching: find.text('2/2'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reply navigation preserves drafts and fits a narrow keyboard', (
    tester,
  ) async {
    await _app(
      tester,
      size: const Size(320, 720),
      scale: 1.5,
      location: '/posts/$_postId',
    );
    await tester.tap(find.byTooltip('Comments'));
    await tester.pumpAndSettle();
    expect(find.text('View reply'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Root draft');
    await tester.pumpAndSettle();
    await tester.tap(find.text('View reply'));
    await tester.pumpAndSettle();
    expect(find.text('We stopped to take photos too.'), findsOneWidget);
    expect(find.text('Root draft'), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.enterText(find.byType(TextField), 'Reply draft');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back to all comments'));
    await tester.pumpAndSettle();
    expect(find.text('Root draft'), findsOneWidget);
    expect(find.text('Reply draft'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an offline feed refresh can recover through retry', (
    tester,
  ) async {
    final fixture = await _app(tester);
    fixture.offline = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('You’re offline'), findsOneWidget);
    fixture.offline = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('A small campus moment worth keeping.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

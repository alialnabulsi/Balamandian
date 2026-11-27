import 'dart:convert';

import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/community_repository.dart';
import 'package:balamandian/data/repositories/messaging_repository.dart';
import 'package:balamandian/data/services/community_api_service.dart';
import 'package:balamandian/ui/messaging/widgets/chat_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../startup_test_support.dart';

const threadId = 'b0000000-0000-4000-8000-000000000001';
const firstId = 'b0000000-0000-4000-8000-000000000002';

class MessagingFixture {
  MessagingFixture({this.pending = false, this.official = false});
  bool pending;
  final bool official;
  bool failSend = true;
  bool unavailable = false;
  final sends = <String>[];
  String? lastMessage;
  final date = DateTime.now().toIso8601String();

  Map<String, Object?> get thread => {
    'id': threadId,
    'kind': official ? 'channel' : 'direct',
    'title': official ? 'Computer Science' : '',
    'description': '',
    'peer': official ? null : profileJson(id: otherId, own: false),
    if (official) 'departmentName': 'Faculty of Science',
    'activityAt': date,
    'state': 'active',
    'role': 'member',
    'requestState': pending ? 'pending' : 'accepted',
    'initiated': false,
    'unread': 1,
    'memberCount': 2,
    'lastSeq': lastMessage == null ? '1' : '2',
    'readSeq': '0',
    'peerDelivered': '0',
    'peerRead': '0',
    for (final key in ['sendPolicy', 'invitePolicy', 'editPolicy', 'pinPolicy'])
      key: 'members',
    'latest': {'text': lastMessage ?? 'Meet at the library after class.'},
  };

  Map<String, Object?> message(String id, String body, bool own) => {
    'id': id,
    'seq': own ? '2' : '1',
    'senderId': own ? ownId : otherId,
    'sender': profileJson(id: own ? ownId : otherId, own: own),
    'body': body,
    'createdAt': date,
    'images': [],
    'reactions': [],
  };

  http.Response ok(Object? data) => http.Response(
    jsonEncode({'data': data}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> respond(http.Request request) async {
    final parts = request.url.pathSegments.skip(3).join('/');
    expect(request.headers['authorization'], startsWith('Bearer '));
    if (parts == 'sync') {
      return ok({
        'revision': unavailable ? 'unavailable' : 'revision',
        'version': 'revision',
        'visibility': '0',
        'threadVersion': '1',
        'unread': 1,
        'threadAvailable': !unavailable,
        'typing': [],
        'online': false,
      });
    }
    if (parts == 'conversations') {
      return ok({
        'items': [thread],
        'next': null,
      });
    }
    if (parts == 'academic/spaces') {
      return ok({
        'items': [
          if (request.url.queryParameters['kind'] == 'channel')
            {
              'id': threadId,
              'kind': 'channel',
              'title': 'Computer Science',
              'description': 'Official department news',
              'affiliation': 'Faculty of Science',
              'memberCount': 2,
              'joined': false,
              'canJoin': true,
            },
        ],
        'next': null,
      });
    }
    if (parts == 'academic/spaces/$threadId/join') return ok({'id': threadId});
    if (parts == 'academic/capabilities') return ok({'canCreateRoom': false});
    if (parts == 'conversations/$threadId/messages') {
      final announcement =
          request.url.queryParameters['section'] == 'announcement';
      return ok({
        'thread': thread,
        'items': [
          if (lastMessage != null) message(sends.last, lastMessage!, true),
          if (official && announcement)
            {
              ...message(firstId, 'Department tutorial this Thursday.', false),
              'section': 'announcement',
            }
          else
            message(firstId, 'Meet at the library after class.', false),
        ],
        'next': null,
      });
    }
    if (parts == 'conversations/$threadId/request') {
      pending = false;
      return ok({'ok': true});
    }
    if (parts == 'conversations/$threadId/ack' ||
        parts == 'conversations/$threadId/typing') {
      return ok({'ok': true});
    }
    if (parts.startsWith('conversations/$threadId/messages/')) {
      sends.add(request.url.pathSegments.last);
      if (failSend) return http.Response('{}', 503);
      lastMessage =
          (jsonDecode(utf8.decode(request.bodyBytes)) as Map)['text'] as String;
      return ok({'id': sends.last, 'seq': '2'});
    }
    if (parts == 'notifications' || parts == 'notifications/sync') {
      return ok({
        'items': [],
        'unread': 0,
        'next': null,
        'revision': 'none',
        'visibility': '0',
      });
    }
    fail('Unexpected fixture request $parts');
  }
}

Future<void> messagingApp(
  WidgetTester tester,
  MessagingFixture fixture,
  String path,
) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final auth = AuthTestHarness((_) async => success(sessionData(), 200));
  addTearDown(auth.close);
  await auth.repository.login('FICTION001', 'fixture');
  final origin = Uri.parse('https://api.example.test');
  final media = CommunityRepository(
    CommunityApiService(MockClient(fixture.respond), origin),
    auth.repository,
  );
  final messaging = MessagingRepository(
    CommunityApiService(MockClient(fixture.respond), origin, area: 'messaging'),
    auth.repository,
    media,
  );
  addTearDown(media.dispose);
  addTearDown(messaging.dispose);
  await tester.pumpWidget(
    MainApp(
      authRepository: auth.repository,
      profileRepository: FakeProfileRepository(),
      marketplaceRepository: FakeMarketplaceRepository(),
      communityRepository: media,
      messagingRepository: messaging,
      onboardingRepository: testOnboardingRepository(completed: true),
      initialLocation: path,
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'inbox opens a chat and a failed send retries the same operation',
    (tester) async {
      final fixture = MessagingFixture();
      await messagingApp(tester, fixture, '/messages');
      expect(find.text('Messages'), findsOneWidget);
      await tester.tap(find.text('Meet at the library after class.'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatThreadScreen), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'I’ll bring my camera.',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('I’ll bring my camera.'), findsOneWidget);
      expect(fixture.sends, hasLength(1));
      fixture.failSend = false;
      await tester.tap(find.byTooltip('Retry send'));
      await tester.pumpAndSettle();
      expect(fixture.sends, hasLength(2));
      expect(fixture.sends.first, fixture.sends.last);
      expect(find.text('I’ll bring my camera.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'accepting a request enables the composer and loss of access clears history',
    (tester) async {
      final fixture = MessagingFixture(pending: true);
      await messagingApp(tester, fixture, '/messages/$threadId');
      expect(find.byTooltip('Send message'), findsNothing);
      await tester.tap(find.text('Accept request'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsOneWidget);
      fixture.unavailable = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Conversation unavailable'), findsOneWidget);
      expect(find.text('Meet at the library after class.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'discover and join an official department with separate sections',
    (tester) async {
      await messagingApp(
        tester,
        MessagingFixture(official: true),
        '/messages/discover',
      );
      expect(find.text('Official channels'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join').last);
      await tester.pumpAndSettle();
      expect(find.text('Department tutorial this Thursday.'), findsOneWidget);
      expect(find.byTooltip('Publish announcement'), findsNothing);
      await tester.tap(find.text('Discussion'));
      await tester.pumpAndSettle();
      expect(find.text('Meet at the library after class.'), findsOneWidget);
      expect(find.text('Department tutorial this Thursday.'), findsNothing);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'dart:async';

import 'package:balamandian/data/services/external_url_service.dart';
import 'package:balamandian/domain/models/guide_models.dart';
import 'package:balamandian/ui/guide/view_models/guide_session.dart';
import 'package:balamandian/ui/guide/view_models/guide_bookmarks.dart';
import 'package:balamandian/ui/guide/view_models/guide_browse_view_models.dart';
import 'package:balamandian/ui/guide/view_models/guide_article_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../guide_test_support.dart';

class RecordingGuideUrls implements ExternalUrlService {
  final opened = <Uri>[];
  @override
  Future<bool> launch(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  late AuthTestHarness auth;
  late FakeGuideRepository repository;
  late GuideSession session;
  var accountId = '11111111-1111-4111-8111-111111111111';
  setUp(() async {
    accountId = '11111111-1111-4111-8111-111111111111';
    auth = AuthTestHarness((_) async {
      final payload = sessionData();
      payload['user'] = {
        ...payload['user']! as Map<String, Object>,
        'id': accountId,
      };
      return success(payload, 200);
    });
    await auth.repository.login('FICTION001', 'test');
    repository = FakeGuideRepository();
    session = GuideSession(auth: auth.repository, repository: repository);
  });
  tearDown(() {
    session.dispose();
    auth.close();
  });

  testWidgets(
    'home requests only roots; locale changes discard old responses',
    (tester) async {
      final old = Completer<List<GuideSection>>();
      repository.onSections = (locale) async =>
          locale == GuideLocale.en ? old.future : [];
      final model = GuideHomeViewModel(session);
      addTearDown(model.dispose);
      expect(model.loading, isTrue);
      expect(repository.rootCalls, 1);
      expect(repository.articleCalls, 0);
      expect(repository.bookmarkCalls, isEmpty);
      session.selectLocale(GuideLocale.ar);
      await tester.pump();
      expect(model.loading, isFalse);
      expect(model.sections, isEmpty);
      old.complete([GuideSection.fromJson(guideSectionJson())]);
      await tester.pump();
      expect(model.sections, isEmpty);
    },
  );

  testWidgets(
    'switching to a different account rejects old bookmark completion and clears search',
    (tester) async {
      final wait = Completer<void>();
      repository.onSave = (_) => wait.future;
      final old = session.bookmarks.setSaved(guideArticleId, true);
      final search = GuideSearchViewModel(session);
      addTearDown(search.dispose);
      search.setQuery('previous query');
      accountId = '22222222-2222-4222-8222-222222222222';
      await auth.repository.login('FICTION002', 'test');
      await tester.pump();
      expect(session.owner, accountId);
      expect(search.query, isEmpty);
      expect(session.bookmarks.pending(guideArticleId), isFalse);
      wait.complete();
      await old;
      expect(
        session.bookmarks.status(guideArticleId),
        GuideBookmarkStatus.unknown,
      );
    },
  );

  testWidgets(
    'hierarchy, deduplicated pagination and controlled invalid-cursor recovery',
    (tester) async {
      repository.onSection = (_, _, cursor) async {
        if (cursor != null) throw GuideFailure.fromCode('INVALID_REQUEST');
        return guideSectionDetail(
          child: true,
          page: GuidePage(
            items: [guideSummary(), guideSummary()],
            nextCursor: 'first-page',
          ),
        );
      };
      final model = GuideSectionViewModel(session, guideChildId);
      addTearDown(model.dispose);
      await tester.pump();
      expect(model.detail!.section.id, guideChildId);
      expect(model.detail!.breadcrumb.map((s) => s.id), [
        guideRootId,
        guideChildId,
      ]);
      expect(model.items.length, 1);
      final wait = Completer<GuideSectionDetail>();
      repository.onSection = (_, _, _) => wait.future;
      final first = model.load();
      final duplicate = model.load();
      expect(repository.sectionCalls.length, 2);
      wait.completeError(GuideFailure.fromCode('INVALID_REQUEST'));
      await first;
      await duplicate;
      expect(model.cursorExpired, isTrue);
      expect(model.nextCursor, isNull);
      expect(repository.sectionCalls.length, 2);
      repository.onSection = (_, _, cursor) async {
        expect(cursor, isNull);
        return guideSectionDetail(child: true);
      };
      await model.load(refresh: true);
      expect(model.cursorExpired, isFalse);
      expect(model.items.length, 1);
      await model.load();
      expect(
        repository.sectionCalls.length,
        3,
      ); // Null cursor terminates pagination.
    },
  );

  testWidgets(
    'search debounces 350ms and never displays an older query response',
    (tester) async {
      final old = Completer<GuidePage>();
      repository.onSearch = (q, _, _) async => q == 'older'
          ? old.future
          : GuidePage(items: [guideSummary(id: 'newer')]);
      final model = GuideSearchViewModel(session);
      addTearDown(model.dispose);
      model.setQuery('old');
      await tester.pump(const Duration(milliseconds: 200));
      model.setQuery('older');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repository.searchCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.searchCalls.single.$1, 'older');
      model.setQuery('التقويم');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(model.items.single.id, 'newer');
      old.complete(GuidePage(items: [guideSummary(id: 'old')]));
      await tester.pump();
      expect(model.items.single.id, 'newer');
      session.selectLocale(GuideLocale.ar);
      await tester.pump(const Duration(milliseconds: 350));
      expect(repository.searchCalls.last.$2, GuideLocale.ar);
      expect(repository.searchCalls.last.$3, isNull);
      model.setQuery('');
      await tester.pump(const Duration(milliseconds: 400));
      expect(model.items, isEmpty);
    },
  );

  testWidgets(
    'bookmark membership beyond first page remains unknown until found or exhausted',
    (tester) async {
      repository.onBookmarks = (cursor) async {
        final index = cursor == null ? 0 : int.parse(cursor);
        return GuidePage(
          items: [
            guideSummary(id: index == 3 ? guideArticleId : 'other-$index'),
          ],
          nextCursor: index == 3 ? null : '${index + 1}',
        );
      };
      final books = session.bookmarks;
      await books.check(guideArticleId);
      expect(repository.bookmarkCalls, [null, '1', '2']);
      expect(books.status(guideArticleId), GuideBookmarkStatus.unknown);
      await books.check(guideArticleId);
      expect(repository.bookmarkCalls.last, '3');
      expect(books.status(guideArticleId), GuideBookmarkStatus.saved);
      expect(books.status('absent'), GuideBookmarkStatus.unsaved);
    },
  );

  testWidgets(
    'bookmark failures and duplicate concurrent mutations retain confirmed state',
    (tester) async {
      final books = session.bookmarks;
      final save = Completer<void>();
      repository.onSave = (_) => save.future;
      final first = books.setSaved(guideArticleId, true);
      await books.setSaved(guideArticleId, true);
      expect(repository.saveCalls, 1);
      expect(books.pending(guideArticleId), isTrue);
      save.complete();
      await first;
      expect(books.status(guideArticleId), GuideBookmarkStatus.saved);
      repository.onRemove = (_) async => throw GuideFailure.network;
      await books.setSaved(guideArticleId, false);
      expect(books.status(guideArticleId), GuideBookmarkStatus.saved);
      expect(books.error(guideArticleId), isNotNull);
      expect(books.pending(guideArticleId), isFalse);
      repository.onRemove = (_) async {};
      await books.setSaved(guideArticleId, false);
      expect(books.status(guideArticleId), GuideBookmarkStatus.unsaved);
      expect(books.error(guideArticleId), isNull);
    },
  );

  testWidgets(
    'invalid membership cursor offers retry without marking absent as unsaved',
    (tester) async {
      repository.onBookmarks = (cursor) async {
        if (cursor != null) throw GuideFailure.fromCode('INVALID_REQUEST');
        return GuidePage(
          items: [guideSummary(id: 'other')],
          nextCursor: 'old-server',
        );
      };
      await session.bookmarks.check(guideArticleId);
      expect(
        session.bookmarks.status(guideArticleId),
        GuideBookmarkStatus.unknown,
      );
      expect(session.bookmarks.error(guideArticleId), isNotNull);
      repository.onBookmarks = (cursor) async {
        expect(cursor, isNull);
        return const GuidePage(items: []);
      };
      await session.bookmarks.check(guideArticleId);
      expect(
        session.bookmarks.status(guideArticleId),
        GuideBookmarkStatus.unsaved,
      );
    },
  );

  testWidgets(
    'saved list observes membership and reloads after confirmed removal',
    (tester) async {
      var saved = true;
      repository.onBookmarks = (_) async =>
          GuidePage(items: saved ? [guideSummary()] : []);
      repository.onRemove = (_) async {
        saved = false;
      };
      final model = GuideSavedViewModel(session);
      addTearDown(model.dispose);
      await tester.pump();
      expect(model.items.single.id, guideArticleId);
      expect(
        session.bookmarks.status(guideArticleId),
        GuideBookmarkStatus.saved,
      );
      await session.bookmarks.setSaved(guideArticleId, false);
      await tester.pump();
      expect(model.items, isEmpty);
    },
  );

  testWidgets(
    'logout and account replacement clear membership and reject late article work',
    (tester) async {
      await session.bookmarks.setSaved(guideArticleId, true);
      final old = Completer<GuideArticle>();
      repository.onArticle = (_) => old.future;
      final model = GuideArticleViewModel(
        session,
        guideArticleId,
        externalUrls: RecordingGuideUrls(),
      );
      addTearDown(model.dispose);
      await auth.repository.logout(localOnly: true);
      await tester.pump();
      expect(session.owner, isNull);
      expect(model.article, isNull);
      expect(model.loading, isFalse);
      expect(
        session.bookmarks.status(guideArticleId),
        GuideBookmarkStatus.unknown,
      );
      old.complete(GuideArticle.fromJson(guideArticleJson()));
      await tester.pump();
      expect(model.article, isNull);
      await auth.repository.login('FICTION002', 'test');
      await tester.pump();
      expect(
        session.bookmarks.status(guideArticleId),
        isNot(GuideBookmarkStatus.saved),
      );
    },
  );

  testWidgets(
    'article refetch, cited revision notice, unavailable state and URL scheme guard',
    (tester) async {
      final urls = RecordingGuideUrls();
      final model = GuideArticleViewModel(
        session,
        guideArticleId,
        citedVersion: 2,
        externalUrls: urls,
      );
      addTearDown(model.dispose);
      await tester.pump();
      expect(model.revisionChanged, isTrue);
      await model.openLink('javascript:alert(1)');
      await model.openLink('tel:+000');
      await model.openLink('https://name:password@example.test/');
      expect(urls.opened, isEmpty);
      expect(model.linkError, isNotNull);
      await model.openLink('https://www.balamand.edu.lb/');
      expect(urls.opened.single.host, 'www.balamand.edu.lb');
      expect(model.linkError, isNull);
      await model.load();
      expect(repository.articleCalls, 2);
      repository.onArticle = (_) async =>
          throw GuideFailure.fromCode('ARTICLE_NOT_FOUND');
      await model.load();
      expect(model.article, isNull);
      expect(model.error, contains('unavailable'));
    },
  );

  testWidgets('disposed models ignore later results and pending debounce', (
    tester,
  ) async {
    final old = Completer<List<GuideSection>>();
    repository.onSections = (_) => old.future;
    final home = GuideHomeViewModel(session);
    home.dispose();
    old.complete([GuideSection.fromJson(guideSectionJson())]);
    await tester.pump();
    final search = GuideSearchViewModel(session);
    search.setQuery('calendar');
    search.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.searchCalls, isEmpty);
  });
}

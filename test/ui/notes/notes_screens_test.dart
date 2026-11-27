import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/note_models.dart';
import 'package:balamandian/ui/notes/widgets/notes_browser_screen.dart';
import 'package:balamandian/ui/notes/widgets/note_editor_screen.dart';
import 'package:balamandian/ui/notes/widgets/note_text_block.dart';
import 'package:balamandian/ui/notes/widgets/note_drawing_canvas.dart';
import 'package:balamandian/ui/notes/widgets/note_drawing_editor.dart';
import 'package:balamandian/ui/notes/widgets/notes_dialogs.dart';
import 'package:balamandian/ui/core/ui/quick_actions/expandable_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../task_test_support.dart';
import '../../academic_test_support.dart';
import '../../notes_test_support.dart';
import '../startup_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../tools/tools_hub_view_model_test.dart' show setRoles;
import '../tools/tools_screen_test.dart' show captureTools;

Future<(AuthTestHarness, FakeNotesRepository, MemoryNoteDrafts)> pumpNotes(
  WidgetTester tester, {
  String location = '/tools/notes',
  bool guest = false,
  List<String> roles = const ['student'],
  Size size = const Size(412, 915),
  double scale = 1,
  bool dark = false,
}) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final auth = AuthTestHarness((_) async => success(sessionData(), 200));
  addTearDown(auth.close);
  if (!guest) await auth.repository.login('FIRST', 'test');
  final profiles = FakeProfileRepository();
  setRoles(profiles, roles);
  addTearDown(profiles.dispose);
  final repo = FakeNotesRepository(), drafts = MemoryNoteDrafts();
  await tester.pumpWidget(
    RepaintBoundary(
      child: MainApp(
        authRepository: auth.repository,
        profileRepository: profiles,
        notesRepository: repo,
        noteDrafts: drafts,
        noteFiles: FakeNoteFiles(),
        taskRepository: FakeTaskRepository(),
        academicRepository: FakeAcademicRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        onboardingRepository: testOnboardingRepository(completed: true),
        initialLocation: location,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
  return (auth, repo, drafts);
}

Finder paragraph() => find.descendant(
  of: find.byType(NoteTextBlock).first,
  matching: find.byType(TextField),
);
Future<void> reveal(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: .3);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadHomeFonts);
  testWidgets('new note is directly writable and Save returns to the browser', (
    tester,
  ) async {
    final (_, repo, _) = await pumpNotes(tester);
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditorScreen), findsOneWidget);
    expect(find.byType(NoteTextBlock), findsOneWidget);
    expect(tester.widget<TextField>(paragraph()).controller!.text, isEmpty);
    await tester.enterText(paragraph(), 'Write immediately on the blank page');
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesBrowserScreen), findsOneWidget);
    expect(
      repo.data.values.any(
        (n) =>
            n.document?.blocks.any(
              (b) => b.text == 'Write immediately on the blank page',
            ) ??
            false,
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Tools shortcut opens private notes and nested Back returns through folder browser',
    (tester) async {
      await pumpNotes(tester, location: '/tools');
      await tester.tap(find.text('My Notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowserScreen), findsOneWidget);
      await tester.tap(find.text('Classes'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Playground'), findsOneWidget);
      await tester.tap(find.text('Lecture notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.byType(ExpandableQuickActions), findsNothing);
      await tester.tap(find.byTooltip('Back to My Notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowserScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'editor saves formatting, retains failed input and guards leaving with local recovery',
    (tester) async {
      final (_, repo, drafts) = await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
      );
      repo.saveFailure = NotesFailure.fromCode(null);
      await tester.enterText(paragraph(), 'My private paragraph');
      await tester.tap(find.byTooltip('Bold paragraph'));
      await tester.tap(find.byTooltip('Save note'));
      await tester.pumpAndSettle();
      expect(find.text('My private paragraph'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to My Notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesLeaveDialog), findsOneWidget);
      await tester.tap(find.text('Keep local draft & leave'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowserScreen), findsOneWidget);
      expect(
        (await drafts.read(ownId, noteId))!.document.blocks.first.bold,
        isTrue,
      );
      repo.saveFailure = null;
      await tester.tap(find.text('Lecture notes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Recovered local draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Save note'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowserScreen), findsOneWidget);
      expect(
        repo.data[noteId]!.document!.blocks.first.text,
        'My private paragraph',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'contained handwriting draws, erases, undoes and persists editable strokes on insert',
    (tester) async {
      final (_, repo, _) = await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
      );
      final toolbar = find.byType(SingleChildScrollView).first;
      await tester.drag(toolbar, const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Insert drawing'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteDrawingEditor), findsOneWidget);
      final canvas = find.descendant(
        of: find.byType(NoteDrawingEditor),
        matching: find.byType(NoteDrawingCanvas),
      );
      final rect = tester.getRect(canvas);
      final gesture = await tester.startGesture(
        rect.center - const Offset(40, 20),
      );
      await gesture.moveBy(const Offset(80, 40));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Insert drawing').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save note'));
      await tester.pumpAndSettle();
      expect(repo.data[noteId]!.document!.blocks.last.type, 'drawing');
      expect(repo.data[noteId]!.document!.blocks.last.strokes, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'new folder, global title search with path, and permanent Playground actions',
    (tester) async {
      final (_, repo, _) = await pumpNotes(tester);
      await tester.tap(find.text('New folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Projects');
      await tester.tap(find.text('Save folder'));
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
      repo.data[noteId] = noteFixture(title: 'Nested Topic', folder: folderId);
      await tester.enterText(find.byType(TextField).first, 'nEsTeD');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Nested Topic'), findsOneWidget);
      expect(find.textContaining('Classes ·'), findsOneWidget);
      expect(find.byTooltip('Actions for folder Playground'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final (guest, roles) in [
    (true, <String>[]),
    (false, ['staff']),
    (false, ['advisor']),
    (false, ['student', 'advisor']),
  ]) {
    testWidgets('direct editor access guest=$guest roles=$roles', (
      tester,
    ) async {
      final (_, repo, _) = await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
        guest: guest,
        roles: roles,
      );
      final allowed = roles.contains('student') || roles.contains('advisor');
      expect(
        find.byType(NoteTextBlock),
        allowed ? findsOneWidget : findsNothing,
      );
      expect(repo.reads, allowed ? 1 : 0);
      if (guest) {
        expect(find.byType(CredentialsScreen), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final size in [const Size(280, 640), const Size(915, 412)]) {
    testWidgets('editor keyboard and dark enlarged layout at $size', (
      tester,
    ) async {
      await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
        size: size,
        scale: 2,
        dark: true,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await reveal(tester, paragraph());
      await tester.enterText(paragraph(), 'Longer text with a keyboard');
      await tester.pumpAndSettle();
      expect(find.text('Longer text with a keyboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'logout hides active private editor and account-scoped modal contents',
    (tester) async {
      final (auth, _, _) = await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
      );
      await tester.enterText(paragraph(), 'Secret');
      await tester.tap(find.byTooltip('Back to My Notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesLeaveDialog), findsOneWidget);
      await auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      expect(find.text('Secret'), findsNothing);
      expect(find.byType(NotesLeaveDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'direct route changes respect unsaved draft guard and Stay keeps editing',
    (tester) async {
      final (_, repo, _) = await pumpNotes(
        tester,
        location: '/tools/notes/$noteId',
      );
      repo.saveFailure = NotesFailure.fromCode(null);
      await tester.enterText(paragraph(), 'Keep this content');
      final router = GoRouter.of(tester.element(find.byType(NoteEditorScreen)));
      router.go('/tools');
      await tester.pumpAndSettle();
      expect(find.byType(NotesLeaveDialog), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.text('Keep this content'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final size in [const Size(280, 640), const Size(915, 412)]) {
    testWidgets('folder browser supports enlarged dark layout at $size', (
      tester,
    ) async {
      await pumpNotes(tester, size: size, scale: 2, dark: true);
      await reveal(tester, find.text('Lecture notes'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'phone browser and editor screenshots, accessible touch targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpNotes(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await captureTools(tester, 'notes-browser-phone', const Size(412, 915));
      final router = GoRouter.of(
        tester.element(find.byType(NotesBrowserScreen)),
      );
      router.go('/tools/notes/$noteId');
      await tester.pumpAndSettle();
      await captureTools(tester, 'notes-editor-phone', const Size(412, 915));
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

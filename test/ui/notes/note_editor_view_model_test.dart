import 'dart:async';
import 'dart:typed_data';

import 'package:balamandian/domain/models/note_models.dart';
import 'package:balamandian/ui/notes/view_models/note_editor_view_model.dart';
import 'package:balamandian/ui/notes/view_models/notes_browser_view_model.dart';
import 'package:balamandian/ui/notes/view_models/notes_session.dart';
import 'package:balamandian/ui/notes/view_models/drawing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../notes_test_support.dart';
import '../tools/tools_hub_view_model_test.dart' show setRoles;

void main() {
  Future<
    (
      AuthTestHarness,
      FakeProfileRepository,
      FakeNotesRepository,
      MemoryNoteDrafts,
      FakeNoteFiles,
      NotesSession,
      NoteEditorViewModel,
    )
  >
  setup({
    List<String> roles = const ['student'],
    Duration debounce = const Duration(hours: 1),
  }) async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FICTION', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, roles);
    await profiles.loadOwn();
    final repo = FakeNotesRepository(),
        drafts = MemoryNoteDrafts(),
        files = FakeNoteFiles();
    final session = NotesSession(
      auth: auth.repository,
      profiles: profiles,
      repository: repo,
    );
    addTearDown(session.dispose);
    final model = NoteEditorViewModel(
      noteId: noteId,
      session: session,
      repository: repo,
      drafts: drafts,
      files: files,
      debounce: debounce,
    );
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    return (auth, profiles, repo, drafts, files, session, model);
  }

  test('formatting and normalized drawing serialize, save, reopen with acknowledgments only', () async {
    final (_, _, repo, drafts, _, session, m) = await setup();
    m.select(m.document.blocks.first.id);
    m.format(type: 'heading', mark: 'bold');
    m.format(mark: 'italic');
    m.format(mark: 'underline');
    m.addDrawing([
      const InkStroke(
        color: 3,
        width: .008,
        points: [InkPoint(.25, .75), InkPoint(1, 0)],
      ),
    ]);
    expect(m.saveStatus, 'Unsaved changes');
    expect(await m.save(), isTrue);
    expect(m.saveStatus, 'Saved');
    expect(await drafts.read(ownId, noteId), isNull);
    final fresh = NoteEditorViewModel(
      noteId: noteId,
      session: session,
      repository: repo,
      drafts: drafts,
      files: FakeNoteFiles(),
    );
    addTearDown(fresh.dispose);
    await Future<void>.delayed(Duration.zero);
    final text = fresh.document.blocks.first;
    expect(text.type, 'heading');
    expect(text.bold && text.italic && text.underline, isTrue);
    expect(fresh.document.blocks.last.strokes.single.points.first.x, .25);
  });
  test(
    'late save never overwrites newer typing and saves serialize revisions',
    () async {
      final (_, _, repo, _, _, _, m) = await setup();
      m.setTitle('First');
      final reply = Completer<void>();
      repo.saveWait = reply.future;
      final saving = m.save();
      await Future<void>.delayed(Duration.zero);
      m.setTitle('Newer edit');
      expect(await m.save(), isFalse);
      expect(repo.saves, 1);
      reply.complete();
      await saving;
      expect(m.title, 'Newer edit');
      expect(m.dirty, isTrue);
      expect(m.revision, 2);
      repo.saveWait = null;
      expect(await m.save(), isTrue);
      expect(repo.data[noteId]!.title, 'Newer edit');
      expect(repo.saves, 2);
    },
  );
  test('debounced autosave consolidates edits', () async {
    final (_, _, repo, _, _, _, m) = await setup(
      debounce: const Duration(milliseconds: 20),
    );
    m.setTitle('A');
    m.setTitle('B');
    m.setTitle('Final');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(repo.saves, 1);
    expect(m.saveStatus, 'Saved');
  });
  test('failed save preserves private recoverable draft; reopened conflict requires explicit rebase', () async {
    final (_, _, repo, drafts, _, session, m) = await setup();
    m.setTitle('Private draft');
    repo.saveFailure = NotesFailure.fromCode(null);
    expect(await m.save(), isFalse);
    expect((await drafts.read(ownId, noteId))!.title, 'Private draft');
    repo.saveFailure = null;
    repo.data[noteId] = noteFixture(revision: 2, title: 'Other device');
    final fresh = NoteEditorViewModel(
      noteId: noteId,
      session: session,
      repository: repo,
      drafts: drafts,
      files: FakeNoteFiles(),
    );
    addTearDown(fresh.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(fresh.recovered, isTrue);
    expect(fresh.conflict, isTrue);
    expect(fresh.title, 'Private draft');
    expect(await fresh.save(), isFalse);
    await fresh.rebase();
    expect(await fresh.save(), isTrue);
    expect(repo.data[noteId]!.revision, 3);
  });
  test(
    'server conflict preserves content and blocks automatic resubmission',
    () async {
      final (_, _, repo, drafts, _, _, m) = await setup();
      m.setTitle('Keep me');
      repo.saveFailure = NotesFailure.fromCode('NOTE_CONFLICT');
      expect(await m.save(), isFalse);
      expect(m.conflict, isTrue);
      expect(m.title, 'Keep me');
      expect((await drafts.read(ownId, noteId))!.title, 'Keep me');
    },
  );
  test('attachment failure/retry keeps local file and references survive text edits', () async {
    final (_, _, repo, drafts, files, _, m) = await setup();
    files.picked = PickedNoteFile(
      'lecture.pdf',
      'application/pdf',
      Uint8List.fromList([1, 2, 3]),
    );
    repo.uploadFailure = NotesFailure.fromCode(null);
    await m.pickAttachment();
    final b = m.document.blocks.last;
    expect(b.localId, isNotNull);
    expect(b.attachmentId, isNull);
    expect(drafts.storedFiles, isNotEmpty);
    expect(m.uploadErrors[b.id], isNotNull);
    expect(await m.save(), isFalse);
    repo.uploadFailure = null;
    await m.upload(b);
    m.setTitle('Updated title');
    expect(m.document.blocks.last.attachmentId, isNotNull);
    expect(await m.save(), isTrue);
    expect(repo.data[noteId]!.document!.blocks.last.attachmentId, isNotNull);
    expect(repo.data[noteId]!.document!.blocks.last.localId, isNull);
    expect(drafts.storedFiles, isEmpty);
  });
  test('deleting during pending save cannot recreate deleted note', () async {
    final (_, _, repo, drafts, _, _, m) = await setup();
    m.setTitle('Pending');
    final reply = Completer<void>();
    repo.saveWait = reply.future;
    final saving = m.save();
    await Future<void>.delayed(Duration.zero);
    expect(await m.delete(), isTrue);
    reply.complete();
    await saving;
    expect(repo.data.containsKey(noteId), isFalse);
    expect(m.deleted, isTrue);
    expect(await drafts.read(ownId, noteId), isNull);
  });
  test('account change clears visible private state and ignores late note responses', () async {
    final (auth, _, repo, _, _, _, m) = await setup();
    final reply = Completer<void>();
    repo.readWait = reply.future;
    final loading = m.load();
    await auth.repository.logout(localOnly: true);
    expect(m.title, isEmpty);
    expect(m.document.blocks, isEmpty);
    reply.complete();
    await loading;
    expect(m.loaded, isFalse);
    expect(m.title, isEmpty);
  });
  for (final roles in [
    ['student'],
    ['advisor'],
    ['staff', 'advisor'],
    ['staff'],
    ['instructor'],
  ]) {
    test('eligible notes access $roles', () async {
      final (_, _, repo, _, _, session, m) = await setup(roles: roles);
      final eligible = roles.contains('student') || roles.contains('advisor');
      expect(m.canEdit, eligible);
      expect(
        session.access,
        eligible ? NotesAccess.eligible : NotesAccess.ineligible,
      );
      expect(repo.reads, eligible ? 1 : 0);
    });
  }
  test('drawing eraser, undo/redo and normalized stroke editing', () {
    final d = DrawingViewModel([]);
    addTearDown(d.dispose);
    d.start(const InkPoint(.1, .1));
    d.point(const InkPoint(.9, .9));
    d.end();
    expect(d.strokes.length, 1);
    d.pen(erase: true);
    d.start(const InkPoint(.5, .5));
    d.end();
    expect(d.strokes, isEmpty);
    d.undo();
    expect(d.strokes.length, 1);
    d.redo();
    expect(d.strokes, isEmpty);
  });
  test('unfinished contained drawing is recoverable locally and cancel restores original document', () async {
    final (_, _, repo, drafts, _, _, m) = await setup();
    final original = m.document.toJson();
    final block = m.beginDrawing(null);
    expect(block, isNotNull);
    m.stageDrawing([
      const InkStroke(
        color: 1,
        width: .008,
        points: [InkPoint(.1, .3), InkPoint(.2, .4)],
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(
      (await drafts.read(
        ownId,
        noteId,
      ))!.document.blocks.last.strokes.single.points.length,
      2,
    );
    expect(await m.save(), isFalse);
    expect(repo.saves, 0);
    m.endDrawing(keep: false);
    expect(m.document.toJson(), original);
  });
  test('browser global search has paths, hierarchy back, and recovered drafts never leak after account change', () async {
    final (auth, _, repo, drafts, _, session, _) = await setup();
    final m = NotesBrowserViewModel(
      session: session,
      repository: repo,
      drafts: drafts,
    );
    addTearDown(m.dispose);
    await Future<void>.delayed(Duration.zero);
    m.enter(folderId);
    await m.refresh();
    expect(m.path(folderId), 'Classes');
    expect(m.back(), isTrue);
    expect(m.folderId, isNull);
    await drafts.write(
      ownId,
      NoteDraft(
        noteId: noteId,
        title: 'Private',
        folderId: playgroundId,
        revision: 1,
        document: NoteDocument([]),
      ),
    );
    final wait = Completer<void>();
    drafts.listWait = wait.future;
    final loading = m.refresh();
    await Future<void>.delayed(Duration.zero);
    await auth.repository.logout(localOnly: true);
    wait.complete();
    await loading;
    expect(m.recovered, isEmpty);
    expect(m.notes, isEmpty);
  });
}

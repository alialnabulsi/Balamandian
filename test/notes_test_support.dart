import 'dart:convert';
import 'dart:typed_data';

import 'package:balamandian/data/repositories/notes_repository.dart';
import 'package:balamandian/data/services/note_draft_store.dart';
import 'package:balamandian/data/services/note_file_service.dart';
import 'package:balamandian/domain/models/note_models.dart';

const noteId = '33333333-3333-4333-8333-333333333333';
const playgroundId = '44444444-4444-4444-8444-444444444444';
const folderId = '55555555-5555-4555-8555-555555555555';
PersonalNote noteFixture({
  String id = noteId,
  String title = 'Lecture notes',
  int revision = 1,
  NoteDocument? document,
  String folder = playgroundId,
  List<NoteAttachment> attachments = const [],
}) => PersonalNote(
  id: id,
  folderId: folder,
  title: title,
  revision: revision,
  updatedAt: DateTime.utc(2026, 11, 25),
  document:
      document ?? NoteDocument([NoteBlock(id: 'a' * 32, text: 'Start here')]),
  attachments: attachments,
);

class FakeNotesRepository implements NotesRepository {
  final data = <String, PersonalNote>{noteId: noteFixture()};
  List<NoteFolder> folderData = [
    const NoteFolder(playgroundId, null, 'Playground', true),
    const NoteFolder(folderId, null, 'Classes', false),
  ];
  Object? failure, saveFailure, uploadFailure;
  Future<void>? saveWait, readWait;
  int saves = 0, reads = 0, uploads = 0, cancels = 0, deletes = 0, lists = 0;
  @override
  Future<List<NoteFolder>> folders() async {
    if (failure != null) throw failure!;
    return List.of(folderData);
  }

  @override
  Future<List<PersonalNote>> list({
    String? folderId,
    String search = '',
  }) async {
    lists++;
    if (failure != null) throw failure!;
    return data.values
        .where(
          (n) => search.isNotEmpty
              ? n.title.toLowerCase().contains(search.toLowerCase())
              : n.folderId == (folderId ?? playgroundId),
        )
        .toList();
  }

  @override
  Future<PersonalNote> read(String id) async {
    reads++;
    if (readWait != null) await readWait;
    if (failure != null) throw failure!;
    return data[id] ?? (throw NotesFailure.fromCode('NOTE_NOT_FOUND'));
  }

  @override
  Future<PersonalNote> create({String? folderId}) async {
    if (failure != null) throw failure!;
    final id =
        '${(data.length + 1).toString().padLeft(8, '0')}-1111-4111-8111-111111111111';
    return data[id] = noteFixture(
      id: id,
      title: 'Untitled note',
      folder: folderId ?? playgroundId,
      document: NoteDocument([]),
    );
  }

  @override
  Future<PersonalNote> save(String id, NoteDraft draft) async {
    saves++;
    if (saveWait != null) await saveWait;
    if (saveFailure != null) throw saveFailure!;
    final old = data[id];
    if (old == null) throw NotesFailure.fromCode('NOTE_NOT_FOUND');
    if (old.revision != draft.revision) {
      throw NotesFailure.fromCode('NOTE_CONFLICT');
    }
    return data[id] = noteFixture(
      id: id,
      title: draft.title.trim().isEmpty ? 'Untitled note' : draft.title,
      folder: draft.folderId,
      revision: old.revision + 1,
      document: NoteDocument.fromJson(
        jsonDecode(jsonEncode(draft.document.toServerJson())),
      ),
      attachments: old.attachments,
    );
  }

  @override
  Future<void> delete(String id, int revision) async {
    deletes++;
    if (data[id]?.revision != revision) {
      throw NotesFailure.fromCode('NOTE_CONFLICT');
    }
    data.remove(id);
  }

  @override
  Future<NoteFolder> saveFolder({
    String? id,
    required String name,
    String? parentId,
  }) async {
    final f = NoteFolder(
      id ?? '66666666-6666-4666-8666-666666666666',
      parentId,
      name,
      false,
    );
    folderData = [...folderData.where((x) => x.id != f.id), f];
    return f;
  }

  @override
  Future<void> deleteFolder(String id) async {
    folderData = folderData.where((f) => f.id != id).toList();
  }

  @override
  Future<NoteAttachment> upload(
    String noteId,
    String key,
    PickedNoteFile file,
    void Function(double) progress,
  ) async {
    uploads++;
    progress(.5);
    if (uploadFailure != null) throw uploadFailure!;
    progress(1);
    final a = NoteAttachment(
      '77777777-7777-4777-8777-777777777777',
      file.name,
      file.type,
      file.bytes.length,
    );
    final old = data[noteId]!;
    data[noteId] = noteFixture(
      id: old.id,
      title: old.title,
      revision: old.revision,
      document: old.document,
      folder: old.folderId,
      attachments: [a],
    );
    return a;
  }

  @override
  Future<Uint8List> download(String noteId, String attachmentId) async =>
      Uint8List.fromList([1, 2, 3]);
  @override
  Future<void> removeAttachment(String noteId, String attachmentId) async {}
  @override
  void cancelPending() {
    cancels++;
  }
}

class MemoryNoteDrafts implements NoteDraftStore {
  final data = <String, NoteDraft>{};
  final storedFiles = <String, PickedNoteFile>{};
  bool fail = false;
  Future<void>? listWait;
  @override
  Future<void> write(String owner, NoteDraft draft) async {
    if (fail) throw StateError('disk full');
    data['$owner:${draft.noteId}'] = NoteDraft.fromJson(
      jsonDecode(jsonEncode(draft.toJson())),
    );
  }

  @override
  Future<NoteDraft?> read(String owner, String note) async =>
      data['$owner:$note'];
  @override
  Future<List<NoteDraft>> list(String owner) async {
    final result = data.entries
        .where((e) => e.key.startsWith('$owner:'))
        .map((e) => e.value)
        .toList();
    if (listWait != null) await listWait;
    return result;
  }

  @override
  Future<void> remove(String owner, String note) async {
    data.remove('$owner:$note');
    storedFiles.removeWhere((k, _) => k.startsWith('$owner:$note:'));
  }

  @override
  Future<void> putFile(
    String owner,
    String note,
    String key,
    PickedNoteFile file,
  ) async {
    storedFiles['$owner:$note:$key'] = file;
  }

  @override
  Future<PickedNoteFile> file(String owner, String note, String key) async =>
      storedFiles['$owner:$note:$key']!;
}

class FakeNoteFiles implements NoteFileService {
  PickedNoteFile? picked;
  int opens = 0, clears = 0;
  @override
  Future<PickedNoteFile?> pick() async => picked;
  @override
  Future<void> openPdf(Uint8List bytes) async {
    opens++;
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

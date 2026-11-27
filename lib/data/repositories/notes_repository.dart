import 'dart:typed_data';

import '../../domain/models/note_models.dart';

abstract interface class NotesRepository {
  Future<List<NoteFolder>> folders();
  Future<List<PersonalNote>> list({String? folderId, String search = ''});
  Future<NoteFolder> saveFolder({
    String? id,
    required String name,
    String? parentId,
  });
  Future<void> deleteFolder(String id);
  Future<PersonalNote> read(String id);
  Future<PersonalNote> create({String? folderId});
  Future<PersonalNote> save(String id, NoteDraft draft);
  Future<void> delete(String id, int revision);
  Future<NoteAttachment> upload(
    String noteId,
    String key,
    PickedNoteFile file,
    void Function(double) progress,
  );
  Future<Uint8List> download(String noteId, String attachmentId);
  Future<void> removeAttachment(String noteId, String attachmentId);
  void cancelPending();
}

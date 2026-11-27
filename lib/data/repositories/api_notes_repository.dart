import 'dart:typed_data';

import '../../domain/models/note_models.dart';
import '../services/notes_api_service.dart';
import 'notes_repository.dart';

typedef NotesSessionRequest = Future<T> Function<T>(
  Future<T> Function(String) request,
);

class ApiNotesRepository implements NotesRepository {
  ApiNotesRepository({required this.api, required this.withSession});
  final NotesApiService api;
  final NotesSessionRequest withSession;
  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    int status = 200,
    Map<String, String> headers = const {},
  }) => withSession(
    (t) => api.request(
      t,
      method,
      path,
      body: body,
      query: query,
      status: status,
      headers: headers,
    ),
  );
  @override
  Future<List<NoteFolder>> folders() async => List.unmodifiable(
    (await _request('GET', '/folders') as List).map(NoteFolder.fromJson),
  );
  @override
  Future<List<PersonalNote>> list({
    String? folderId,
    String search = '',
  }) async {
    final all = <PersonalNote>[];
    var page = 1;
    while (true) {
      final m = noteMap(
        await _request(
          'GET',
          '',
          query: {
            'folderId': ?folderId,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            'page': '$page',
          },
        ),
      );
      all.addAll((m['items'] as List).map(PersonalNote.fromJson));
      if (m['hasMore'] != true) break;
      if (page++ >= 20) throw NotesFailure.fromCode(null);
    }
    return List.unmodifiable(all);
  }

  @override
  Future<NoteFolder> saveFolder({
    String? id,
    required String name,
    String? parentId,
  }) async => NoteFolder.fromJson(
    await _request(
      id == null ? 'POST' : 'PATCH',
      '/folders${id == null ? '' : '/$id'}',
      body: {'name': name, 'parentId': parentId},
      status: id == null ? 201 : 200,
    ),
  );
  @override
  Future<void> deleteFolder(String id) async {
    await _request('DELETE', '/folders/$id', status: 204);
  }

  @override
  Future<PersonalNote> read(String id) async =>
      PersonalNote.fromJson(await _request('GET', '/$id'));
  @override
  Future<PersonalNote> create({String? folderId}) async =>
      PersonalNote.fromJson(
        await _request(
          'POST',
          '',
          body: {'folderId': ?folderId},
          status: 201,
        ),
      );
  @override
  Future<PersonalNote> save(String id, NoteDraft draft) async =>
      PersonalNote.fromJson(
        await _request(
          'PATCH',
          '/$id',
          body: {
            'revision': draft.revision,
            'title': draft.title,
            'folderId': draft.folderId,
            'document': draft.document.toServerJson(),
          },
        ),
      );
  @override
  Future<void> delete(String id, int revision) async {
    await _request(
      'DELETE',
      '/$id',
      status: 204,
      headers: {'If-Match': '"$revision"'},
    );
  }

  @override
  Future<NoteAttachment> upload(
    String noteId,
    String key,
    PickedNoteFile file,
    void Function(double) progress,
  ) => withSession(
    (t) async => NoteAttachment.fromJson(
      await api.request(
        t,
        'POST',
        '/$noteId/attachments',
        upload: file,
        headers: {'X-Upload-Id': key},
        progress: progress,
        status: 201,
      ),
    ),
  );
  @override
  Future<Uint8List> download(String noteId, String attachmentId) => withSession(
    (t) async => await api.request(
      t,
      'GET',
      '/$noteId/attachments/$attachmentId',
      binary: true,
    ) as Uint8List,
  );
  @override
  Future<void> removeAttachment(String noteId, String attachmentId) async {
    await _request('DELETE', '/$noteId/attachments/$attachmentId', status: 204);
  }

  @override
  void cancelPending() => api.cancel();
}

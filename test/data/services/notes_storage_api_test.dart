import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:balamandian/data/services/note_draft_store.dart';
import 'package:balamandian/data/services/note_file_service.dart';
import 'package:flutter/services.dart';
import 'package:balamandian/data/services/notes_api_service.dart';
import 'package:balamandian/data/repositories/api_notes_repository.dart';
import 'package:balamandian/domain/models/note_models.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../notes_test_support.dart';
import '../../profile_test_support.dart';
import '../../auth_test_support.dart' show failure;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account cleanup cancels a private PDF open before cache work completes',
    () async {
      final reply = Completer<Directory>();
      final service = PlatformNoteFileService(temporary: () => reply.future);
      final opening = service.openPdf(Uint8List.fromList([1]));
      await service.clear();
      reply.complete(Directory.systemTemp);
      await opening;
    },
  );
  test('private PDF bridge opens only a generated cache copy and clears it with read-grant revocation', () async {
    final dir = await Directory.systemTemp.createTemp('balamandian-pdf-test-');
    addTearDown(() async {
      expect(dir.parent.absolute.path, Directory.systemTemp.absolute.path);
      await dir.delete(recursive: true);
    });
    const channel = MethodChannel('balamandian/notes-files');
    final calls = <String>[];
    String? opened;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'openPdf') {
            opened = (call.arguments as Map)['path'] as String;
            expect(await File(opened!).readAsBytes(), [1, 2, 3]);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final service = PlatformNoteFileService(temporary: () async => dir);
    await service.openPdf(Uint8List.fromList([1, 2, 3]));
    expect(opened, contains('notes-pdf'));
    expect(calls, containsAllInOrder(['clearPdf', 'openPdf']));
    await service.clear();
    expect(await File(opened!).exists(), isFalse);
    expect(calls.last, 'clearPdf');
  });
  test('app-private draft and pending-file recovery survives new store instance, scoped to owner and note', () async {
    final dir = await Directory.systemTemp.createTemp(
      'balamandian-notes-test-',
    );
    addTearDown(() async {
      expect(dir.parent.absolute.path, Directory.systemTemp.absolute.path);
      await dir.delete(recursive: true);
    });
    final store = FileNoteDraftStore(directory: () async => dir),
        key = 'c' * 32;
    final block = NoteBlock(type: 'attachment', localId: key);
    final draft = NoteDraft(
      noteId: noteId,
      title: 'Recovered',
      folderId: folderId,
      revision: 5,
      document: NoteDocument([
        NoteBlock(type: 'bullet', text: 'Formatted', bold: true),
        NoteBlock(
          type: 'drawing',
          strokes: [
            const InkStroke(color: 1, width: .004, points: [InkPoint(.2, .3)]),
          ],
        ),
        block,
      ]),
    );
    await store.putFile(
      ownId,
      noteId,
      key,
      PickedNoteFile('image.png', 'image/png', Uint8List.fromList([1, 2, 3])),
    );
    await Future.wait([
      store.write(ownId, draft),
      store.write(
        ownId,
        NoteDraft(
          noteId: noteId,
          title: 'Newest',
          folderId: folderId,
          revision: 5,
          document: draft.document,
        ),
      ),
    ]);
    final restarted = FileNoteDraftStore(directory: () async => dir),
        result = await restarted.read(ownId, noteId);
    expect(result!.title, 'Newest');
    expect(result.document.blocks.first.bold, isTrue);
    expect(result.document.blocks[1].strokes.first.points.single.y, .3);
    expect((await restarted.file(ownId, noteId, key)).bytes, [1, 2, 3]);
    expect(await restarted.read(otherId, noteId), isNull);
    expect(await restarted.list(otherId), isEmpty);
    await restarted.remove(ownId, noteId);
    expect(await restarted.read(ownId, noteId), isNull);
    await expectLater(
      restarted.read('../escape', noteId),
      throwsFormatException,
    );
  });
  test('real API mapping sends revision and server document without local file keys', () async {
    final requests = <http.Request>[];
    final api = NotesApiService(
      baseUrl: Uri.parse('https://api.example.edu'),
      client: MockClient((r) async {
        requests.add(r);
        if (r.method == 'PATCH') {
          final b = noteMap(jsonDecode(r.body));
          expect(b['revision'], 3);
          expect(
            (b['document'] as Map)['blocks'][0].containsKey('localId'),
            isFalse,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'id': noteId,
              'folderId': folderId,
              'title': 'Title',
              'revision': 4,
              'updatedAt': '2026-11-25T10:00:00.000Z',
              'document': {'version': 1, 'blocks': []},
              'attachments': [],
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final repo = ApiNotesRepository(
      api: api,
      withSession: <T>(request) => request('session'),
    );
    final reply = await repo.save(
      noteId,
      NoteDraft(
        noteId: noteId,
        title: 'Title',
        folderId: folderId,
        revision: 3,
        document: NoteDocument([
          NoteBlock(
            type: 'attachment',
            attachmentId: otherId,
            localId: 'a' * 32,
          ),
        ]),
      ),
    );
    expect(reply.revision, 4);
    expect(requests.single.url.path, '/api/v1/notes/$noteId');
    expect(requests.single.headers['Authorization'], 'Bearer session');
  });
  test('streamed attachment upload reports progress, carries idempotency key and no public URL', () async {
    final progress = <double>[];
    final api = NotesApiService(
      baseUrl: Uri.parse('https://api.example.edu'),
      client: MockClient((r) async {
        expect(r.headers['X-Upload-Id'], 'a' * 32);
        expect(r.bodyBytes.length, 40000);
        return http.Response(
          jsonEncode({
            'data': {
              'id': otherId,
              'filename': 'paper.pdf',
              'mediaType': 'application/pdf',
              'size': 40000,
            },
          }),
          201,
        );
      }),
    );
    addTearDown(api.close);
    final repo = ApiNotesRepository(
      api: api,
      withSession: <T>(request) => request('session'),
    );
    final result = await repo.upload(
      noteId,
      'a' * 32,
      PickedNoteFile('paper.pdf', 'application/pdf', Uint8List(40000)),
      progress.add,
    );
    expect(result.id, otherId);
    expect(progress.last, 1);
    expect(progress.length, greaterThan(1));
  });
  test('401 follows existing session expiry boundary and conflict is safely mapped', () async {
    for (final code in ['UNAUTHENTICATED', 'NOTE_CONFLICT', 'NOTE_NOT_FOUND']) {
      final api = NotesApiService(
        baseUrl: Uri.parse('https://api.example.edu'),
        client: MockClient(
          (_) async =>
              failure(code, status: code == 'UNAUTHENTICATED' ? 401 : 409),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.request('session', 'GET', '/$noteId'),
        throwsA(
          code == 'UNAUTHENTICATED'
              ? isA<AuthFailure>()
              : isA<NotesFailure>().having((e) => e.code, 'code', code),
        ),
      );
    }
  });
  test(
    'local version, document limits and pending references remain explicit',
    () {
      expect(
        () => NoteDocument.fromJson({'version': 2, 'blocks': []}),
        throwsFormatException,
      );
      expect(NoteDocument([NoteBlock(text: 'a' * 50001)]).error, isNotNull);
      final d = NoteDocument([
        NoteBlock(type: 'attachment', localId: 'a' * 32),
      ]);
      expect(d.error, contains('pending'));
      expect(
        () => InkPoint.fromJson({'x': double.infinity, 'y': .2}),
        throwsFormatException,
      );
    },
  );
}

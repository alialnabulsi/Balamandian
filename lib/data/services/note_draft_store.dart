import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/note_models.dart';

abstract interface class NoteDraftStore {
  Future<void> write(String owner, NoteDraft draft);
  Future<NoteDraft?> read(String owner, String note);
  Future<List<NoteDraft>> list(String owner);
  Future<void> remove(String owner, String note);
  Future<void> putFile(
    String owner,
    String note,
    String key,
    PickedNoteFile file,
  );
  Future<PickedNoteFile> file(String owner, String note, String key);
}

class FileNoteDraftStore implements NoteDraftStore {
  FileNoteDraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();
  void _id(String id) {
    if (!RegExp(r'^[a-fA-F0-9-]{32,36}$').hasMatch(id)) {
      throw const FormatException('Invalid private draft key');
    }
  }

  Future<Directory> _dir(String owner, String note) async {
    _id(owner);
    _id(note);
    final base = await _directory();
    return Directory('${base.path}/notes-drafts-v1/$owner/$note')
        .create(recursive: true);
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _atomic(File file, String json) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> write(String owner, NoteDraft draft) => _serial(() async {
    final dir = await _dir(owner, draft.noteId);
    await _atomic(File('${dir.path}/draft.json'), jsonEncode(draft.toJson()));
  });
  @override
  Future<NoteDraft?> read(String owner, String note) => _serial(() async {
    final dir = await _dir(owner, note), f = File('${dir.path}/draft.json');
    if (!await f.exists()) return null;
    return NoteDraft.fromJson(jsonDecode(await f.readAsString()));
  });
  @override
  Future<List<NoteDraft>> list(String owner) => _serial(() async {
    _id(owner);
    final base = await _directory(),
        root = Directory('${base.path}/notes-drafts-v1/$owner');
    if (!await root.exists()) return [];
    final drafts = <NoteDraft>[];
    await for (final child in root.list(followLinks: false)) {
      if (child is Directory) {
        final f = File('${child.path}/draft.json');
        if (await f.exists()) {
          try {
            drafts.add(NoteDraft.fromJson(jsonDecode(await f.readAsString())));
          } on FormatException {
            /* Preserve corrupt file for explicit recovery, do not erase it. */
          }
        }
      }
    }
    return drafts;
  });
  @override
  Future<void> remove(String owner, String note) => _serial(() async {
    final dir = await _dir(owner, note);
    // Only files inside the explicitly validated owner/note directory; no
    // recursive delete, symlink traversal, or cleanup of other account drafts.
    await for (final child in dir.list(followLinks: false)) {
      if (child is File) await child.delete();
    }
  });
  @override
  Future<void> putFile(
    String owner,
    String note,
    String key,
    PickedNoteFile file,
  ) => _serial(() async {
    _id(key);
    if (file.bytes.length > 5242880) {
      throw NotesFailure.fromCode('ATTACHMENT_INVALID');
    }
    final dir = await _dir(owner, note);
    await File('${dir.path}/$key.bin').writeAsBytes(file.bytes, flush: true);
    await _atomic(
      File('${dir.path}/$key.json'),
      jsonEncode({'name': file.name, 'type': file.type}),
    );
  });
  @override
  Future<PickedNoteFile> file(String owner, String note, String key) =>
      _serial(() async {
        _id(key);
        final dir = await _dir(owner, note);
        final m = noteMap(
          jsonDecode(await File('${dir.path}/$key.json').readAsString()),
        );
        return PickedNoteFile(
          m['name'] as String,
          m['type'] as String,
          await File('${dir.path}/$key.bin').readAsBytes(),
        );
      });
}

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/note_models.dart';

abstract interface class NoteFileService {
  Future<PickedNoteFile?> pick();
  Future<void> openPdf(Uint8List bytes);
  Future<void> clear();
}

class PlatformNoteFileService implements NoteFileService {
  PlatformNoteFileService({
    Future<Directory> Function()? temporary,
    this.channel = const MethodChannel('balamandian/notes-files'),
  }) : _temporary = temporary ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporary;
  final MethodChannel channel;
  Directory? _cache;
  int _generation = 0;
  final _opened = <File>[];
  @override
  Future<PickedNoteFile?> pick() async {
    final f = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images and PDF',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          mimeTypes: [
            'image/jpeg',
            'image/png',
            'image/webp',
            'application/pdf',
          ],
        ),
      ],
    );
    if (f == null) return null;
    if (await f.length() > 5242880) {
      throw NotesFailure.fromCode('ATTACHMENT_INVALID');
    }
    final ext = f.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => throw NotesFailure.fromCode('ATTACHMENT_INVALID'),
    };
    return PickedNoteFile(f.name, type, await f.readAsBytes());
  }

  @override
  Future<void> openPdf(Uint8List bytes) async {
    final generation = ++_generation;
    final base = await _temporary();
    if (generation != _generation) return;
    final dir = await Directory('${base.path}/notes-pdf')
        .create(recursive: true);
    if (generation != _generation) return;
    _cache = dir;
    await _clearFiles();
    if (generation != _generation) return;
    final f = File('${dir.path}/private-note-${noteLocalId()}.pdf');
    await f.writeAsBytes(bytes, flush: true);
    _opened.add(f);
    if (generation != _generation) {
      if (await f.exists()) await f.delete();
      _opened.remove(f);
      return;
    }
    try {
      await channel.invokeMethod<void>('openPdf', {'path': f.path});
    } on Exception {
      throw const NotesFailure(
        'OPEN_FAILED',
        'Install a PDF viewer or try opening this attachment again.',
      );
    }
  }

  @override
  Future<void> clear() async {
    _generation++;
    await _clearFiles();
  }

  Future<void> _clearFiles() async {
    final cache = _cache;
    if (cache != null) {
      try {
        await channel.invokeMethod<void>('clearPdf');
      } on Exception {
        /* Files are still removed if the Activity is closing. */
      }
      if (await cache.exists()) {
        await for (final file in cache.list(followLinks: false)) {
          if (file is File &&
              RegExp(r'^private-note-[a-f0-9]{32}\.pdf$')
                  .hasMatch(file.uri.pathSegments.last)) {
            await file.delete();
          }
        }
      }
    }
    for (final f in _opened.toList()) {
      if (await f.exists()) await f.delete();
      _opened.remove(f);
    }
  }
}

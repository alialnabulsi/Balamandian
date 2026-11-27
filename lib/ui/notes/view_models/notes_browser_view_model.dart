import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notes_repository.dart';
import '../../../data/services/note_draft_store.dart';
import '../../../domain/models/note_models.dart';
import '../../../domain/models/auth_failure.dart';
import 'notes_session.dart';

String notesMessage(Object e) => switch (e) {
  NotesFailure() => e.message,
  AuthFailure() => e.message,
  _ => 'Notes could not load. Please retry.',
};

class NotesBrowserViewModel extends ChangeNotifier {
  NotesBrowserViewModel({
    required this.session,
    required this.repository,
    required this.drafts,
  }) {
    session.addListener(_sync);
    _sync();
  }
  final NotesSession session;
  final NotesRepository repository;
  final NoteDraftStore drafts;
  List<NoteFolder> folders = [];
  List<PersonalNote> notes = [];
  List<NoteDraft> recovered = [];
  String? folderId, error;
  String search = '';
  bool loading = false, busy = false;
  int _epoch = -1, _request = 0;
  bool _disposed = false;
  Timer? _searchTimer;
  bool get eligible => session.owner != null;
  List<NoteFolder> get children =>
      folders.where((f) => f.parentId == folderId).toList();
  Set<String> excludedDestinations(String id) {
    final excluded = <String>{id};
    var added = true;
    while (added) {
      added = false;
      for (final f in folders) {
        if (excluded.contains(f.parentId) && excluded.add(f.id)) added = true;
      }
    }
    return excluded;
  }

  String path(String? id) {
    final parts = <String>[];
    var at = id;
    while (at != null && parts.length <= 20) {
      final f = folders.where((f) => f.id == at).firstOrNull;
      if (f == null) break;
      parts.insert(0, f.name);
      at = f.parentId;
    }
    return parts.isEmpty ? 'My Notes' : parts.join(' / ');
  }

  List<NoteFolder> get breadcrumbs {
    final result = <NoteFolder>[];
    var at = folderId;
    while (at != null && result.length <= 20) {
      final f = folders.where((f) => f.id == at).firstOrNull;
      if (f == null) break;
      result.insert(0, f);
      at = f.parentId;
    }
    return result;
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    if (_epoch != session.epoch) {
      _epoch = session.epoch;
      _request++;
      _searchTimer?.cancel();
      folders = [];
      notes = [];
      recovered = [];
      folderId = null;
      search = '';
      error = null;
      busy = loading = false;
      if (eligible) scheduleMicrotask(refresh);
    }
    _publish();
  }

  bool _current(int e, int r) =>
      !_disposed && eligible && e == session.epoch && r == _request;
  Future<void> refresh() async {
    if (!eligible) return;
    final e = session.epoch, r = ++_request, owner = session.owner!;
    loading = true;
    error = null;
    _publish();
    try {
      final fs = await repository.folders();
      if (!_current(e, r)) return;
      final ns = await repository.list(folderId: folderId, search: search);
      if (!_current(e, r)) return;
      final ds = await drafts.list(owner);
      if (_current(e, r)) {
        folders = fs;
        notes = ns;
        recovered = ds;
      }
    } catch (ex) {
      if (_current(e, r)) {
        error = notesMessage(ex);
        try {
          final local = await drafts.list(owner);
          if (_current(e, r)) recovered = local;
        } catch (_) {
          /* Error shown below. */
        }
      }
    } finally {
      if (_current(e, r)) {
        loading = false;
        _publish();
      }
    }
  }

  void enter(String? id) {
    folderId = id;
    search = '';
    _searchTimer?.cancel();
    unawaited(refresh());
  }

  bool back() {
    if (search.isNotEmpty) {
      setSearch('');
      return true;
    }
    if (folderId == null) return false;
    final f = folders.where((f) => f.id == folderId).firstOrNull;
    enter(f?.parentId);
    return true;
  }

  void setSearch(String value) {
    search = value;
    _request++;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), refresh);
    _publish();
  }

  Future<T?> _mutate<T>(Future<T> Function() run) async {
    if (!eligible || busy) return null;
    final e = session.epoch;
    busy = true;
    error = null;
    _publish();
    try {
      final result = await run();
      if (e != session.epoch || _disposed) return null;
      await refresh();
      return result;
    } catch (ex) {
      if (e == session.epoch && !_disposed) error = notesMessage(ex);
      return null;
    } finally {
      if (e == session.epoch && !_disposed) {
        busy = false;
        _publish();
      }
    }
  }

  Future<PersonalNote?> create() =>
      _mutate(() => repository.create(folderId: folderId));
  Future<void> saveFolder(
    String name, {
    NoteFolder? folder,
    String? parent,
  }) async {
    await _mutate(
      () => repository.saveFolder(
        id: folder?.id,
        name: name,
        parentId: folder == null ? folderId : parent,
      ),
    );
  }

  Future<void> deleteFolder(NoteFolder folder) async {
    await _mutate(() => repository.deleteFolder(folder.id));
  }

  Future<void> deleteNote(PersonalNote note) async {
    final owner = session.owner;
    if (owner == null) return;
    await _mutate(() async {
      await repository.delete(note.id, note.revision);
      await drafts.remove(owner, note.id);
    });
  }

  Future<void> moveNote(PersonalNote note, String destination) async {
    await _mutate(() async {
      final full = await repository.read(note.id);
      return repository.save(
        note.id,
        NoteDraft(
          noteId: note.id,
          title: full.title,
          folderId: destination,
          revision: full.revision,
          document: full.document!,
        ),
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    session.removeListener(_sync);
    super.dispose();
  }
}

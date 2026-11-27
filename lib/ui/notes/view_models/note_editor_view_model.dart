import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notes_repository.dart';
import '../../../data/services/note_draft_store.dart';
import '../../../data/services/note_file_service.dart';
import '../../../domain/models/note_models.dart';
import 'notes_session.dart';
import 'notes_browser_view_model.dart' show notesMessage;

class NoteEditorViewModel extends ChangeNotifier {
  NoteEditorViewModel({
    required this.noteId,
    required this.session,
    required this.repository,
    required this.drafts,
    required this.files,
    this.debounce = const Duration(milliseconds: 900),
  }) {
    session.addListener(_sync);
    _sync();
  }
  final String noteId;
  final NotesSession session;
  final NotesRepository repository;
  final NoteDraftStore drafts;
  final NoteFileService files;
  final Duration debounce;
  String title = '', folderId = '';
  int revision = 1, generation = 0;
  NoteDocument document = NoteDocument([]);
  List<NoteAttachment> attachments = [];
  final Map<String, Uint8List> previews = {};
  final Map<String, Future<Uint8List?>> _previewRequests = {};
  Future<List<NoteFolder>> destinations() => repository.folders();
  final Map<String, double> uploading = {};
  final Map<String, String> uploadErrors = {};
  bool loading = false,
      loaded = false,
      dirty = false,
      saving = false,
      recovered = false,
      conflict = false,
      deleting = false,
      deleted = false;
  String? error, draftError;
  String? _owner;
  int _epoch = -1, _seq = 0, _operation = 0;
  bool _disposed = false;
  Timer? _timer;
  final _undo = <NoteDocument>[], _redo = <NoteDocument>[];
  String? selectedId;
  NoteDocument? _drawingOriginal;
  String? _drawingId;
  NoteBlock? beginDrawing(String? id) {
    if (!canEdit || _drawingOriginal != null) return null;
    _drawingOriginal = document;
    final b =
        document.blocks
            .where((b) => b.id == id && b.type == 'drawing')
            .firstOrNull ??
        NoteBlock(type: 'drawing');
    _drawingId = b.id;
    if (id == null) changeDocument(NoteDocument([...document.blocks, b]));
    _timer?.cancel();
    return b;
  }

  void stageDrawing(List<InkStroke> strokes) {
    final b = document.blocks.where((b) => b.id == _drawingId).firstOrNull;
    if (canEdit && b != null) {
      updateBlock(b.copy(strokes: List.unmodifiable(strokes)));
    }
  }

  void endDrawing({required bool keep}) {
    if (!canEdit || _drawingOriginal == null) return;
    final original = _drawingOriginal!;
    _drawingOriginal = null;
    _drawingId = null;
    if (!keep) {
      changeDocument(original);
    } else {
      _changed();
    }
  }

  NoteBlock? get selected =>
      document.blocks
          .where((b) => b.id == selectedId && b.isText)
          .firstOrNull ??
      document.blocks.where((b) => b.isText).firstOrNull;
  void select(String id) {
    selectedId = id;
    _publish();
  }

  void format({String? type, String? mark}) {
    final b = selected;
    if (b == null) return;
    updateBlock(
      b.copy(
        type: type,
        bold: mark == 'bold' ? !b.bold : null,
        italic: mark == 'italic' ? !b.italic : null,
        underline: mark == 'underline' ? !b.underline : null,
      ),
    );
  }

  int numberFor(String id) {
    var n = 0;
    for (final b in document.blocks) {
      n = b.type == 'numbered' ? n + 1 : 0;
      if (b.id == id) return n;
    }
    return 0;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get current =>
      !_disposed &&
      session.owner != null &&
      session.owner == _owner &&
      !deleted;
  bool get canEdit => current && loaded && !deleting;
  String get saveStatus => saving
      ? 'Saving…'
      : dirty
      ? 'Unsaved changes'
      : loaded
      ? 'Saved'
      : 'Loading…';
  NoteDraft get draft => NoteDraft(
    noteId: noteId,
    title: title,
    folderId: folderId,
    revision: revision,
    document: document,
  );
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    if (_epoch != session.epoch) {
      _epoch = session.epoch;
      _owner = session.owner;
      _operation++;
      _timer?.cancel();
      generation++;
      title = '';
      folderId = '';
      document = NoteDocument([]);
      attachments = [];
      previews.clear();
      _previewRequests.clear();
      uploading.clear();
      uploadErrors.clear();
      _undo.clear();
      _redo.clear();
      _drawingOriginal = null;
      _drawingId = null;
      dirty = saving = loaded = loading = recovered = conflict = deleting =
          deleted = false;
      error = draftError = null;
      unawaited(files.clear());
      if (_owner != null) scheduleMicrotask(load);
    }
    _publish();
  }

  bool _valid(int epoch, int op) =>
      current && epoch == session.epoch && op == _operation;
  Future<void> load() async {
    if (!current || loading) return;
    final e = session.epoch, op = ++_operation, owner = _owner!;
    loading = true;
    error = null;
    _publish();
    NoteDraft? local;
    try {
      local = await drafts.read(owner, noteId);
    } catch (_) {
      if (_valid(e, op)) {
        draftError =
            'The local draft could not be read. It has not been erased.';
      }
    }
    try {
      if (!_valid(e, op)) return;
      final server = await repository.read(noteId);
      if (!_valid(e, op)) return;
      attachments = server.attachments;
      if (local != null) {
        _applyDraft(local);
        recovered = dirty = true;
        conflict = server.revision != local.revision;
      } else {
        title = server.title;
        folderId = server.folderId;
        revision = server.revision;
        document = server.document!;
      }
      if (document.blocks.isEmpty) {
        final body = NoteBlock();
        document = NoteDocument([body]);
        selectedId = body.id;
      }
      loaded = true;
    } catch (ex) {
      if (_valid(e, op)) {
        error = notesMessage(ex);
        if (local != null) {
          _applyDraft(local);
          loaded = recovered = dirty = true;
        }
      }
    } finally {
      if (_valid(e, op)) {
        loading = false;
        generation++;
        _publish();
      }
    }
  }

  void _applyDraft(NoteDraft d) {
    title = d.title;
    folderId = d.folderId;
    revision = d.revision;
    document = d.document;
  }

  Future<void> _persist() async {
    final owner = _owner, e = session.epoch, seq = _seq, content = draft;
    if (owner == null) return;
    try {
      await drafts.write(owner, content);
      if (current && e == session.epoch && seq == _seq) {
        draftError = null;
        _publish();
      }
    } catch (_) {
      if (current && e == session.epoch) {
        draftError = 'Local recovery could not be written. Keep this editor open and retry Save.';
        _publish();
      }
    }
  }

  void _changed() {
    _seq++;
    dirty = true;
    error = null;
    unawaited(_persist());
    _timer?.cancel();
    if (!conflict) _timer = Timer(debounce, save);
    _publish();
  }

  void setTitle(String value) {
    if (!canEdit) return;
    title = value;
    _changed();
  }

  void changeDocument(NoteDocument next, {bool history = true}) {
    if (!canEdit) return;
    if (history) {
      _undo.add(document);
      if (_undo.length > 50) _undo.removeAt(0);
      _redo.clear();
    }
    document = next;
    _changed();
  }

  void updateBlock(NoteBlock block) => changeDocument(
    NoteDocument(document.blocks.map((b) => b.id == block.id ? block : b)),
  );
  void addText() {
    if (document.blocks.length >= 100) {
      error = 'A note supports 100 blocks.';
      _publish();
      return;
    }
    changeDocument(NoteDocument([...document.blocks, NoteBlock()]));
  }

  void addDrawing(List<InkStroke> strokes, {String? blockId}) {
    if (blockId != null) {
      final b = document.blocks.where((b) => b.id == blockId).firstOrNull;
      if (b != null) updateBlock(b.copy(strokes: strokes));
    } else {
      changeDocument(
        NoteDocument([
          ...document.blocks,
          NoteBlock(type: 'drawing', strokes: strokes),
        ]),
      );
    }
  }

  void removeBlock(String id) {
    changeDocument(NoteDocument(document.blocks.where((b) => b.id != id)));
  }

  void undo() {
    if (!canEdit || _undo.isEmpty) return;
    _redo.add(document);
    document = _undo.removeLast();
    generation++;
    _changed();
  }

  void redo() {
    if (!canEdit || _redo.isEmpty) return;
    _undo.add(document);
    document = _redo.removeLast();
    generation++;
    _changed();
  }

  Future<void> move(String id) async {
    if (!canEdit) return;
    folderId = id;
    _changed();
    await save();
  }

  Future<bool> save() async {
    if (!canEdit ||
        saving ||
        conflict ||
        !dirty ||
        uploading.isNotEmpty ||
        _drawingOriginal != null) {
      return !dirty;
    }
    final validation = title.runes.length > 160
        ? 'Title limit: 160 characters.'
        : document.error;
    if (validation != null) {
      error = validation;
      _publish();
      return false;
    }
    _timer?.cancel();
    final e = session.epoch, op = _operation, seq = _seq, snapshot = draft;
    saving = true;
    error = null;
    _publish();
    try {
      await _persist();
      if (!_valid(e, op)) return false;
      final reply = await repository.save(noteId, snapshot);
      if (!_valid(e, op) || deleting) return false;
      revision = reply.revision;
      attachments = reply.attachments;
      recovered = false;
      if (seq == _seq) {
        document = reply.document!;
        title = reply.title;
        dirty = false;
        final refs = document.blocks
            .map((b) => b.attachmentId)
            .whereType<String>()
            .toSet();
        bool staleHistory(NoteDocument d) => d.blocks.any(
          (b) =>
              b.localId != null ||
              (b.attachmentId != null && !refs.contains(b.attachmentId)),
        );
        _undo.removeWhere(staleHistory);
        _redo.removeWhere(staleHistory);
        await drafts.remove(_owner!, noteId);
      } else {
        dirty = true;
        await _persist();
      }
      return !dirty;
    } catch (ex) {
      if (_valid(e, op)) {
        dirty = true;
        error = notesMessage(ex);
        conflict = ex is NotesFailure && ex.code == 'NOTE_CONFLICT';
        await _persist();
      }
      return false;
    } finally {
      if (_valid(e, op)) {
        saving = false;
        if (dirty && !conflict && error == null) _timer = Timer(debounce, save);
        _publish();
      }
    }
  }

  /// Explicit user-approved rebase keeps the local content, never silently
  /// replaces it with a remote document. A further concurrent edit still 409s.
  Future<void> rebase() async {
    if (!canEdit || saving) return;
    final e = session.epoch, op = _operation;
    try {
      final latest = await repository.read(noteId);
      if (!_valid(e, op)) return;
      revision = latest.revision;
      attachments = latest.attachments;
      conflict = false;
      error = null;
      dirty = true;
      await _persist();
      _publish();
    } catch (ex) {
      if (_valid(e, op)) {
        error = notesMessage(ex);
        _publish();
      }
    }
  }

  Future<void> pickAttachment() async {
    if (!canEdit || uploading.isNotEmpty) return;
    final e = session.epoch, op = _operation;
    try {
      final file = await files.pick();
      if (file == null || !_valid(e, op)) return;
      if (document.blocks.where((b) => b.type == 'attachment').length >= 10) {
        throw NotesFailure.fromCode('NOTES_LIMIT');
      }
      final key = noteLocalId();
      _seq++;
      dirty = true;
      _timer?.cancel();
      await drafts.putFile(_owner!, noteId, key, file);
      if (!_valid(e, op)) return;
      final b = NoteBlock(type: 'attachment', localId: key);
      changeDocument(NoteDocument([...document.blocks, b]));
      await upload(b);
    } catch (ex) {
      if (_valid(e, op)) {
        error = notesMessage(ex);
        _publish();
      }
    }
  }

  Future<void> upload(NoteBlock block) async {
    if (!canEdit || block.localId == null || uploading.containsKey(block.id)) {
      return;
    }
    final e = session.epoch, op = _operation;
    uploading[block.id] = 0;
    uploadErrors.remove(block.id);
    _publish();
    try {
      final file = await drafts.file(_owner!, noteId, block.localId!);
      if (!_valid(e, op)) return;
      final a = await repository.upload(noteId, block.localId!, file, (p) {
        if (_valid(e, op)) {
          uploading[block.id] = p;
          _publish();
        }
      });
      if (!_valid(e, op)) return;
      final currentBlock = document.blocks
          .where((b) => b.id == block.id)
          .firstOrNull;
      if (currentBlock != null) {
        attachments = [...attachments.where((x) => x.id != a.id), a];
        updateBlock(currentBlock.copy(attachmentId: a.id));
      } else {
        await repository.removeAttachment(noteId, a.id);
      }
    } catch (ex) {
      if (_valid(e, op)) uploadErrors[block.id] = notesMessage(ex);
    } finally {
      if (_valid(e, op)) {
        uploading.remove(block.id);
        _publish();
      }
    }
  }

  void cancelUpload() {
    repository.cancelPending();
  }

  Future<Uint8List?> preview(NoteBlock block) {
    if (!canEdit || block.attachmentId == null) return Future.value(null);
    return _previewRequests.putIfAbsent(
      block.attachmentId!,
      () => _loadPreview(block),
    );
  }

  Future<Uint8List?> _loadPreview(NoteBlock block) async {
    if (!canEdit || block.attachmentId == null) return null;
    final id = block.attachmentId!, cached = previews[id];
    if (cached != null) return cached;
    final e = session.epoch, op = _operation;
    try {
      final bytes = await repository.download(noteId, id);
      if (!_valid(e, op)) return null;
      previews[id] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> openAttachment(NoteBlock block) async {
    if (!canEdit) return;
    final e = session.epoch, op = _operation;
    try {
      final bytes = block.localId != null
          ? (await drafts.file(_owner!, noteId, block.localId!)).bytes
          : await repository.download(noteId, block.attachmentId!);
      if (!_valid(e, op)) return;
      await files.openPdf(bytes);
    } catch (ex) {
      if (_valid(e, op)) {
        error = ex is NotesFailure
            ? ex.message
            : 'This attachment could not be opened.';
        _publish();
      }
    }
  }

  Future<bool> delete() async {
    if (!canEdit || deleting) return false;
    deleting = true;
    _timer?.cancel();
    _operation++;
    repository.cancelPending();
    final e = session.epoch, op = _operation;
    _publish();
    try {
      final latest = await repository.read(noteId);
      if (!_valid(e, op)) return false;
      await repository.delete(noteId, latest.revision);
      if (!_valid(e, op)) return false;
      deleted = true;
      dirty = false;
      await drafts.remove(_owner!, noteId);
      return true;
    } catch (ex) {
      if (_valid(e, op)) error = notesMessage(ex);
      return false;
    } finally {
      if (!_disposed) {
        deleting = false;
        saving = false;
        _publish();
      }
    }
  }

  Future<bool> keepDraftAndLeave() async {
    _timer?.cancel();
    await _persist();
    return draftError == null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _operation++;
    repository.cancelPending();
    session.removeListener(_sync);
    unawaited(files.clear());
    super.dispose();
  }
}

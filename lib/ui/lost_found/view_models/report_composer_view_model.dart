import 'package:flutter/foundation.dart';

import '../../../data/repositories/lost_found_repository.dart';
import '../../../data/services/note_file_service.dart';
import '../../../domain/models/lost_found_models.dart';
import '../../../domain/models/note_models.dart' show noteLocalId, NotesFailure;
import '../../../domain/models/tool_failure.dart';
import '../../tools/view_models/tool_session.dart';

class ReportComposerViewModel extends ChangeNotifier {
  ReportComposerViewModel(this.repository, this.files, this.session, this.type)
    : epoch = session.epoch;
  final LostFoundRepository repository;
  final NoteFileService files;
  final ToolSession session;
  final String type;
  final int epoch;
  bool busy = false, submitted = false, _disposed = false;
  String? error;
  String key = noteLocalId();
  final uploads = <ReportUpload>[];
  bool get current =>
      !_disposed && epoch == session.epoch && session.owner != null;
  void changed() {
    key = noteLocalId();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || !current) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      if (current) {
        error = e is ToolFailure
            ? e.message
            : e is NotesFailure
            ? e.message
            : 'Unable to save. Your content is retained. Retry with a connection.';
      }
    } finally {
      if (current) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> upload() => _run(() async {
    final f = await files.pick();
    if (f == null || !current) return;
    final u = await repository.upload(f, noteLocalId());
    if (current) {
      uploads.add(u);
      changed();
    }
  });
  Future<void> remove(ReportUpload u) => _run(() async {
    await repository.discard(u.id);
    if (current) {
      uploads.remove(u);
      changed();
    }
  });
  Future<bool> submit(String title, String description) async {
    await _run(() async {
      await repository.submit(
        key: key,
        type: type,
        title: title,
        description: description,
        uploads: uploads.map((e) => e.id).toList(),
      );
      if (current) submitted = true;
    });
    return current && submitted;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!submitted && epoch == session.epoch) {
      for (final u in uploads) {
        repository.discard(u.id).catchError((Object _) {});
      }
    }
    super.dispose();
  }
}

import '../../../domain/models/note_models.dart' show NotesFailure;

import 'package:flutter/foundation.dart';

import '../../../data/repositories/lost_found_repository.dart';
import '../../../data/services/note_file_service.dart';
import '../../../domain/models/lost_found_models.dart';

class ReportDetailsViewModel extends ChangeNotifier {
  ReportDetailsViewModel(this.repository, this.files);
  final LostFoundRepository repository;
  final NoteFileService files;
  bool busy = false, _disposed = false;
  String? error;
  Future<Uint8List?> open(ReportUpload upload) async {
    if (busy) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final bytes = await repository.download(upload.id);
      if (_disposed) return null;
      if (upload.mediaType == 'application/pdf') {
        await files.openPdf(bytes);
        return null;
      }
      return bytes;
    } catch (e) {
      if (!_disposed) {
        error = e is NotesFailure
            ? e.message
            : 'Unable to open this private attachment. Please retry.';
      }
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

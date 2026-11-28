import 'package:flutter/foundation.dart';

import '../../../data/repositories/guide_repository.dart';
import '../../../domain/models/guide_models.dart';

enum GuideBookmarkStatus { unknown, loading, saved, unsaved }

/// Session-only knowledge of membership, never a persistent bookmark database.
class GuideBookmarks extends ChangeNotifier {
  GuideBookmarks(this.repository);
  final GuideRepository repository;
  final _known = <String, bool>{};
  final _pending = <String>{};
  final _errors = <String, String>{};
  final _checkingIds = <String>{};
  final _seenCursors = <String>{};
  String? _cursor;
  bool _complete = false, _disposed = false;
  int _generation = 0, mutationSerial = 0, changes = 0;
  Future<void>? _checking;
  bool pending(String id) => _pending.contains(id);
  String? error(String id) => _errors[id];
  GuideBookmarkStatus status(String id) {
    if (_checkingIds.contains(id)) return GuideBookmarkStatus.loading;
    if (_known[id] == true) return GuideBookmarkStatus.saved;
    if (_known[id] == false || _complete) return GuideBookmarkStatus.unsaved;
    return GuideBookmarkStatus.unknown;
  }

  void reset() {
    _generation++;
    mutationSerial++;
    _known.clear();
    _pending.clear();
    _errors.clear();
    _checkingIds.clear();
    _cursor = null;
    _complete = false;
    _checking = null;
    _seenCursors.clear();
    if (!_disposed) notifyListeners();
  }

  void observe(List<GuideArticleSummary> articles, int serial) {
    if (serial != mutationSerial || _disposed) return;
    for (final a in articles) {
      if (!_pending.contains(a.id)) _known[a.id] = true;
    }
    notifyListeners();
  }

  Future<void> check(String id) async {
    if (_disposed || pending(id)) return;
    if (_checking != null) {
      await _checking;
      return;
    }
    if (status(id) == GuideBookmarkStatus.saved ||
        status(id) == GuideBookmarkStatus.unsaved) {
      return;
    }
    final operation = _scan(id);
    _checking = operation;
    await operation;
    if (identical(_checking, operation)) _checking = null;
  }

  Future<void> _scan(String id) async {
    final generation = _generation;
    final serial = mutationSerial;
    _checkingIds.add(id);
    _errors.remove(id);
    notifyListeners();
    try {
      // Each user action/open performs at most three pages, never an unbounded crawl.
      for (var pageNumber = 0; pageNumber < 3 && !_complete; pageNumber++) {
        final page = await repository.bookmarks(cursor: _cursor);
        if (_disposed ||
            generation != _generation ||
            serial != mutationSerial) {
          return;
        }
        if (page.nextCursor != null && !_seenCursors.add(page.nextCursor!)) {
          throw GuideFailure.invalidResponse;
        }
        for (final a in page.items) {
          if (!_pending.contains(a.id)) _known[a.id] = true;
        }
        _cursor = page.nextCursor;
        _complete = _cursor == null;
        if (_known[id] == true) break;
      }
    } catch (error) {
      if (!_disposed && generation == _generation && serial == mutationSerial) {
        _errors[id] = error is GuideFailure
            ? error.message
            : 'Unable to check saved articles. Please retry.';
        if (error is GuideFailure && error.code == 'INVALID_REQUEST') {
          _cursor = null;
          _complete = false;
          _seenCursors.clear();
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _checkingIds.remove(id);
        notifyListeners();
      }
    }
  }

  Future<void> setSaved(String id, bool saved) async {
    if (_disposed || !_pending.add(id)) return;
    final generation = _generation;
    mutationSerial++;
    _errors.remove(id);
    notifyListeners();
    try {
      if (saved) {
        await repository.save(id);
      } else {
        await repository.remove(id);
      }
      if (_disposed || generation != _generation) return;
      _known[id] = saved;
      _cursor = null;
      _complete = false;
      _seenCursors.clear();
      changes++;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _errors[id] = error is GuideFailure
            ? error.message
            : 'Your saved articles could not be updated. Please retry.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        mutationSerial++;
        _pending.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

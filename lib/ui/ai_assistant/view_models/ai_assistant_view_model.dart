import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/ai_assistant_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/ai_conversation.dart';
import '../../../domain/models/auth_session.dart';

class AiRun {
  AiRun({
    required this.conversationId,
    required this.baseline,
    required this.baselineAttempt,
    this.question,
    this.locale,
    this.contextArticleId,
    this.regenerateUserId,
  });

  final String conversationId;
  final int baseline;
  final int baselineAttempt;
  final String? question, locale, contextArticleId, regenerateUserId;
  var abort = Completer<void>();
  final buffer = StringBuffer();
  String? requestKey;
  AiGenerationIds? ids;
  Timer? paint;
  bool connected = true;
  bool stopping = false;
  bool checking = false;
  bool canRetryDelivery = false;
  bool inferredIds = false;
  String provisional = '';

  void close() {
    connected = false;
    paint?.cancel();
    if (!abort.isCompleted) abort.complete();
  }
}

class AiAssistantViewModel extends ChangeNotifier {
  AiAssistantViewModel(this._repository, this._auth) {
    _owner = _activeOwner;
    _auth.addListener(_sessionChanged);
  }

  final AiAssistantRepository _repository;
  final AuthRepository _auth;
  final _random = Random.secure();
  final _runs = <String, AiRun>{};
  final _notices = <String, String>{};
  final _votes = <String, int>{};
  final _voting = <String>{};
  final _mutating = <String>{};
  String? _owner;
  int _epoch = 0, _selection = 0;
  bool _disposed = false;

  String? conversationId;
  String? contextArticleId;
  String draft = '';
  String? threadError, actionError, historyError;
  bool loadingThread = false, loadingOlder = false, creating = false;
  bool loadingHistory = false;
  String? _olderCursor, _historyCursor;
  final _turns = <AiTurn>[];
  final _history = <AiConversation>[];

  List<AiTurn> get turns => List.unmodifiable(_turns);
  List<AiConversation> get history => List.unmodifiable(_history);
  bool get hasOlder => _olderCursor != null;
  bool get hasMoreHistory => _historyCursor != null;
  bool get signedIn => _owner != null;
  int get sessionVersion => _epoch;
  AiRun? get run => _runs[conversationId];
  String? get generationNotice => _notices[conversationId];
  int? vote(String messageId) => _votes[messageId];
  bool voting(String messageId) => _voting.contains(messageId);
  bool mutating(String id) => _mutating.contains(id);

  String? get _activeOwner =>
      _auth.status == SessionStatus.authenticated ? _auth.user?.id : null;

  void _sessionChanged() {
    final owner = _activeOwner;
    if (_owner == owner) return;
    _owner = owner;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _epoch++;
    _selection++;
    for (final run in _runs.values) {
      run.close();
    }
    _runs.clear();
    _notices.clear();
    _votes.clear();
    _voting.clear();
    _mutating.clear();
    _turns.clear();
    _history.clear();
    _olderCursor = _historyCursor = null;
    conversationId = contextArticleId = null;
    threadError = actionError = historyError = null;
    draft = '';
    loadingThread = loadingOlder = creating = loadingHistory = false;
  }

  bool _current(int epoch) => !_disposed && _epoch == epoch && signedIn;
  bool _selected(int epoch, int selection) =>
      _current(epoch) && _selection == selection;
  bool _owns(AiRun run) =>
      !_disposed && identical(_runs[run.conversationId], run);
  void _runChanged(AiRun run) {
    if (conversationId == run.conversationId) notifyListeners();
  }

  void setDraft(String value) => draft = value;

  void resetDraft() {
    if (conversationId != null) {
      unawaited(open(null));
      return;
    }
    _selection++;
    draft = '';
    contextArticleId = null;
    actionError = null;
    notifyListeners();
  }

  void removeContext() {
    contextArticleId = null;
    actionError = null;
    notifyListeners();
  }

  Future<void> open(
    String? id, {
    String? articleId,
    bool refresh = false,
  }) async {
    if (!signedIn) return;
    if (id != conversationId || (id == null && articleId != contextArticleId)) {
      _selection++;
      conversationId = id;
      contextArticleId = articleId;
      draft = '';
      actionError = threadError = null;
      loadingThread = loadingOlder = false;
      _olderCursor = null;
      _turns.clear();
    } else if (!refresh) {
      return;
    }
    if (id == null) {
      notifyListeners();
      return;
    }
    final epoch = _epoch, selection = _selection;
    loadingThread = _turns.isEmpty && run?.connected != true;
    threadError = null;
    notifyListeners();
    try {
      final page = await _repository.turns(id);
      if (!_selected(epoch, selection)) return;
      _mergeTurns(page, initial: _turns.isEmpty);
      final active = run;
      if (active == null) {
        final turn = _turns.lastOrNull;
        final attempt = turn?.latest;
        if (turn != null && attempt?.status == AiStatus.streaming) {
          final recovered =
              AiRun(
                  conversationId: id,
                  baseline: turn.number,
                  baselineAttempt: attempt!.number,
                  regenerateUserId: turn.userId,
                )
                ..ids = AiGenerationIds(
                  attempt.generationId,
                  turn.userId,
                  attempt.id,
                )
                ..connected = false;
          _runs[id] = recovered;
          unawaited(recover());
        }
      } else if (!active.connected) {
        unawaited(recover());
      }
    } on Object catch (error) {
      if (_selected(epoch, selection)) threadError = _message(error);
    } finally {
      if (_selected(epoch, selection)) {
        loadingThread = false;
        notifyListeners();
      }
    }
  }

  Future<bool> older() async {
    final id = conversationId, cursor = _olderCursor;
    if (id == null || cursor == null || loadingOlder) return false;
    final epoch = _epoch, selection = _selection;
    loadingOlder = true;
    actionError = null;
    notifyListeners();
    try {
      final page = await _repository.turns(id, before: cursor);
      if (!_selected(epoch, selection)) return false;
      _mergeTurns(page, initial: true);
      return true;
    } on Object catch (error) {
      if (_selected(epoch, selection)) actionError = _message(error);
      return false;
    } finally {
      if (_selected(epoch, selection)) {
        loadingOlder = false;
        notifyListeners();
      }
    }
  }

  void _mergeTurns(AiPage<AiTurn> page, {required bool initial}) {
    final merged = {for (final turn in _turns) turn.userId: turn};
    for (final turn in page.items) {
      final local = merged[turn.userId];
      // A history read can race with a newer terminal SSE frame.
      if (local != null &&
          local.latest?.id == turn.latest?.id &&
          local.latest?.status != AiStatus.streaming &&
          turn.latest?.status == AiStatus.streaming) {
        continue;
      }
      if ((local?.latest?.number ?? 0) > (turn.latest?.number ?? 0)) continue;
      merged[turn.userId] = turn;
    }
    _turns
      ..clear()
      ..addAll(
        merged.values.toList()..sort((a, b) => a.number.compareTo(b.number)),
      );
    if (initial) _olderCursor = page.nextCursor;
  }

  Future<void> loadHistory({bool more = false}) async {
    if (!signedIn ||
        loadingHistory ||
        _mutating.isNotEmpty ||
        (more && _historyCursor == null)) {
      return;
    }
    final epoch = _epoch;
    loadingHistory = true;
    historyError = null;
    notifyListeners();
    try {
      final page = await _repository.conversations(
        cursor: more ? _historyCursor : null,
      );
      if (!_current(epoch)) return;
      final items = {
        if (more)
          for (final item in _history) item.id: item,
        for (final item in page.items) item.id: item,
      };
      _history
        ..clear()
        ..addAll(items.values);
      _historyCursor = page.nextCursor;
    } on Object catch (error) {
      if (_current(epoch)) historyError = _message(error);
    } finally {
      if (_current(epoch)) {
        loadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<bool> rename(String id, String title) =>
      _changeHistory(id, (epoch) async {
        if (title.trim().isEmpty || title.trim().runes.length > 160) {
          throw const AiFailure('INVALID_REQUEST');
        }
        final renamed = await _repository.rename(id, title.trim());
        if (_current(epoch)) _remember(renamed);
      });

  Future<bool> delete(String id) => _changeHistory(id, (epoch) async {
    await _repository.delete(id);
    if (!_current(epoch)) return;
    _runs.remove(id)?.close();
    _notices.remove(id);
    _history.removeWhere((item) => item.id == id);
  }, deleted: true);

  Future<bool> _changeHistory(
    String id,
    Future<void> Function(int epoch) change, {
    bool deleted = false,
  }) async {
    if (!signedIn || loadingHistory || !_mutating.add(id)) return false;
    final epoch = _epoch;
    historyError = null;
    notifyListeners();
    try {
      await change(epoch);
      if (!_current(epoch)) return false;
      if (deleted && conversationId == id) await open(null);
      return true;
    } on Object catch (error) {
      if (_current(epoch)) historyError = _message(error);
      return false;
    } finally {
      if (_current(epoch)) {
        _mutating.remove(id);
        notifyListeners();
      }
    }
  }

  void _remember(AiConversation item) {
    _history
      ..removeWhere((chat) => chat.id == item.id)
      ..insert(0, item);
  }

  Future<String?> send(String locale) async {
    final text = draft.trim();
    if (!signedIn ||
        text.isEmpty ||
        creating ||
        loadingThread ||
        threadError != null ||
        run != null) {
      return null;
    }
    if (text.runes.length > 2000 || text.contains('\u0000')) {
      actionError = 'Enter a message with at most 2,000 characters.';
      notifyListeners();
      return null;
    }
    final epoch = _epoch, selection = _selection;
    final context = contextArticleId;
    var id = conversationId;
    actionError = null;
    if (id == null) {
      creating = true;
      notifyListeners();
      try {
        final singleLine = text.replaceAll(RegExp(r'\s+'), ' ');
        final title = singleLine.runes.length <= 64
            ? singleLine
            : '${String.fromCharCodes(singleLine.runes.take(63))}…';
        final chat = await _repository.create(title: title);
        if (!_selected(epoch, selection)) return null;
        _remember(chat);
        id = conversationId = chat.id;
      } on Object catch (error) {
        if (_selected(epoch, selection)) actionError = _message(error);
        return null;
      } finally {
        if (_current(epoch)) {
          creating = false;
          notifyListeners();
        }
      }
    }
    if (draft.trim() == text) draft = '';
    final pending = AiRun(
      conversationId: id,
      baseline: _turns.lastOrNull?.number ?? 0,
      baselineAttempt: 0,
      question: text,
      locale: locale,
      contextArticleId: context,
    );
    _begin(pending);
    return id;
  }

  void regenerate() {
    final latest = _turns.lastOrNull;
    final id = conversationId;
    if (!signedIn ||
        latest == null ||
        id == null ||
        run != null ||
        loadingThread ||
        threadError != null) {
      return;
    }
    _begin(
      AiRun(
        conversationId: id,
        baseline: latest.number,
        baselineAttempt: latest.latest?.number ?? 0,
        regenerateUserId: latest.userId,
      ),
    );
  }

  void _begin(AiRun pending) {
    actionError = null;
    _notices.remove(pending.conversationId);
    _runs[pending.conversationId] = pending;
    _runChanged(pending);
    unawaited(_stream(pending));
  }

  Future<void> _stream(AiRun pending) async {
    final transport = pending.abort;
    bool active() =>
        _owns(pending) &&
        !pending.stopping &&
        identical(pending.abort, transport);
    try {
      await _repository.generate(
        conversationId: pending.conversationId,
        requestKey: pending.requestKey ??= _requestKey(),
        abort: transport.future,
        text: pending.question,
        locale: pending.locale,
        contextArticleId: pending.contextArticleId,
        regenerateUserId: pending.regenerateUserId,
        onEvent: (event) {
          if (!active()) return;
          switch (event) {
            case AiStart(:final ids):
              pending.ids = ids;
            case AiDelta(:final text):
              pending.buffer.write(text);
              if (pending.paint?.isActive != true) {
                pending.paint = Timer(const Duration(milliseconds: 45), () {
                  if (!_owns(pending) || !pending.connected) return;
                  pending.provisional = pending.buffer.toString();
                  _runChanged(pending);
                });
              }
            case AiTerminal(:final result):
              _finish(pending, result);
          }
        },
      );
    } on Object catch (error) {
      if (!active()) return;
      if (error is AiFailure &&
          (error.rejected || error.code == 'GENERATION_ACTIVE')) {
        if (conversationId == pending.conversationId && draft.isEmpty) {
          draft = pending.question ?? '';
        }
        _release(pending, error.message);
        if (error.code == 'GENERATION_ACTIVE' &&
            conversationId == pending.conversationId) {
          unawaited(open(pending.conversationId, refresh: true));
        }
        return;
      }
    }
    if (!active()) return;
    pending.provisional = pending.buffer.toString();
    pending.close();
    _runChanged(pending);
    await _recover(pending);
  }

  Future<void> stop() async {
    final pending = run;
    if (pending == null || pending.stopping) return;
    pending.stopping = true;
    pending.close();
    _runChanged(pending);
    await _recover(pending);
  }

  Future<void> recover() async {
    final pending = run;
    if (pending != null && !pending.connected) await _recover(pending);
  }

  void retryDelivery() {
    final pending = run;
    if (pending == null ||
        !pending.canRetryDelivery ||
        pending.stopping ||
        pending.checking ||
        pending.connected ||
        pending.ids != null) {
      return;
    }
    pending
      ..canRetryDelivery = false
      ..abort = Completer<void>()
      ..connected = true
      ..provisional = '';
    pending.buffer.clear();
    _runChanged(pending);
    unawaited(_stream(pending));
  }

  Future<void> _recover(AiRun pending) async {
    if (pending.checking || !_owns(pending)) return;
    pending.checking = true;
    pending.canRetryDelivery = false;
    _runChanged(pending);
    try {
      for (var attempt = 0; attempt < 3 && _owns(pending); attempt++) {
        final id = pending.conversationId;
        if (pending.ids == null) {
          final page = await _repository.turns(id);
          if (!_owns(pending)) return;
          if (conversationId == id) _mergeTurns(page, initial: _turns.isEmpty);
          final candidates = page.items
              .where(
                (turn) => pending.regenerateUserId != null
                    ? turn.userId == pending.regenerateUserId &&
                          (turn.latest?.number ?? 0) > pending.baselineAttempt
                    : turn.number > pending.baseline &&
                          turn.question == pending.question,
              )
              .toList();
          if (candidates.length == 1) {
            final turn = candidates.single;
            final reply = turn.latest;
            if (reply != null) {
              pending.ids = AiGenerationIds(
                reply.generationId,
                turn.userId,
                reply.id,
              );
              pending.inferredIds = true;
            }
          }
        }
        final ids = pending.ids;
        if (ids != null) {
          final result = pending.stopping && !pending.inferredIds
              ? await _repository.cancel(id, ids.generation)
              : await _repository.generation(id, ids.generation);
          if (!_owns(pending)) return;
          if (result.ids.generation != ids.generation) {
            throw const AiFailure('INVALID_RESPONSE');
          }
          if (result.status != AiStatus.streaming) {
            _finish(pending, result);
            return;
          }
        }
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
      if (_owns(pending) &&
          pending.ids == null &&
          pending.requestKey != null &&
          !pending.stopping) {
        // A manual retransmit reuses the request key after a successful history check.
        pending.canRetryDelivery = true;
      }
    } on Object {
      // A subsequent foreground or manual check can use the same saved IDs.
    } finally {
      if (_owns(pending)) {
        pending.checking = false;
        _runChanged(pending);
      }
    }
  }

  void _finish(AiRun pending, AiGeneration result) {
    if (!_owns(pending)) return;
    if (conversationId == pending.conversationId) {
      final index = _turns.indexWhere((turn) => turn.userId == result.ids.user);
      final existing = index < 0 ? null : _turns[index];
      final oldAttempt = existing?.attempts
          .where((a) => a.id == result.ids.assistant)
          .firstOrNull;
      final answer = AiAttempt(
        id: result.ids.assistant,
        generationId: result.ids.generation,
        number:
            oldAttempt?.number ??
            (existing?.latest?.number ?? pending.baselineAttempt) + 1,
        status: result.status,
        body: result.body,
        citations: result.citations,
      );
      final attempts = [
        ...?existing?.attempts.where((a) => a.id != answer.id),
        answer,
      ]..sort((a, b) => a.number.compareTo(b.number));
      final turn = AiTurn(
        existing?.number ?? pending.baseline + 1,
        result.ids.user,
        existing?.question ?? pending.question ?? '',
        List.unmodifiable(attempts),
      );
      if (index < 0) {
        _turns.add(turn);
        _turns.sort((a, b) => a.number.compareTo(b.number));
      } else {
        _turns[index] = turn;
      }
    }
    final notice = switch (result.status) {
      AiStatus.completed => null,
      AiStatus.cancelled => const AiFailure('AI_CANCELLED').message,
      _ => AiFailure(result.failureCode ?? 'AI_GENERATION_FAILED').message,
    };
    _release(pending, notice);
    if (conversationId == pending.conversationId) {
      unawaited(open(pending.conversationId, refresh: true));
    }
  }

  void _release(AiRun pending, String? notice) {
    pending.close();
    _runs.remove(pending.conversationId);
    if (notice != null) _notices[pending.conversationId] = notice;
    _runChanged(pending);
  }

  Future<void> feedback(String messageId, int value) async {
    final id = conversationId;
    if (id == null || !signedIn || !_voting.add(messageId)) return;
    final epoch = _epoch, selection = _selection;
    final next = _votes[messageId] == value ? null : value;
    actionError = null;
    notifyListeners();
    try {
      await _repository.feedback(id, messageId, next);
      if (!_current(epoch)) return;
      if (next == null) {
        _votes.remove(messageId);
      } else {
        _votes[messageId] = next;
      }
    } on Object catch (error) {
      if (_selected(epoch, selection)) actionError = _message(error);
    } finally {
      if (_current(epoch)) {
        _voting.remove(messageId);
        notifyListeners();
      }
    }
  }

  String _requestKey() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _message(Object error) => error is AiFailure
      ? error.message
      : const AiFailure('SERVICE_ERROR').message;

  @override
  void dispose() {
    _auth.removeListener(_sessionChanged);
    _disposed = true;
    _reset();
    super.dispose();
  }
}

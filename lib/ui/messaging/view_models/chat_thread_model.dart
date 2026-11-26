import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../../domain/models/messaging.dart';
import '../../community/view_models/community_composer_model.dart';
import 'messaging_session.dart';

class ChatPhoto {
  ChatPhoto(this.bytes, this.type);
  final Uint8List bytes;
  final String type;
  CommunityImage? uploaded;
}

class ChatThreadModel extends ChangeNotifier {
  ChatThreadModel(
    this.session,
    this.id, {
    this.referenceId,
    this.referenceKind,
  }) {
    session.addListener(_changed);
    session.focus(id);
  }
  final MessagingSession session;
  final String id;
  final photos = <ChatPhoto>[];
  String? referenceId, referenceKind;
  Conversation? conversation;
  List<ChatMessage> messages = const [];
  ChatMessage? reply, editing;
  String? next;
  Object? error, sendError;
  bool loading = false, loadingMore = false, busy = false, picking = false;
  double progress = 0;
  int? unreadBoundary, anchor;
  bool _disposed = false;
  int _generation = 0;
  String? _submittedId, _submittedText, _version, _visibility;
  DateTime? _lastTyped;
  bool _wasTyping = false;
  int _acknowledged = -1;
  final _delivered = <String>{};

  void _changed() {
    if (session.focusedThread != id) return;
    final current = session.snapshot;
    if (current != null && !current.threadAvailable) {
      _generation++;
      messages = const [];
      conversation = null;
      error = const CommunityFailure(
        'This conversation is unavailable.',
        unavailable: true,
      );
      loading = false;
      loadingMore = false;
      _publish();
      return;
    }
    if (current != null) {
      final visibilityChanged =
          _visibility != null && _visibility != current.visibility;
      if (visibilityChanged) {
        messages = const [];
        next = null;
        unreadBoundary = null;
      }
      _visibility = current.visibility;
      if (visibilityChanged ||
          current.threadVersion != _version && !loading && !loadingMore) {
        _version = current.threadVersion;
        unawaited(load(at: anchor));
      }
    }
    _publish();
  }

  Future<void> load({bool older = false, int? at}) async {
    if (older && (next == null || loading || loadingMore)) return;
    final generation = ++_generation;
    final previousCursor = next;
    if (older) {
      loadingMore = true;
    } else {
      loading = true;
    }
    error = null;
    _publish();
    try {
      final data = await session.repository.history(
        id,
        before: older ? previousCursor : null,
        anchor: at,
      );
      if (!_current(generation)) return;
      conversation = data.thread;
      unreadBoundary ??= (data.thread.unread > 0 ? data.thread.readSeq : null);
      if (at != null) anchor = at;
      if (older || at != null || messages.isEmpty || anchor != null) {
        messages = [if (older) ...messages, ...data.page.items];
        next = data.page.next;
      } else {
        // Replace the latest page, including removed entries, and retain any
        // history older than its oldest message until a deliberate refresh.
        final floor = data.page.items.lastOrNull?.seq ?? 0;
        messages = [
          ...data.page.items,
          ...messages.where((msg) => msg.seq < floor),
        ];
        if (messages.length == data.page.items.length) next = data.page.next;
      }
      if (data.thread.state == 'active' && data.page.items.isNotEmpty) {
        final received = [
          for (final item in data.page.items)
            if (_delivered.add(item.id)) item.id,
        ];
        if (received.isNotEmpty) {
          unawaited(_ack(data.page.items.first.seq, false, received));
        }
      }
    } catch (e) {
      if (_current(generation)) {
        error = e is CommunityFailure
            ? e
            : const CommunityFailure(
                'Could not read this conversation. Try again.',
              );
        if (e is CommunityFailure && e.unavailable) {
          messages = const [];
          conversation = null;
        }
      }
    } finally {
      if (_current(generation)) {
        loading = loadingMore = false;
        _publish();
      }
    }
  }

  Future<void> _ack(int seq, bool read, List<String> ids) async {
    try {
      await session.repository.object(
        'conversations/$id/ack',
        method: 'PUT',
        data: {'seq': '$seq', 'read': read, 'messages': ids},
      );
    } catch (_) {
      if (read && _acknowledged == seq) _acknowledged = -1;
      if (!read) _delivered.removeAll(ids);
    }
  }

  void markRead() {
    final newest = messages.firstOrNull?.seq;
    if (newest == null ||
        newest <= _acknowledged ||
        anchor != null ||
        conversation?.invited != false) {
      return;
    }
    _acknowledged = newest;
    unawaited(
      _ack(
        newest,
        true,
        messages.take(24).map((message) => message.id).toList(),
      ),
    );
  }

  Future<void> live() async {
    anchor = null;
    messages = const [];
    await load();
  }

  void setReply(ChatMessage? value) {
    reply = value;
    editing = null;
    _submittedId = null;
    _publish();
  }

  void edit(ChatMessage? value) {
    editing = value;
    reply = null;
    _submittedId = null;
    _publish();
  }

  void clearReference() {
    referenceKind = referenceId = null;
    _submittedId = null;
    _publish();
  }

  Future<void> pick() async {
    if (picking || busy || photos.length >= 6) return;
    picking = true;
    sendError = null;
    _publish();
    try {
      final picker = ImagePicker();
      final remaining = 6 - photos.length;
      final List<XFile> files;
      if (remaining == 1) {
        files = [
          ?await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1800,
            maxHeight: 1800,
            requestFullMetadata: false,
            imageQuality: 85,
          ),
        ];
      } else {
        files = await picker.pickMultiImage(
          limit: remaining,
          maxWidth: 1800,
          maxHeight: 1800,
          requestFullMetadata: false,
          imageQuality: 85,
        );
      }
      for (final file in files.take(remaining)) {
        if (_disposed) return;
        if (await file.length() > 8000000) {
          throw const CommunityFailure('Choose images smaller than 8 MB.');
        }
        final bytes = await file.readAsBytes();
        final type = CommunityComposerModel.imageType(bytes);
        if (type == null) {
          throw const CommunityFailure('Choose a JPEG, PNG or WebP photo.');
        }
        photos.add(ChatPhoto(bytes, type));
        _submittedId = null;
      }
    } catch (e) {
      sendError = e is CommunityFailure
          ? e
          : const CommunityFailure('Could not choose photos.');
    } finally {
      picking = false;
      _publish();
    }
  }

  void removePhoto(ChatPhoto photo) {
    photos.remove(photo);
    _submittedId = null;
    if (photo.uploaded case final image?) {
      unawaited(
        session.repository.media
            .mutate('media/${image.id}', method: 'DELETE')
            .catchError((Object _) {}),
      );
    }
    _publish();
  }

  void typing(String value) {
    final now = DateTime.now();
    final active = value.trim().isNotEmpty;
    if (conversation?.pending != false ||
        conversation?.canWrite != true ||
        (active == _wasTyping &&
            (!active ||
                (_lastTyped != null &&
                    now.difference(_lastTyped!) <
                        const Duration(seconds: 4))))) {
      return;
    }
    _lastTyped = now;
    _wasTyping = active;
    unawaited(
      session.repository
          .object(
            'conversations/$id/typing',
            method: 'PUT',
            data: {'active': active},
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  Future<bool> send(String input) async {
    final text = input.trim();
    if (busy ||
        picking ||
        (text.isEmpty && photos.isEmpty && referenceId == null)) {
      return false;
    }
    if (_submittedText != text) _submittedId = null;
    _submittedText = text;
    final messageId = _submittedId ??= CommunityRepository.newId();
    busy = true;
    progress = 0;
    sendError = null;
    _publish();
    try {
      final editTarget = editing;
      if (editTarget != null) {
        await action(editTarget, 'edit', text, refresh: false);
      } else {
        for (var i = 0; i < photos.length; i++) {
          if (_disposed) return false;
          final image = photos[i];
          image.uploaded ??= await session.repository.media.upload(
            image.bytes,
            image.type,
            (fraction) {
              progress = (i + fraction) / (photos.length + 1);
              _publish();
            },
          );
        }
        await session.repository.object(
          'conversations/$id/messages/$messageId',
          method: 'PUT',
          data: {
            'text': text,
            'images': photos.map((photo) => photo.uploaded!.id).toList(),
            'replyId': reply?.id,
            'referenceId': referenceId,
            'referenceKind': referenceKind,
          },
        );
      }
      _submittedId = _submittedText = null;
      reply = editing = null;
      photos.clear();
      referenceId = referenceKind = null;
      typing('');
      await live();
      return true;
    } catch (e) {
      sendError = e is CommunityFailure
          ? e
          : const CommunityFailure(
              'The message could not be sent. Retry when you are connected.',
            );
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> action(
    ChatMessage message,
    String action,
    Object? value, {
    bool refresh = true,
  }) async {
    await session.repository.object(
      'conversations/$id/messages/${message.id}',
      method: 'PATCH',
      data: {'action': action, 'value': value},
    );
    if (action == 'hide') {
      messages = messages.where((item) => item.id != message.id).toList();
    }
    if (refresh) await load();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    typing('');
    session.removeListener(_changed);
    session.focus(null, whenClosing: id);
    super.dispose();
  }
}

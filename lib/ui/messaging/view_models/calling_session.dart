import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../data/services/voice_media.dart';
import '../../../domain/models/calling.dart';
import '../../../domain/models/community.dart';

class CallingSession extends ChangeNotifier {
  CallingSession(this.repository);
  final MessagingRepository repository;
  late final VoiceMedia _media = VoiceMedia(
    signal: _send,
    changed: _mediaChanged,
    failed: _mediaFailed,
  );
  VoiceCall? call;
  List<VoicePeer> peers = [];
  String? user, _known, _revision, _outgoingLabel;
  String _cursor = '0';
  String? problem, notice;
  bool minimized = false, muted = false, busy = false, reconnecting = false;
  bool _visible = false,
      _disposed = false,
      _restartPending = false,
      _mediaReported = false;
  int _generation = 0, _restarts = 0;
  DateTime? localConnectedAt, _lastSnapshot;
  Timer? _next, _meter;
  Completer<void>? _cancel;
  List<dynamic>? _servers;

  bool get prepared => _media.prepared;
  bool get connected => _media.connected.isNotEmpty;
  bool get pending => call == null && _known != null;
  bool get showing => call != null || pending;
  String get title {
    final value = call;
    if (value == null) return _outgoingLabel ?? 'Voice call';
    if (value.kind == 'direct' && value.callerId == user) {
      return _outgoingLabel ??
          peers.firstOrNull?.identity?.displayName ??
          'Voice call';
    }
    return value.displayName;
  }

  bool speaking(String id) => _media.speaking.contains(id);
  bool linked(String id) => _media.connected.contains(id);

  void activate(String? account, bool visible) {
    final changed = user != account;
    if (!changed && _visible == visible) return;
    user = account;
    _visible = visible;
    if (changed) {
      _generation++;
      _clear();
      notice = null;
      unawaited(_media.reset().catchError((Object _) {}));
    }
    _kick();
    _publish();
  }

  void _kick() {
    _generation++;
    _next?.cancel();
    _cancel?.complete();
    _cancel = null;
    if (user != null && (_visible || prepared || _known != null)) {
      final generation = _generation;
      _next = Timer(Duration.zero, () => unawaited(_poll(generation)));
    }
  }

  Future<void> _poll(int generation) async {
    final cancel = Completer<void>();
    _cancel = cancel;
    var delay = const Duration(milliseconds: 300);
    try {
      final data = await repository.object(
        'calls/sync',
        query: {'call': ?_known, 'after': _cursor, 'revision': ?_revision},
        cancel: cancel.future,
      );
      if (_disposed || generation != _generation) return;
      _lastSnapshot = DateTime.now();
      reconnecting = false;
      _revision = data['revision'] as String;
      final raw = data['call'] as CommunityJson?;
      final next = raw == null ? null : VoiceCall(raw);
      if (next != null && (next.ended || !next.joined && !next.incoming)) {
        if (_known == next.id || call?.id == next.id) {
          notice = switch (next.reason ?? next.state) {
            'busy' => 'The other member is already in a call.',
            'declined' => 'Call declined',
            'missed' => 'No answer',
            'failed' => 'Call connection failed',
            'revoked' => 'Access to the call ended',
            _ => 'Call ended',
          };
        }
        _clear();
        await _media.reset();
      } else if (next == null) {
        if (call != null) {
          _clear();
          notice = 'Call is no longer available';
          await _media.reset();
        }
      } else {
        if (call?.id != next.id) {
          _cursor = '0';
          _servers = null;
          _restarts = 0;
          _mediaReported = false;
          _restartPending = false;
          localConnectedAt = null;
          minimized = false;
          if (next.incoming) {
            unawaited(
              SystemSound.play(SystemSoundType.alert).catchError((Object _) {}),
            );
          }
        }
        _known = next.id;
        call = next;
        peers = (data['peers'] as List)
            .cast<CommunityJson>()
            .map(VoicePeer.new)
            .toList();
        if (next.joined && prepared) {
          _servers ??=
              (await repository.object('calls/${next.id}/ice'))['servers']
                  as List;
          if (_disposed || generation != _generation || call?.id != next.id) {
            return;
          }
          await _media.reconcile(user!, next.epoch, peers, _servers!);
          for (final raw in (data['signals'] as List).cast<CommunityJson>()) {
            final event = VoiceSignal(raw);
            await _media.receive(event);
            _cursor = event.seq;
          }
          _meter ??= Timer.periodic(const Duration(seconds: 1), (_) {
            unawaited(_media.measure());
            _publish();
          });
        }
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      if (showing) {
        reconnecting = true;
        if (_lastSnapshot != null &&
            DateTime.now().difference(_lastSnapshot!) >
                const Duration(seconds: 24)) {
          _clear();
          notice = 'Call ended after losing the connection';
          await _media.reset().catchError((Object _) {});
        }
      }
      delay = const Duration(seconds: 2);
    } finally {
      if (!_disposed && generation == _generation) {
        _cancel = null;
        _publish();
        if (user != null && (_visible || prepared || _known != null)) {
          _next = Timer(delay, () => unawaited(_poll(generation)));
        }
      }
    }
  }

  void _clear() {
    _known = _revision = _outgoingLabel = problem = null;
    _cursor = '0';
    _servers = null;
    call = null;
    peers = [];
    minimized = muted = busy = reconnecting = _mediaReported = _restartPending =
        false;
    _restarts = 0;
    localConnectedAt = _lastSnapshot = null;
    _media.mute(false);
    _meter?.cancel();
    _meter = null;
  }

  Future<void> _prepare() async {
    if (!_visible) {
      throw const CommunityFailure('Open Balamandian to use the microphone.');
    }
    try {
      await _media.prepare();
    } catch (_) {
      throw const CommunityFailure(
        'Allow microphone access in Android settings, then try again.',
      );
    }
  }

  Future<void> start(
    String thread,
    String label, {
    String? activeId,
    List<String> invites = const [],
  }) async {
    if (busy || user == null) return;
    if (showing) {
      if (call?.thread == thread) {
        setMinimized(false);
        return;
      }
      throw const CommunityFailure('Finish your current call first.');
    }
    final account = user;
    busy = true;
    notice = problem = null;
    _publish();
    try {
      await _prepare();
      if (account != user || _disposed) return;
      final result = activeId == null
          ? await repository.object(
              'calls/start/$thread/${CommunityRepository.newId()}',
              method: 'PUT',
              data: {'invite': invites},
            )
          : await repository.object(
              'calls/$activeId/state',
              method: 'PUT',
              data: {'action': 'join'},
            );
      if (account != user || _disposed) return;
      _known = result['id'] as String;
      _outgoingLabel = label;
      _lastSnapshot = DateTime.now();
      _revision = null;
      _kick();
    } catch (_) {
      if (!showing) await _media.reset().catchError((Object _) {});
      rethrow;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> respond(String action) async {
    final value = call;
    if (value == null || busy) return;
    final account = user;
    busy = true;
    problem = null;
    _publish();
    try {
      if (action == 'join' || action == 'restart') await _prepare();
      if (account != user || call?.id != value.id || _disposed) {
        await _media.reset();
        return;
      }
      await _action(value.id, action);
      if (action == 'decline' || action == 'leave') {
        _clear();
        await _media.reset();
      }
      _revision = null;
      _kick();
    } catch (error) {
      if (!value.joined || action == 'leave') {
        await _media.reset().catchError((Object _) {});
      }
      if (action == 'leave') {
        _clear();
        notice = 'Call closed on this device';
      } else {
        problem = error is CommunityFailure
            ? error.toString()
            : 'Call request failed. Try again.';
      }
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> invite(List<String> ids) async {
    final value = call;
    if (value == null || !value.joined) return;
    await _action(value.id, 'invite', ids);
    _revision = null;
    _kick();
  }

  Future<void> _action(
    String id,
    String action, [
    List<String> invites = const [],
  ]) async {
    await repository.object(
      'calls/$id/state',
      method: 'PUT',
      data: {'action': action, if (invites.isNotEmpty) 'invite': invites},
    );
  }

  Future<void> _send(VoicePeer peer, String kind, CommunityJson data) async {
    final value = call;
    if (value == null || !value.joined) return;
    final operation = CommunityRepository.newId();
    final path = 'calls/${value.id}/signals/$operation';
    final message = {
      'to': peer.id,
      'fromEpoch': value.epoch,
      'toEpoch': peer.epoch,
      'kind': kind,
      'payload': data,
    };
    try {
      await repository.object(path, method: 'PUT', data: message);
    } catch (_) {
      if (call?.epoch == value.epoch) {
        await repository.object(path, method: 'PUT', data: message);
      }
    }
  }

  void _mediaChanged() {
    final value = call;
    if (value != null && connected) {
      localConnectedAt ??= DateTime.now();
      if (!_mediaReported) {
        _mediaReported = true;
        unawaited(
          _action(value.id, 'connected').catchError((Object _) {
            if (call?.id == value.id) _mediaReported = false;
          }),
        );
      }
    }
    _publish();
  }

  void _mediaFailed() {
    final value = call;
    if (value == null || _restartPending || busy) return;
    _restartPending = true;
    unawaited(() async {
      try {
        if (_restarts++ < 2) {
          reconnecting = true;
          _publish();
          _servers = null;
          _mediaReported = false;
          await _action(value.id, 'restart');
          _revision = null;
          _kick();
        } else {
          await _action(value.id, 'fail');
          _clear();
          await _media.reset();
          notice = 'Call connection failed';
        }
      } catch (_) {
        reconnecting = true;
      } finally {
        _restartPending = false;
        _publish();
      }
    }());
  }

  void setMuted(bool value) {
    muted = value;
    _media.mute(value);
    _publish();
  }

  void setMinimized(bool value) {
    minimized = value;
    _publish();
  }

  void dismissNotice() {
    notice = null;
    _publish();
  }

  Future<List<MediaDeviceInfo>> get audioOutputs async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await const MethodChannel('balamandian/voice_audio')
          .invokeMethod<bool>('bluetooth');
    }
    return Helper.audiooutputs;
  }

  Future<void> output(String id) => Helper.selectAudioOutput(id);
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _next?.cancel();
    _meter?.cancel();
    _cancel?.complete();
    unawaited(_media.reset().catchError((Object _) {}));
    super.dispose();
  }
}

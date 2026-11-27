import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/models/calling.dart';
import '../../domain/models/community.dart';

typedef SendVoiceSignal = Future<void> Function(
  VoicePeer peer,
  String kind,
  CommunityJson data,
);

class VoiceMedia {
  VoiceMedia({
    required this.signal,
    required this.changed,
    required this.failed,
  });
  final SendVoiceSignal signal;
  final VoidCallback changed, failed;
  static const _service = MethodChannel('balamandian/voice_audio');
  final _peers = <String, _VoiceConnection>{};
  MediaStream? _microphone;
  Future<void>? _opening;
  int _generation = 0;
  bool _muted = false;

  bool get prepared => _microphone != null;
  Set<String> get connected => {
    for (final peer in _peers.values)
      if (peer.connected) peer.identity.id,
  };
  Set<String> get speaking => {
    for (final peer in _peers.values)
      if (peer.speaking) peer.identity.id,
  };

  Future<void> prepare() {
    if (prepared) return Future.value();
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    final generation = _generation;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (android) {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    }
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    try {
      if (stream.getAudioTracks().isEmpty) {
        throw const CommunityFailure(
          'Microphone access is required for a voice call.',
        );
      }
      if (generation != _generation) {
        throw const CommunityFailure('This call is no longer available.');
      }
      if (android) await _service.invokeMethod<void>('start');
      if (generation != _generation) {
        throw const CommunityFailure('This call is no longer available.');
      }
      _microphone = stream;
      mute(_muted);
    } catch (_) {
      await _releaseStream(stream);
      if (android) {
        await _service.invokeMethod<void>('stop').catchError((Object _) {});
      }
      rethrow;
    }
  }

  void mute(bool value) {
    _muted = value;
    for (final track in _microphone?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !value;
    }
  }

  Future<void> reconcile(
    String viewer,
    String epoch,
    List<VoicePeer> peers,
    List<dynamic> servers,
  ) async {
    final stream = _microphone;
    if (stream == null) return;
    final generation = _generation;
    final desired = {
      for (final peer in peers)
        if (peer.state == 'joined') peer.id: peer,
    };
    for (final existing in _peers.values.toList()) {
      if (existing.localEpoch != epoch ||
          desired[existing.identity.id]?.epoch != existing.identity.epoch) {
        _peers.remove(existing.identity.id);
        await existing.close();
      }
    }
    for (final peer in desired.values) {
      if (generation != _generation) return;
      if (_peers.containsKey(peer.id)) continue;
      final pc = await createPeerConnection({
        'iceServers': servers,
        'sdpSemantics': 'unified-plan',
      });
      if (generation != _generation) {
        await pc.dispose();
        return;
      }
      final connection = _VoiceConnection(peer, epoch, pc);
      _peers[peer.id] = connection;
      var live = true;
      bool current() => live && identical(_peers[peer.id], connection);
      connection.onDispose = () => live = false;
      pc.onConnectionState = (state) {
        if (!current()) return;
        connection.connected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          failed();
        }
        changed();
      };
      pc.onIceCandidate = (event) {
        if (!current() ||
            event.candidate?.isNotEmpty != true ||
            event.sdpMLineIndex != 0) {
          return;
        }
        unawaited(
          signal(peer, 'candidate', {
            'candidate': event.candidate,
            'mid': event.sdpMid,
            'line': event.sdpMLineIndex,
          }).catchError((Object _) {
            if (current()) failed();
          }),
        );
      };
      try {
        for (final track in stream.getAudioTracks()) {
          await pc.addTrack(track, stream);
        }
        if (viewer.compareTo(peer.id) < 0 && current()) {
          final offer = await pc.createOffer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': false,
          });
          await pc.setLocalDescription(offer);
          if (current()) await signal(peer, 'offer', {'sdp': offer.sdp});
        }
      } catch (_) {
        if (current()) {
          _peers.remove(peer.id);
          await connection.close();
          rethrow;
        }
      }
    }
    changed();
  }

  Future<void> receive(VoiceSignal event) async {
    final peer = _peers[event.sender];
    if (peer == null ||
        peer.localEpoch != event.toEpoch ||
        peer.identity.epoch != event.fromEpoch) {
      return;
    }
    final connection = peer.connection;
    if (event.kind == 'candidate') {
      final ice = RTCIceCandidate(
        event.payload['candidate'] as String,
        event.payload['mid'] as String?,
        event.payload['line'] as int?,
      );
      if (peer.hasRemote) {
        await connection.addCandidate(ice);
      } else if (peer.pending.length < 100) {
        peer.pending.add(ice);
      }
      return;
    }
    await connection.setRemoteDescription(
      RTCSessionDescription(event.payload['sdp'] as String, event.kind),
    );
    peer.hasRemote = true;
    for (final candidate in peer.pending) {
      await connection.addCandidate(candidate);
    }
    peer.pending.clear();
    if (event.kind == 'offer') {
      final answer = await connection.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await connection.setLocalDescription(answer);
      if (identical(peer, _peers[event.sender])) {
        await signal(peer.identity, 'answer', {'sdp': answer.sdp});
      }
    }
  }

  Future<void> measure() async {
    var updated = false;
    for (final peer in _peers.values.toList()) {
      if (!peer.connected) continue;
      try {
        final reports = await peer.connection.getStats();
        final level = reports
            .where(
              (report) =>
                  report.type == 'inbound-rtp' &&
                  (report.values['kind'] == 'audio' ||
                      report.values['mediaType'] == 'audio'),
            )
            .map((report) => report.values['audioLevel'])
            .whereType<num>()
            .fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
        final speaking = level > .015;
        if (peer.speaking != speaking) {
          peer.speaking = speaking;
          updated = true;
        }
      } catch (_) {
        /* Peer closed during a sample. */
      }
    }
    if (updated) changed();
  }

  Future<void> reset() async {
    _generation++;
    final peers = _peers.values.toList();
    _peers.clear();
    final microphone = _microphone;
    _microphone = null;
    for (final peer in peers) {
      await peer.close();
    }
    if (microphone != null) await _releaseStream(microphone);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _service.invokeMethod<void>('stop').catchError((Object _) {});
    }
  }

  Future<void> _releaseStream(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }
}

class _VoiceConnection {
  _VoiceConnection(this.identity, this.localEpoch, this.connection);
  final VoicePeer identity;
  final String localEpoch;
  final RTCPeerConnection connection;
  final pending = <RTCIceCandidate>[];
  bool connected = false, speaking = false, hasRemote = false;
  VoidCallback? onDispose;
  Future<void> close() async {
    onDispose?.call();
    await connection.close();
    await connection.dispose();
  }
}

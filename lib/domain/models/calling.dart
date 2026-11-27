import 'community.dart';
import 'profile_models.dart';

class VoiceCall {
  VoiceCall(CommunityJson data)
    : id = data['id'] as String,
      thread = data['conversationId'] as String,
      kind = data['kind'] as String,
      title = data['title'] as String,
      state = data['state'] as String,
      epoch = data['epoch'] as String,
      callerId = data['callerId'] as String?,
      caller = data['caller'] == null
          ? null
          : PublicUserIdentity.fromJson(data['caller']),
      connectedAt = DateTime.tryParse(data['connectedAt']?.toString() ?? ''),
      ended = data['endedAt'] != null,
      reason = data['endReason'] as String?;

  final String id, thread, kind, title, state, epoch;
  final String? callerId, reason;
  final PublicUserIdentity? caller;
  final DateTime? connectedAt;
  final bool ended;
  bool get incoming => !ended && state == 'invited';
  bool get joined => !ended && state == 'joined';
  String get displayName =>
      kind == 'direct' ? caller?.displayName ?? 'Voice call' : title;
}

class VoicePeer {
  VoicePeer(CommunityJson data)
    : id = data['id'] as String,
      epoch = data['epoch'] as String,
      state = data['state'] as String,
      identity = data['identity'] == null
          ? null
          : PublicUserIdentity.fromJson(data['identity']);
  final String id, epoch, state;
  final PublicUserIdentity? identity;
}

class VoiceSignal {
  VoiceSignal(CommunityJson data)
    : seq = data['seq'] as String,
      sender = data['sender'] as String,
      fromEpoch = data['fromEpoch'] as String,
      toEpoch = data['toEpoch'] as String,
      kind = data['kind'] as String,
      payload = data['payload'] as CommunityJson;
  final String seq, sender, fromEpoch, toEpoch, kind;
  final CommunityJson payload;
}

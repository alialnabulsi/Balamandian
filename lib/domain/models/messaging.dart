import 'community.dart';
import 'profile_models.dart';

class Conversation {
  Conversation(CommunityJson json)
    : id = json['id'] as String,
      kind = json['kind'] as String,
      title = json['title'] as String,
      description = json['description'] as String,
      peer = json['peer'] == null
          ? null
          : PublicUserIdentity.fromJson(json['peer']),
      image = json['image'] == null
          ? null
          : CommunityImage.fromJson(json['image'] as CommunityJson),
      activity = DateTime.parse(json['activityAt'] as String).toLocal(),
      state = json['state'] as String,
      role = json['role'] as String,
      request = json['requestState'] as String,
      initiated = json['initiated'] == true,
      muted = json['muted'] == true,
      archived = json['archived'] == true,
      pinned = json['pinned'] == true,
      markedUnread = json['markedUnread'] == true,
      unread = json['unread'] as int,
      memberCount = json['memberCount'] as int,
      lastSeq = int.parse(json['lastSeq'] as String),
      readSeq = int.parse(json['readSeq'] as String),
      peerDelivered = int.parse(json['peerDelivered'] as String),
      peerRead = int.parse(json['peerRead'] as String),
      sendPolicy = json['sendPolicy'] as String,
      invitePolicy = json['invitePolicy'] as String,
      editPolicy = json['editPolicy'] as String,
      pinPolicy = json['pinPolicy'] as String,
      latest = json['latest'] as CommunityJson?;

  final String id, kind, title, description, role, state, request;
  final String sendPolicy, invitePolicy, editPolicy, pinPolicy;
  final PublicUserIdentity? peer;
  final CommunityImage? image;
  final DateTime activity;
  final bool initiated, muted, archived, pinned, markedUnread;
  final int unread, memberCount, lastSeq, readSeq, peerDelivered, peerRead;
  final CommunityJson? latest;
  bool get group => kind == 'group';
  bool get pending => request == 'pending';
  bool get invited => state == 'invited';
  bool get owner => role == 'owner';
  bool get admin => role != 'member';
  bool get canWrite =>
      !invited &&
      (pending ? initiated && lastSeq == 0 : sendPolicy == 'members' || admin);
  String get name => group ? title : peer?.displayName ?? 'Member';
  String get preview {
    final row = latest;
    if (invited) return 'Private group invitation';
    if (row == null) return 'Start the conversation';
    if (row['systemEvent'] case final String event) return event;
    final content = switch (row) {
      {'referenceKind': 'post'} => 'Shared a campus post',
      {'referenceKind': 'story'} => 'Replied to a story',
      {'text': final String value} when value.isNotEmpty => value,
      {'image': true} => 'Sent a photo',
      _ => 'New message',
    };
    return row['mine'] == true ? 'You · $content' : content;
  }
}

class ChatMessage {
  ChatMessage(CommunityJson json)
    : id = json['id'] as String,
      seq = int.parse(json['seq'] as String),
      body = json['body'] as String,
      senderId = json['senderId'] as String?,
      sender = json['sender'] == null
          ? null
          : PublicUserIdentity.fromJson(json['sender']),
      at = DateTime.parse(json['createdAt'] as String).toLocal(),
      edited = json['editedAt'] != null,
      deleted = json['deleted'] == true,
      delivered = json['delivered'] == true,
      read = json['read'] == true,
      forwarded = json['forwarded'] == true,
      pinned = json['pinned'] == true,
      systemEvent = json['systemEvent'] as String?,
      referenceKind = json['referenceKind'] as String?,
      referenceId = json['referenceId'] as String?,
      reply = json['reply'] as CommunityJson?,
      images = (json['images'] as List)
          .cast<CommunityJson>()
          .map(CommunityImage.fromJson)
          .toList(),
      reactions = (json['reactions'] as List).cast<CommunityJson>();

  final String id, body;
  final String? senderId, systemEvent, referenceId, referenceKind;
  final PublicUserIdentity? sender;
  final DateTime at;
  final int seq;
  final bool edited, deleted, forwarded, pinned;
  final bool delivered, read;
  final CommunityJson? reply;
  final List<CommunityImage> images;
  final List<CommunityJson> reactions;
  bool get withinEditWindow =>
      DateTime.now().difference(at) <= const Duration(minutes: 15);
}

class ChatHistory {
  ChatHistory(CommunityJson json)
    : thread = Conversation(json['thread'] as CommunityJson),
      page = CommunityPage.fromJson(json, ChatMessage.new);
  final Conversation thread;
  final CommunityPage<ChatMessage> page;
}

class ChatSync {
  ChatSync(CommunityJson json)
    : revision = json['revision'] as String,
      version = json['version'] as String,
      visibility = json['visibility'] as String? ?? '',
      threadVersion = json['threadVersion'] as String?,
      count = json['unread'] as int,
      typing = (json['typing'] as List).cast<String>(),
      online = json['online'] == true,
      threadAvailable = json['threadAvailable'] == true,
      lastSeen = DateTime.tryParse(json['lastSeen'] as String? ?? '')
          ?.toLocal();
  final String revision, version, visibility;
  final String? threadVersion;
  final int count;
  final List<String> typing;
  final bool online, threadAvailable;
  final DateTime? lastSeen;
}

class ChatMember {
  ChatMember(CommunityJson json)
    : identity = PublicUserIdentity.fromJson(json['identity']),
      role = json['role'] as String,
      state = json['state'] as String;
  final PublicUserIdentity identity;
  final String role, state;
}

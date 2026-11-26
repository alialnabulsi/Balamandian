import 'package:flutter/foundation.dart';

import 'profile_models.dart';

typedef CommunityJson = Map<String, dynamic>;

@immutable
class CommunityPage<T> {
  const CommunityPage(this.items, this.next);
  final List<T> items;
  final String? next;
  factory CommunityPage.fromJson(
    CommunityJson json,
    T Function(CommunityJson) parse,
  ) => CommunityPage(
    List.unmodifiable((json['items'] as List).cast<CommunityJson>().map(parse)),
    json['next'] as String?,
  );
}

@immutable
class CommunityImage {
  const CommunityImage(this.id, this.width, this.height);
  final String id;
  final int width, height;
  factory CommunityImage.fromJson(CommunityJson json) => CommunityImage(
    json['id'] as String,
    json['width'] as int,
    json['height'] as int,
  );
}

@immutable
class CommunityEntry {
  const CommunityEntry({
    required this.id,
    required this.kind,
    required this.caption,
    required this.author,
    required this.createdAt,
    required this.media,
    this.expiresAt,
    this.isOwn = false,
    this.archived = false,
    this.seen = false,
    this.liked = false,
    this.saved = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.canComment = true,
    this.canLike = true,
  });
  final String id, kind, caption;
  final PublicUserIdentity author;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<CommunityImage> media;
  final bool isOwn, archived, seen, liked, saved, canComment, canLike;
  final int likeCount, commentCount;
  bool get isStory => kind == 'story';
  factory CommunityEntry.fromJson(CommunityJson json) => CommunityEntry(
    id: json['id'] as String,
    kind: json['kind'] as String,
    caption: json['caption'] as String,
    author: PublicUserIdentity.fromJson(json['author']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: switch (json['expiresAt']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
    media: List.unmodifiable(
      (json['media'] as List).cast<CommunityJson>().map(
        CommunityImage.fromJson,
      ),
    ),
    isOwn: json['isOwn'] == true,
    archived: json['archived'] == true,
    seen: json['seen'] == true,
    liked: json['liked'] == true,
    saved: json['saved'] == true,
    likeCount: json['likeCount'] as int,
    commentCount: json['commentCount'] as int,
    canComment: json['canComment'] == true,
    canLike: json['canLike'] == true,
  );
  CommunityEntry withInteraction({bool? liked, bool? saved, bool? seen}) =>
      CommunityEntry(
        id: id,
        kind: kind,
        caption: caption,
        author: author,
        createdAt: createdAt,
        expiresAt: expiresAt,
        media: media,
        isOwn: isOwn,
        archived: archived,
        seen: seen ?? this.seen,
        liked: liked ?? this.liked,
        saved: saved ?? this.saved,
        likeCount:
            likeCount +
            (liked == null || liked == this.liked
                ? 0
                : liked
                ? 1
                : -1),
        commentCount: commentCount,
        canComment: canComment,
        canLike: canLike,
      );
}

@immutable
class CommunityComment {
  CommunityComment.fromJson(CommunityJson json)
    : id = json['id'] as String,
      text = json['body'] as String,
      author = PublicUserIdentity.fromJson(json['author']),
      createdAt = DateTime.tryParse(json['createdAt'] as String? ?? ''),
      isOwn = json['isOwn'] == true,
      liked = json['liked'] == true,
      likes = json['likeCount'] as int,
      replies = json['replyCount'] as int;
  final String id, text;
  final PublicUserIdentity author;
  final DateTime? createdAt;
  final bool isOwn, liked;
  final int likes, replies;
}

@immutable
class CommunityActivity {
  CommunityActivity.fromJson(CommunityJson json)
    : id = json['id'] as String,
      kind = json['kind'] as String,
      entryId = json['entryId'] as String?,
      conversationId = json['conversationId'] as String?,
      actor = PublicUserIdentity.fromJson(json['actor']),
      preview = switch (json['preview']) {
        final CommunityJson image => CommunityImage.fromJson(image),
        _ => null,
      },
      time = DateTime.parse(json['updatedAt'] as String),
      read = json['read'] == true,
      events = json['events'] as int;
  final String id, kind;
  final String? entryId, conversationId;
  final PublicUserIdentity actor;
  final CommunityImage? preview;
  final DateTime time;
  final bool read;
  final int events;
}

@immutable
class CommunityInbox {
  CommunityInbox.fromJson(CommunityJson json)
    : page = CommunityPage.fromJson(json, CommunityActivity.fromJson),
      unread = json['unread'] as int,
      revision = json['revision'] as String,
      visibility = json['visibility'] as String?;
  final CommunityPage<CommunityActivity> page;
  final int unread;
  final String revision;
  final String? visibility;
}

class CommunityFailure implements Exception {
  const CommunityFailure(
    this.message, {
    this.offline = false,
    this.unavailable = false,
  });
  final String message;
  final bool offline, unavailable;
  @override
  String toString() => message;
}

import '../../domain/models/community.dart';
import '../../domain/models/messaging.dart';
import '../services/community_api_service.dart';
import 'auth_repository.dart';
import 'community_repository.dart';

class MessagingRepository {
  MessagingRepository(this._api, this._auth, this.media);
  final CommunityApiService _api;
  final AuthRepository _auth;
  final CommunityRepository media;
  String? get userId => _auth.user?.id;

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    CommunityJson? data,
    Map<String, String>? query,
    Future<void>? cancel,
  }) => _auth.withSession(
    (token) => _api.json(
      token,
      method,
      path,
      data: data,
      query: query,
      cancel: cancel,
    ),
  );

  Future<CommunityJson> object(
    String path, {
    String method = 'GET',
    CommunityJson? data,
    Map<String, String>? query,
    Future<void>? cancel,
  }) async => await _request(
    path,
    method: method,
    data: data,
    query: query,
    cancel: cancel,
  ) as CommunityJson;

  Future<CommunityPage<Conversation>> conversations({
    String mode = 'inbox',
    String? cursor,
    String search = '',
  }) async => CommunityPage.fromJson(
    await object(
      'conversations',
      query: {'mode': mode, 'cursor': ?cursor, 'q': search},
    ),
    Conversation.new,
  );

  Future<ChatHistory> history(
    String id, {
    String? before,
    String? search,
    String? filter,
    int? anchor,
  }) async => ChatHistory(
    await object(
      'conversations/$id/messages',
      query: {
        'before': ?before,
        'q': ?search,
        'filter': ?filter,
        if (anchor != null) 'anchor': '$anchor',
      },
    ),
  );

  Future<Conversation> thread(String id) async =>
      Conversation(await object('conversations/$id'));

  Future<List<ChatMember>> members(String id) async =>
      (await _request('conversations/$id/members') as List)
          .cast<CommunityJson>()
          .map(ChatMember.new)
          .toList();

  Future<String> direct(String peer) async =>
      (await object('direct/$peer', method: 'PUT'))['id'] as String;

  Future<ChatSync> sync(
    String? revision,
    String? thread,
    Future<void> cancel,
  ) async => ChatSync(
    await object(
      'sync',
      query: {'revision': ?revision, 'thread': ?thread},
      cancel: cancel,
    ),
  );

  void dispose() => _api.close();
}

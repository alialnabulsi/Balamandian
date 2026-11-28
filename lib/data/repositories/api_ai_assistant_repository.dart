import '../../domain/models/ai_conversation.dart';
import '../services/ai_assistant_api_service.dart';
import 'ai_assistant_repository.dart';
import 'auth_repository.dart';

class ApiAiAssistantRepository implements AiAssistantRepository {
  const ApiAiAssistantRepository(this.api, this.auth);

  final AiAssistantApiService api;
  final AuthRepository auth;

  static const _conversations = '/conversations';
  String _chat(String id) => '$_conversations/${Uri.encodeComponent(id)}';

  Future<AiJson> _request(
    String method,
    String path, {
    Map<String, String>? query,
    AiJson? body,
  }) => auth.withSession(
    (token) => api.json(token, method, path, query: query, body: body),
  );

  @override
  Future<AiConversation> create({String? title}) async =>
      AiConversation.fromJson(
        await _request('POST', _conversations, body: {'title': ?title}),
      );

  @override
  Future<AiPage<AiConversation>> conversations({String? cursor}) async =>
      AiPage.fromJson(
        await _request('GET', _conversations, query: {'cursor': ?cursor}),
        AiConversation.fromJson,
      );

  @override
  Future<AiConversation> rename(String conversationId, String title) async =>
      AiConversation.fromJson(
        await _request('PATCH', _chat(conversationId), body: {'title': title}),
      );

  @override
  Future<void> delete(String conversationId) async =>
      await _request('DELETE', _chat(conversationId));

  @override
  Future<AiPage<AiTurn>> turns(String conversationId, {String? before}) async =>
      AiPage.fromJson(
        await _request(
          'GET',
          '${_chat(conversationId)}/messages',
          query: {'before': ?before},
        ),
        AiTurn.fromJson,
      );

  @override
  Future<AiGeneration> generation(
    String conversationId,
    String generationId,
  ) async => AiGeneration.fromJson(
    await _request(
      'GET',
      '${_chat(conversationId)}/generations/${Uri.encodeComponent(generationId)}',
    ),
  );

  @override
  Future<AiGeneration> cancel(
    String conversationId,
    String generationId,
  ) async => AiGeneration.fromJson(
    await _request(
      'POST',
      '${_chat(conversationId)}/generations/${Uri.encodeComponent(generationId)}:cancel',
      body: {},
    ),
  );

  @override
  Future<void> feedback(
    String conversationId,
    String assistantId,
    int? vote,
  ) async => await _request(
    vote == null ? 'DELETE' : 'PUT',
    '${_chat(conversationId)}/messages/${Uri.encodeComponent(assistantId)}/feedback',
    body: vote == null ? null : {'vote': vote},
  );

  @override
  Future<void> generate({
    required String conversationId,
    required String requestKey,
    required Future<void> abort,
    required void Function(AiStreamEvent) onEvent,
    String? text,
    String? locale,
    String? contextArticleId,
    String? regenerateUserId,
  }) => auth.withSession(
    (token) => api.generate(
      token,
      regenerateUserId == null
          ? '${_chat(conversationId)}/messages:stream'
          : '${_chat(conversationId)}/messages/${Uri.encodeComponent(regenerateUserId)}:regenerate',
      key: requestKey,
      abort: abort,
      onEvent: onEvent,
      body: regenerateUserId != null
          ? {}
          : {
              'text': text!,
              'locale': locale!,
              'contextArticleId': ?contextArticleId,
            },
    ),
  );
}

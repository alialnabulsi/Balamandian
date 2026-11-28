import '../../domain/models/ai_conversation.dart';

abstract interface class AiAssistantRepository {
  Future<AiConversation> create({String? title});
  Future<AiPage<AiConversation>> conversations({String? cursor});
  Future<AiConversation> rename(String conversationId, String title);
  Future<void> delete(String conversationId);
  Future<AiPage<AiTurn>> turns(String conversationId, {String? before});
  Future<AiGeneration> generation(String conversationId, String generationId);
  Future<AiGeneration> cancel(String conversationId, String generationId);
  Future<void> feedback(String conversationId, String assistantId, int? vote);

  Future<void> generate({
    required String conversationId,
    required String requestKey,
    required Future<void> abort,
    required void Function(AiStreamEvent) onEvent,
    String? text,
    String? locale,
    String? contextArticleId,
    String? regenerateUserId,
  });
}

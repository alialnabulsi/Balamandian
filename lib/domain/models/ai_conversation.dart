import 'guide_article_ref.dart';

typedef AiJson = Map<String, dynamic>;

final aiIdentifier = RegExp(
  r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class AiPage<T> {
  const AiPage(this.items, this.nextCursor);

  factory AiPage.fromJson(AiJson json, T Function(AiJson) read) => AiPage(
    List.unmodifiable((json['items'] as List).cast<AiJson>().map(read)),
    json['nextCursor'] as String?,
  );

  final List<T> items;
  final String? nextCursor;
}

class AiConversation {
  const AiConversation(this.id, this.title, this.updatedAt);

  factory AiConversation.fromJson(AiJson json) => AiConversation(
    json['conversationId'] as String,
    json['title'] as String,
    DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String title;
  final DateTime updatedAt;
}

enum AiAvailability { current, updated, unavailable }

class AiCitation {
  const AiCitation(this.article, this.heading, this.availability, this.source);

  factory AiCitation.fromJson(AiJson json) {
    final availability = AiAvailability.values.byName(
      json['availability'] as String,
    );
    final source = json['source'] as AiJson?;
    return AiCitation(
      GuideArticleRef(
        articleId: json['articleId'] as String,
        title: json['title'] as String,
        version: json['version'] as int,
      ),
      json['heading'] as String?,
      availability,
      availability == AiAvailability.unavailable || source == null
          ? null
          : AiSource(
              source['label'] as String,
              safeAiUrl(source['url'] as String),
            ),
    );
  }

  final GuideArticleRef article;
  final String? heading;
  final AiAvailability availability;
  final AiSource? source;
}

class AiSource {
  const AiSource(this.label, this.url);

  final String label;
  final Uri? url;
}

Uri? safeAiUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !value.contains(RegExp(r'[\x00-\x20\x7f\\]'))
      ? uri
      : null;
}

enum AiStatus { streaming, completed, failed, cancelled }

class AiGenerationIds {
  const AiGenerationIds(this.generation, this.user, this.assistant);

  factory AiGenerationIds.fromJson(AiJson json) => AiGenerationIds(
    json['generationId'] as String,
    json['userMessageId'] as String,
    json['assistantMessageId'] as String,
  );

  final String generation;
  final String user;
  final String assistant;
}

class AiGeneration {
  const AiGeneration(
    this.ids,
    this.status,
    this.body,
    this.citations,
    this.failureCode,
  );

  factory AiGeneration.fromJson(AiJson json) => AiGeneration(
    AiGenerationIds.fromJson(json),
    AiStatus.values.byName(json['status'] as String),
    json['body'] as String?,
    aiCitations(json),
    json['failureCode'] as String?,
  );

  final AiGenerationIds ids;
  final AiStatus status;
  final String? body;
  final List<AiCitation> citations;
  final String? failureCode;
}

List<AiCitation> aiCitations(AiJson json) => List.unmodifiable(
  (json['citations'] as List).cast<AiJson>().map(AiCitation.fromJson),
);

class AiAttempt {
  const AiAttempt({
    required this.id,
    required this.generationId,
    required this.number,
    required this.status,
    this.body,
    this.citations = const [],
  });

  factory AiAttempt.fromJson(AiJson json) => AiAttempt(
    id: json['messageId'] as String,
    generationId: json['generationId'] as String,
    number: json['attemptNo'] as int,
    status: AiStatus.values.byName(json['status'] as String),
    body: json['body'] as String?,
    citations: aiCitations(json),
  );

  final String id;
  final String generationId;
  final int number;
  final AiStatus status;
  final String? body;
  final List<AiCitation> citations;
}

class AiTurn {
  const AiTurn(this.number, this.userId, this.question, this.attempts);

  factory AiTurn.fromJson(AiJson json) {
    final user = json['user'] as AiJson;
    return AiTurn(
      json['turnNo'] as int,
      user['messageId'] as String,
      user['body'] as String,
      List.unmodifiable(
        (json['assistantAttempts'] as List).cast<AiJson>().map(
          AiAttempt.fromJson,
        ),
      ),
    );
  }

  final int number;
  final String userId;
  final String question;
  final List<AiAttempt> attempts;

  AiAttempt? get latest => attempts.lastOrNull;
  AiAttempt? get answer => attempts.reversed
      .where((a) => a.status == AiStatus.completed)
      .firstOrNull;
}

sealed class AiStreamEvent {
  const AiStreamEvent();
}

class AiStart extends AiStreamEvent {
  const AiStart(this.ids, {this.replay = false});
  final AiGenerationIds ids;
  final bool replay;
}

class AiDelta extends AiStreamEvent {
  const AiDelta(this.text);
  final String text;
}

class AiTerminal extends AiStreamEvent {
  const AiTerminal(this.result);
  final AiGeneration result;
}

class AiFailure implements Exception {
  const AiFailure(this.code, {this.httpStatus, this.retryAfter});

  final String code;
  final int? httpStatus;
  final Duration? retryAfter;

  bool get rejected => switch (httpStatus) {
    400 || 403 || 404 || 422 || 429 => true,
    409 => code == 'IDEMPOTENCY_CONFLICT',
    _ => false,
  };

  String get message => switch (code) {
    'OFFLINE' =>
      'Couldn’t reach Balamandian. Check your connection and try again.',
    'RATE_LIMITED' || 'AI_PROVIDER_LIMIT' =>
      retryAfter == null
          ? 'The assistant is at its usage limit. Try again in a little while.'
          : 'The assistant is at its usage limit. Try again in about ${retryAfter!.inSeconds} seconds.',
    'AI_BUDGET_UNAVAILABLE' ||
    'AI_UNAVAILABLE' ||
    'AI_PROVIDER_AUTH' ||
    'AI_SHUTDOWN' => 'Answer generation is temporarily unavailable.',
    'CONTEXT_UNAVAILABLE' => 'This Guide article is no longer available. Remove the article to ask without it.',
    'AI_SOURCE_CHANGED' =>
      'A source changed during this answer. Try generating it again.',
    'AI_TIMEOUT' =>
      'The assistant ran out of time. You can generate the answer again.',
    'AI_CANCELLED' => 'Generation stopped.',
    'AI_CITATION_INVALID' =>
      'The assistant couldn’t verify the sources for this answer.',
    'GENERATION_ACTIVE' =>
      'This conversation already has an answer in progress.',
    'INVALID_REQUEST' => 'Check your text and try again.',
    _ when httpStatus == 404 =>
      'This conversation or answer is no longer available.',
    _ => 'Something went wrong with the assistant. Try again.',
  };
}

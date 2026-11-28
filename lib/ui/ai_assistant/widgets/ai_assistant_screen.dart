import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/external_url_service.dart';
import '../../../domain/models/ai_conversation.dart';
import '../../../routing/guide_ai_links.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/navigation/bottom_chrome_scope.dart';
import '../view_models/ai_assistant_view_model.dart';
import 'ai_composer.dart';
import 'ai_header.dart';
import 'ai_history_sheet.dart';
import 'ai_sources.dart';
import 'ai_text_direction.dart';
import 'ai_timeline.dart';
import 'ai_welcome.dart';

GoRoute aiAssistantRoute({
  required AiAssistantViewModel model,
  required ExternalUrlService externalUrls,
  required bool guideAvailable,
}) {
  Widget screen(BuildContext context, GoRouterState state) {
    final id = state.pathParameters['conversationId'];
    if (id != null && !aiIdentifier.hasMatch(id)) {
      return Center(
        child: ContentState(
          title: 'Conversation unavailable',
          message: 'Open a conversation from your history.',
          icon: Icons.chat_bubble_outline_rounded,
          onRetry: () => context.go(aiLocation()),
        ),
      );
    }
    final article = state.uri.queryParameters['articleId'];
    return AiAssistantScreen(
      model: model,
      externalUrls: externalUrls,
      conversationId: id?.toLowerCase(),
      articleId: article != null && aiIdentifier.hasMatch(article)
          ? article.toLowerCase()
          : null,
      guideAvailable: guideAvailable,
    );
  }

  return GoRoute(
    path: 'ai',
    builder: (context, state) => state.uri.path == '/ai'
        ? screen(context, state)
        : const SizedBox.shrink(),
    routes: [GoRoute(path: 'conversations/:conversationId', builder: screen)],
  );
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    required this.model,
    required this.externalUrls,
    this.conversationId,
    this.articleId,
    this.guideAvailable = false,
    this.suggestions = aiSuggestedQuestions,
  });

  final AiAssistantViewModel model;
  final ExternalUrlService externalUrls;
  final String? conversationId, articleId;
  final bool guideAvailable;
  final List<String> suggestions;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final AppLifecycleListener _lifecycle;
  bool _opened = false;
  late int _sessionVersion;

  AiAssistantViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    _sessionVersion = model.sessionVersion;
    model.addListener(_syncDraft);
    _lifecycle = AppLifecycleListener(onResume: _resume);
    _openRoute(refresh: true);
  }

  @override
  void didUpdateWidget(covariant AiAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.articleId != widget.articleId) {
      _openRoute();
    }
  }

  void _openRoute({bool refresh = false}) {
    _opened = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        model.open(
          widget.conversationId,
          articleId: widget.articleId,
          refresh: refresh,
        ),
      );
      _syncDraft();
      setState(() => _opened = true);
    });
  }

  void _resume() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final current = model.conversationId;
    if (current != null && model.run?.connected != true) {
      unawaited(model.open(current, refresh: true));
    }
  }

  void _syncDraft() {
    if (_sessionVersion != model.sessionVersion) {
      _sessionVersion = model.sessionVersion;
      if (model.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && model.signedIn) context.go(aiLocation());
        });
      }
    }
    if (_controller.text == model.draft) return;
    _controller.value = TextEditingValue(
      text: model.draft,
      selection: TextSelection.collapsed(offset: model.draft.length),
    );
  }

  void _suggest(String suggestion) {
    model.setDraft(suggestion);
    _syncDraft();
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final before = widget.conversationId;
    final locale = aiLocale(_controller.text, Localizations.localeOf(context));
    final id = await model.send(locale);
    if (!mounted || id == null) return;
    _focus.unfocus();
    if (id != before) context.go(aiConversationLocation(id));
  }

  void _new() {
    _focus.unfocus();
    model.resetDraft();
    context.go(aiLocation());
  }

  Future<void> _history() async {
    _focus.unfocus();
    final session = model.sessionVersion;
    unawaited(model.loadHistory());
    final choice = await showModalBottomSheet<AiHistorySelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AiHistorySheet(model: model, session: session),
    );
    if (!mounted || choice == null || model.sessionVersion != session) return;
    if (choice.id case final id?) {
      if (widget.conversationId == id) {
        unawaited(model.open(id, refresh: true));
      } else {
        context.go(aiConversationLocation(id));
      }
    } else {
      _new();
    }
  }

  void _citation(AiCitation citation) {
    final session = model.sessionVersion;
    final routeContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: model,
        builder: (context, _) => model.sessionVersion != session
            ? const SizedBox.shrink()
            : AiSourceDetails(
                citation: citation,
                onExternal: _external,
                onGuide: widget.guideAvailable
                    ? (article) {
                        if (mounted && model.sessionVersion == session) {
                          routeContext.push(guideCitationLocation(article));
                        }
                      }
                    : null,
              ),
      ),
    );
  }

  Future<void> _external(Uri uri) async {
    if (!model.signedIn || safeAiUrl(uri.toString()) == null) return;
    if (!await widget.externalUrls.launch(uri) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t open this link.')));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    model.removeListener(_syncDraft);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (!_opened || !model.signedIn) return const SizedBox.expand();
      final colors = Theme.of(context).colorScheme;
      final turns = model.turns;
      final run = model.run;
      final error = model.threadError;
      return Material(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AiHeader(onNew: _new, onHistory: _history),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: model.loadingThread && turns.isEmpty && run == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Loading conversation',
                          ),
                        )
                      : error != null && turns.isEmpty && run == null
                      ? Center(
                          child: ContentState(
                            title: 'Couldn’t open conversation',
                            message: error,
                            icon: Icons.cloud_off_outlined,
                            onRetry: () => model.open(
                              widget.conversationId,
                              refresh: true,
                            ),
                          ),
                        )
                      : turns.isEmpty &&
                            run == null &&
                            model.generationNotice == null
                      ? AiWelcome(
                          onSuggestion: _suggest,
                          suggestions: widget.suggestions,
                        )
                      : AiTimeline(
                          key: ValueKey(model.conversationId),
                          model: model,
                          turns: turns,
                          onCitation: _citation,
                          onLink: _external,
                        ),
                ),
              ),
            ),
            if (error != null && (turns.isNotEmpty || run != null))
              AiThreadNotice(
                message: error,
                onRetry: () => model.open(widget.conversationId, refresh: true),
              ),
            if (model.actionError case final message?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(message, style: TextStyle(color: colors.error)),
                ),
              ),
            if (model.creating)
              const LinearProgressIndicator(
                semanticsLabel: 'Starting conversation',
                minHeight: 2,
              ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AiComposer(
                    controller: _controller,
                    focus: _focus,
                    onChanged: model.setDraft,
                    onSend: _send,
                    onStop: model.stop,
                    onRemoveContext: model.removeContext,
                    hasContext: model.contextArticleId != null,
                    working: run?.connected == true,
                    canStop: run?.stopping != true,
                    canSend:
                        run == null &&
                        !model.creating &&
                        !model.loadingThread &&
                        error == null,
                    reserveQuickAction:
                        BottomChromeScope.of(context) > 0 &&
                        MediaQuery.sizeOf(context).width < 880,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

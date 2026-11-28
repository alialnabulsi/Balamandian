import 'package:flutter/material.dart';

import '../../../domain/models/ai_conversation.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/ai_assistant_view_model.dart';
import 'ai_text_direction.dart';

class AiHistorySheet extends StatelessWidget {
  const AiHistorySheet({super.key, required this.model, required this.session});

  final AiAssistantViewModel model;
  final int session;

  Future<void> _rename(BuildContext context, AiConversation item) async {
    final title = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => ListenableBuilder(
        listenable: model,
        builder: (_, _) => model.sessionVersion == session
            ? _RenameConversation(item.title)
            : const SizedBox.shrink(),
      ),
    );
    if (title != null && context.mounted && model.sessionVersion == session) {
      await model.rename(item.id, title);
    }
  }

  Future<void> _delete(BuildContext context, AiConversation item) async {
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This removes the conversation and its saved messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted || model.sessionVersion != session) {
      return;
    }
    final wasSelected = model.conversationId == item.id;
    if (await model.delete(item.id) && wasSelected && context.mounted) {
      Navigator.pop(context, const AiHistorySelection(null));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (model.sessionVersion != session) return const SizedBox.shrink();
      final colors = Theme.of(context).colorScheme;
      final items = model.history;
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conversation history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'New chat',
                      onPressed: () => Navigator.pop(
                        context,
                        const AiHistorySelection(null),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                    ),
                    IconButton(
                      tooltip: 'Close history',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (model.historyError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: () => model.loadHistory(),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: model.loadingHistory
                            ? const CircularProgressIndicator(
                                semanticsLabel: 'Loading conversations',
                              )
                            : model.historyError != null
                            ? const SizedBox.shrink()
                            : const ContentState(
                                title: 'No conversations yet',
                                message: 'Your chats will appear here after you send a question.',
                                icon: Icons.history_rounded,
                                compact: true,
                              ),
                      )
                    : ListView.builder(
                        itemCount: items.length + 1,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return Center(
                              child: model.loadingHistory
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        semanticsLabel: 'Loading conversations',
                                      ),
                                    )
                                  : model.hasMoreHistory
                                  ? TextButton(
                                      onPressed: () =>
                                          model.loadHistory(more: true),
                                      child: const Text(
                                        'Load more conversations',
                                      ),
                                    )
                                  : null,
                            );
                          }
                          final item = items[index];
                          return _ConversationTile(
                            item: item,
                            selected: model.conversationId == item.id,
                            busy:
                                model.loadingHistory || model.mutating(item.id),
                            onOpen: () => Navigator.pop(
                              context,
                              AiHistorySelection(item.id),
                            ),
                            onRename: () => _rename(context, item),
                            onDelete: () => _delete(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AiHistorySelection {
  const AiHistorySelection(this.id);
  final String? id;
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final AiConversation item;
  final bool selected, busy;
  final VoidCallback onOpen, onRename, onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: colors.surfaceContainer,
      leading: const Icon(Icons.chat_bubble_outline_rounded),
      title: Text(
        item.title,
        textDirection: aiTextDirection(item.title),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        MaterialLocalizations.of(context)
            .formatMediumDate(item.updatedAt.toLocal()),
      ),
      onTap: busy ? null : onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: 'Conversation options',
        enabled: !busy,
        onSelected: (action) => action == 'rename' ? onRename() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _RenameConversation extends StatefulWidget {
  const _RenameConversation(this.title);
  final String title;

  @override
  State<_RenameConversation> createState() => _RenameConversationState();
}

class _RenameConversationState extends State<_RenameConversation> {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _controller,
    builder: (context, value, _) {
      final title = value.text.trim();
      final valid = title.isNotEmpty && title.runes.length <= 160;
      return AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 160,
          textDirection: aiTextDirection(title),
          onSubmitted: (_) {
            if (valid) Navigator.pop(context, title);
          },
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: valid ? () => Navigator.pop(context, title) : null,
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

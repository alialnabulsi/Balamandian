import 'package:flutter/material.dart';

import '../../core/ui/form_message.dart';
import '../view_models/chat_thread_model.dart';
import 'chat_bubble.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.model,
    required this.text,
    required this.focus,
    required this.onSend,
    required this.onClear,
  });
  final ChatThreadModel model;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onSend, onClear;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (model.sendError != null)
                FormMessage(model.sendError.toString()),
              if (model.busy && model.photos.isNotEmpty)
                LinearProgressIndicator(
                  value: model.progress,
                  semanticsLabel: 'Uploading attachments',
                ),
              if (model.reply case final reply?)
                ChatContextStrip(
                  icon: Icons.reply_rounded,
                  title: 'Reply to ${reply.sender?.displayName ?? 'message'}',
                  detail: reply.body.isEmpty ? 'Attachment' : reply.body,
                  onClear: model.busy ? null : onClear,
                ),
              if (model.editing case final message?)
                ChatContextStrip(
                  icon: Icons.edit_outlined,
                  title: 'Editing message',
                  detail: message.body,
                  onClear: model.busy ? null : onClear,
                ),
              if (model.referenceKind == 'story')
                ChatContextStrip(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Replying to story',
                  onClear: model.busy ? null : onClear,
                ),
              if (model.photos.isNotEmpty)
                SizedBox(
                  height: 66,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: model.photos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) => ChatDraftThumbnail(
                      photo: model.photos[index],
                      index: index,
                      remove: model.busy
                          ? null
                          : () => model.removePhoto(model.photos[index]),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (model.conversation?.pending == false &&
                      model.editing == null)
                    IconButton(
                      tooltip: 'Attach photos',
                      onPressed:
                          model.busy ||
                              model.picking ||
                              model.photos.length >= 6
                          ? null
                          : model.pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  Expanded(
                    child: TextField(
                      controller: text,
                      focusNode: focus,
                      readOnly: model.busy,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: model.typing,
                      decoration: InputDecoration(
                        hintText: model.referenceKind == 'story'
                            ? 'Reply to story'
                            : 'Write a message',
                        counterText: '',
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  ValueListenableBuilder(
                    valueListenable: text,
                    builder: (context, value, _) => IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                      tooltip: model.busy
                          ? 'Sending'
                          : model.editing != null
                          ? 'Save edit'
                          : model.sendError != null
                          ? 'Retry send'
                          : 'Send message',
                      onPressed:
                          model.busy ||
                              model.picking ||
                              (value.text.trim().isEmpty &&
                                  model.photos.isEmpty)
                          ? null
                          : onSend,
                      icon: model.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              model.editing != null
                                  ? Icons.check_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 21,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDraftThumbnail extends StatelessWidget {
  const ChatDraftThumbnail({
    super.key,
    required this.photo,
    required this.index,
    required this.remove,
  });
  final ChatPhoto photo;
  final int index;
  final VoidCallback? remove;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 64,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            cacheWidth: 150,
            semanticLabel: 'Attachment ${index + 1}',
          ),
        ),
        if (remove != null)
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Remove attachment ${index + 1}',
              onPressed: remove,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close, size: 15),
            ),
          ),
      ],
    ),
  );
}

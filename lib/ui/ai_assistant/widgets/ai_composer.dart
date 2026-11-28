import 'package:flutter/material.dart';

import '../../core/themes/shell_tokens.dart';
import 'ai_text_direction.dart';

class AiComposer extends StatelessWidget {
  const AiComposer({
    super.key,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
    required this.onRemoveContext,
    this.hasContext = false,
    this.working = false,
    this.canSend = true,
    this.canStop = false,
    this.reserveQuickAction = false,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend, onStop, onRemoveContext;
  final bool hasContext, working, canSend, canStop, reserveQuickAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        14,
        6,
        reserveQuickAction ? ShellTokens.actionSize + 24 : 14,
        12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 3, 5, 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasContext)
                InputChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 17),
                  label: const Text(
                    'Guide article attached',
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteButtonTooltipMessage: 'Remove Guide article context',
                  onDeleted: onRemoveContext,
                ),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 4,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        onChanged: onChanged,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        textDirection: aiTextDirection(
                          value.text,
                          Directionality.of(context),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask Balamandian AI',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: IconButton.filled(
                        tooltip: working ? 'Stop generation' : 'Send message',
                        onPressed: working
                            ? (canStop ? onStop : null)
                            : (canSend && value.text.trim().isNotEmpty
                                  ? onSend
                                  : null),
                        icon: Icon(
                          working
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

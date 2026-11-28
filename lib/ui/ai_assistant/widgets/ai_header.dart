import 'package:flutter/material.dart';

import '../../core/ui/brand.dart';

class AiHeader extends StatelessWidget {
  const AiHeader({super.key, required this.onHistory, required this.onNew});

  final VoidCallback onHistory, onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 8, 3),
            child: Row(
              spacing: 8,
              children: [
                const UniversityCrest(size: 25, decorative: true),
                Expanded(
                  child: Text(
                    'Balamandian AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Conversation history',
                  onPressed: onHistory,
                  icon: const Icon(Icons.history_rounded),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: onNew,
                  icon: const Icon(Icons.edit_note_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class AiThreadNotice extends StatelessWidget {
  const AiThreadNotice({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

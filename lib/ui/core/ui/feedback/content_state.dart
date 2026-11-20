import 'package:flutter/material.dart';

class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.people_outline_rounded,
    this.onRetry,
    this.compact = false,
  });
  final String title, message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 16 : 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 12 : 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: compact ? 24 : 30,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
        ],
      ),
    );
  }
}

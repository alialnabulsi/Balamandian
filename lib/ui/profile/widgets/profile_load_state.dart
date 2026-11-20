import 'package:flutter/material.dart';

class ProfileLoadState extends StatelessWidget {
  const ProfileLoadState({
    super.key,
    this.error,
    this.onRetry,
    this.loading = false,
    this.emptyTitle = 'No members yet',
    this.emptyMessage = 'Find people in your university community.',
  });
  final String? error;
  final VoidCallback? onRetry;
  final bool loading;
  final String emptyTitle, emptyMessage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const CircularProgressIndicator(semanticsLabel: 'Loading profile')
        else ...[
          Icon(
            error == null
                ? Icons.people_outline_rounded
                : Icons.cloud_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            error == null ? emptyTitle : 'Could not load',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(error ?? emptyMessage, textAlign: TextAlign.center),
          if (error != null && onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
        ],
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../core/ui/illustrations/campus_line_art.dart';

/// Community can supply a real grid/count without changing the profile layout.
class ProfilePostsSection extends StatelessWidget {
  const ProfilePostsSection({
    super.key,
    this.grid,
    this.count = 0,
    this.isSelf = true,
  });
  final Widget? grid;
  final int count;
  final bool isSelf;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Text('Posts', style: theme.textTheme.titleMedium),
          ],
        ),
        const Divider(height: 24),
        if (grid != null) grid! else const ProfilePostsEmptyState(),
      ],
    );
  }
}

class ProfilePostsEmptyState extends StatelessWidget {
  const ProfilePostsEmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        children: [
          CampusLineArt(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.primary
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            'No posts yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Campus posts are coming soon.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

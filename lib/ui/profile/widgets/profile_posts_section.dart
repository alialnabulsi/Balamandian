import 'package:flutter/material.dart';

/// The community feature can supply its real grid and count here later.
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_on_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text('Posts', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
      const Divider(height: 1),
      if (grid != null)
        grid!
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'No posts yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isSelf
                    ? 'Your campus stories will appear here when community posts arrive.'
                    : 'Campus stories will appear here when community posts arrive.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
    ],
  );
}

import 'package:flutter/material.dart';

class ProfileLockedIdentity extends StatelessWidget {
  const ProfileLockedIdentity({
    super.key,
    required this.displayName,
    required this.username,
  });
  final String displayName, username;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'University identity',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('Official name', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      Text(displayName),
      const SizedBox(height: 16),
      Text('Username', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      Text('@$username'),
      const SizedBox(height: 16),
      Text(
        'Your official name and username come from your verified university identity and cannot be edited.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

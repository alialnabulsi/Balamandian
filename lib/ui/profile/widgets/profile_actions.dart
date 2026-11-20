import 'package:flutter/material.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({
    super.key,
    required this.isSelf,
    required this.isFollowing,
    required this.pending,
    required this.onEdit,
    required this.onFollow,
    required this.onShare,
  });
  final bool isSelf, isFollowing, pending;
  final VoidCallback onEdit, onFollow, onShare;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton(
          onPressed: pending
              ? null
              : isSelf
              ? onEdit
              : onFollow,
          child: Text(
            pending
                ? 'Updating…'
                : isSelf
                ? 'Edit profile'
                : isFollowing
                ? 'Following'
                : 'Follow',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton(
          onPressed: onShare,
          child: const Text('Share profile', textAlign: TextAlign.center),
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../core/ui/buttons/stable_action_label.dart';

/// Reserves the longer label in every state; no normal-size label wrapping.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.following,
    required this.pending,
    required this.name,
    required this.onPressed,
    this.requested = false,
  });
  final bool following, pending;
  final bool requested;
  final String name;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${pending
            ? 'Updating'
            : requested
            ? 'Cancel follow request for'
            : following
            ? 'Unfollow'
            : 'Follow'} $name',
    button: true,
    enabled: !pending,
    onTap: pending ? null : onPressed,
    liveRegion: pending,
    excludeSemantics: true,
    child: OutlinedButton(
      onPressed: pending ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: following
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: pending
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    following ? Icons.check_rounded : Icons.add_rounded,
                    size: 14,
                  ),
          ),
          const SizedBox(width: 5),
          StableActionLabel(
            label: requested
                ? 'Requested'
                : following
                ? 'Following'
                : 'Follow',
            labels: requested
                ? const ['Requested']
                : const ['Following', 'Follow'],
          ),
        ],
      ),
    ),
  );
}

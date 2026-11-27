import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';
import 'profile_tokens.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({
    super.key,
    required this.isSelf,
    required this.isFollowing,
    required this.pending,
    required this.onEdit,
    required this.onFollow,
    required this.onShare,
    this.requested = false,
  });
  final bool isSelf, isFollowing, pending;
  final bool requested;
  final VoidCallback onEdit, onFollow, onShare;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final style = ProfileTokens.actionStyle(context);
      final primary = isSelf
          ? FilledButton(
              onPressed: onEdit,
              style: style,
              child: const Text('Edit profile'),
            )
          : AsyncActionButton(
              label: requested
                  ? 'Requested'
                  : isFollowing
                  ? 'Following'
                  : 'Follow',
              running: pending,
              onPressed: onFollow,
              style: style,
            );
      final share = FilledButton(
        onPressed: onShare,
        style: style,
        child: const Text('Share profile'),
      );
      if (box.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), share],
        );
      }
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 8),
          Expanded(child: share),
        ],
      );
    },
  );
}

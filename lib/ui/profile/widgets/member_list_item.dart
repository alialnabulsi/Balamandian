import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/avatars/member_avatar.dart';
import 'profile_badges.dart';
import 'follow_button.dart';

class MemberListItem extends StatelessWidget {
  const MemberListItem({
    super.key,
    required this.member,
    required this.loadAvatar,
    required this.onOpen,
    required this.onFollow,
    required this.pending,
  });
  final UserProfile member;
  final Future<Uint8List> Function(String) loadAvatar;
  final VoidCallback onOpen, onFollow;
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            MemberAvatar(
              identity: member.identity,
              loadAvatar: loadAvatar,
              size: AppTokens.avatarSmall,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.identity.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (member.identity.verified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: VerificationMark(size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${member.identity.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final action = FollowButton(
      following: member.isFollowing,
      requested: member.followRequested,
      pending: pending,
      name: member.identity.displayName,
      onPressed: onFollow,
    );
    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: .94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stacked) ...[
                  identity,
                  if (!member.isSelf)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: action,
                      ),
                    ),
                ] else
                  Row(
                    children: [
                      Expanded(child: identity),
                      if (!member.isSelf) ...[
                        const SizedBox(width: 10),
                        action,
                      ],
                    ],
                  ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

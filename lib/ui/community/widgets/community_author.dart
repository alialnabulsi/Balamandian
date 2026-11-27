import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/member_avatar.dart';

typedef CommunityAvatarLoader = Future<Uint8List> Function(String);

class CommunityAuthor extends StatelessWidget {
  const CommunityAuthor({
    super.key,
    required this.author,
    required this.loadAvatar,
    this.subtitle,
    this.size = 38,
  });
  final PublicUserIdentity author;
  final CommunityAvatarLoader loadAvatar;
  final String? subtitle;
  final double size;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/members/${author.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            MemberAvatar(identity: author, loadAvatar: loadAvatar, size: size),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.displayName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle ?? '@${author.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

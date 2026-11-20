import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/member_avatar.dart';

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: const EdgeInsets.only(right: 8),
            onTap: onOpen,
            leading: MemberAvatar(
              identity: member.identity,
              loadAvatar: loadAvatar,
              size: 48,
            ),
            title: Text(
              member.identity.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              '@${member.identity.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (!member.isSelf)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: OutlinedButton(
              onPressed: pending ? null : onFollow,
              child: Text(
                pending
                    ? 'Updating…'
                    : member.isFollowing
                    ? 'Following'
                    : 'Follow',
              ),
            ),
          ),
      ],
    ),
  );
}

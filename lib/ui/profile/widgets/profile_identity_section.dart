import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/member_avatar.dart';
import 'profile_badges.dart';
import 'profile_statistics.dart';
import 'profile_tokens.dart';

class ProfileIdentitySection extends StatelessWidget {
  const ProfileIdentitySection({
    super.key,
    required this.profile,
    required this.loadAvatar,
    required this.onFollowers,
    required this.onFollowing,
  });
  final UserProfile profile;
  final Future<Uint8List> Function(String) loadAvatar;
  final VoidCallback onFollowers, onFollowing;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Semantics(
            label: '${profile.identity.displayName} profile picture',
            image: true,
            child: MemberAvatar(
              identity: profile.identity,
              loadAvatar: loadAvatar,
              size: ProfileTokens.avatarSize,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ProfileStatistics(
              posts: profile.postsCount,
              followers: profile.followersCount,
              following: profile.followingCount,
              onFollowers: onFollowers,
              onFollowing: onFollowing,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        profile.identity.displayName,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      ProfileBadges(identity: profile.identity),
      if (profile.biography.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(profile.biography, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}

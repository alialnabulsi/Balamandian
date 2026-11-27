import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/profile_avatar.dart';
import 'profile_identity_summary.dart';
import 'profile_statistics.dart';
import 'profile_tokens.dart';

class ProfileIdentitySection extends StatelessWidget {
  const ProfileIdentitySection({
    super.key,
    required this.profile,
    required this.loadAvatar,
    required this.onFollowers,
    required this.onFollowing,
    this.onEdit,
  });
  final UserProfile profile;
  final Future<Uint8List> Function(String) loadAvatar;
  final VoidCallback? onFollowers, onFollowing;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          final avatar = ProfileAvatar(
            identity: profile.identity,
            loadAvatar: loadAvatar,
            size: box.maxWidth < 320 ? 64 : ProfileTokens.avatarSize,
            onEdit: profile.isSelf ? onEdit : null,
            showEditIndicator: false,
          );
          final stats = ProfileStatistics(
            posts: profile.postsCount,
            followers: profile.followersCount,
            following: profile.followingCount,
            onFollowers: onFollowers,
            onFollowing: onFollowing,
          );
          final needed =
              (box.maxWidth < 320 ? 64 : ProfileTokens.avatarSize) +
              20 +
              MediaQuery.textScalerOf(context).scale(65) * 3;
          if (box.maxWidth < needed) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 12), stats],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(child: stats),
            ],
          );
        },
      ),
      const SizedBox(height: ProfileTokens.identityGap),
      ProfileIdentitySummary(identity: profile.identity),
      if (profile.biography.isNotEmpty) ...[
        const SizedBox(height: ProfileTokens.biographyGap),
        Text(profile.biography, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}

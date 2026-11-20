import 'package:flutter/material.dart';

import '../../core/ui/loading/skeleton.dart';
import 'profile_tokens.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});
  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Loading profile',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final avatarSize = box.maxWidth < 320
                ? 72.0
                : ProfileTokens.avatarSize + 8;
            final beside =
                box.maxWidth >=
                avatarSize +
                    12 +
                    MediaQuery.textScalerOf(context).scale(65) * 3;
            final stats = ProfileStatisticsSkeleton(
              stacked:
                  !beside &&
                  box.maxWidth < MediaQuery.textScalerOf(context).scale(65) * 3,
            );
            return beside
                ? Row(
                    children: [
                      SkeletonAvatar(size: avatarSize),
                      const SizedBox(width: 12),
                      Expanded(child: stats),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonAvatar(size: avatarSize),
                      const SizedBox(height: 12),
                      stats,
                    ],
                  );
          },
        ),
        const SizedBox(height: ProfileTokens.identityGap),
        const SkeletonText(width: 220, height: 24),
        const SizedBox(height: 12),
        const SkeletonText(width: 240, height: 14),
        const SizedBox(height: ProfileTokens.biographyGap),
        const SkeletonText(),
        const SizedBox(height: 8),
        const SkeletonText(width: 180),
        const SizedBox(height: ProfileTokens.actionsGap),
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 48, radius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 48, radius: 14)),
          ],
        ),
        const SizedBox(height: 28),
        const SkeletonText(width: 70, height: 20),
        const SizedBox(height: 16),
        const SkeletonBox(height: 1),
      ],
    ),
  );
}

class ProfileStatisticsSkeleton extends StatelessWidget {
  const ProfileStatisticsSkeleton({super.key, required this.stacked});
  final bool stacked;
  @override
  Widget build(BuildContext context) => stacked
      ? const Column(
          children: [
            Padding(padding: EdgeInsets.all(12), child: SkeletonText()),
            Padding(padding: EdgeInsets.all(12), child: SkeletonText()),
            Padding(padding: EdgeInsets.all(12), child: SkeletonText()),
          ],
        )
      : const Row(
          children: [
            Expanded(child: ProfileStatisticSkeleton()),
            Expanded(child: ProfileStatisticSkeleton()),
            Expanded(child: ProfileStatisticSkeleton()),
          ],
        );
}

class ProfileStatisticSkeleton extends StatelessWidget {
  const ProfileStatisticSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SkeletonText(width: 20, height: 24),
      SizedBox(height: 8),
      SkeletonText(width: 44, height: 12),
    ],
  );
}

class ProfileEditorSkeleton extends StatelessWidget {
  const ProfileEditorSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    label: 'Loading profile editor',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: SkeletonAvatar(size: 104)),
        SizedBox(height: 16),
        Center(child: SkeletonText(width: 100)),
        SizedBox(height: 32),
        SkeletonText(width: 160),
        SizedBox(height: 16),
        SkeletonBox(height: 130, radius: 14),
        SizedBox(height: 28),
        SkeletonText(width: 140),
        SizedBox(height: 16),
        SkeletonText(),
        SizedBox(height: 16),
        SkeletonText(),
      ],
    ),
  );
}

class MemberListSkeleton extends StatelessWidget {
  const MemberListSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    label: 'Loading members',
    child: Column(
      children: [
        SkeletonMemberRow(),
        SkeletonMemberRow(),
        SkeletonMemberRow(),
        SkeletonMemberRow(),
        SkeletonMemberRow(),
      ],
    ),
  );
}

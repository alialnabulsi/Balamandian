import 'package:flutter/material.dart';

class ProfileStatistics extends StatelessWidget {
  const ProfileStatistics({
    super.key,
    required this.posts,
    required this.followers,
    required this.following,
    required this.onFollowers,
    required this.onFollowing,
  });
  final int posts, followers, following;
  final VoidCallback onFollowers, onFollowing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ProfileStatistic(label: 'Posts', count: posts),
      ),
      Expanded(
        child: ProfileStatistic(
          label: 'Followers',
          count: followers,
          onPressed: onFollowers,
        ),
      ),
      Expanded(
        child: ProfileStatistic(
          label: 'Following',
          count: following,
          onPressed: onFollowing,
        ),
      ),
    ],
  );
}

class ProfileStatistic extends StatelessWidget {
  const ProfileStatistic({
    super.key,
    required this.label,
    required this.count,
    this.onPressed,
  });
  final String label;
  final int count;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onPressed != null,
    label: '$count $label',
    excludeSemantics: true,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Column(
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

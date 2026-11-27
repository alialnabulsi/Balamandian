import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/themes/app_tokens.dart';

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
  final VoidCallback? onFollowers, onFollowing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked =
          box.maxWidth < MediaQuery.textScalerOf(context).scale(65) * 3;
      final stats = <Widget>[
        ProfileStatistic(label: 'Posts', count: posts, horizontal: stacked),
        ProfileStatistic(
          label: 'Followers',
          count: followers,
          onPressed: onFollowers,
          horizontal: stacked,
        ),
        ProfileStatistic(
          label: 'Following',
          count: following,
          onPressed: onFollowing,
          horizontal: stacked,
        ),
      ];
      final line = Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: .55);
      return stacked
          ? Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: line),
                  stats[i],
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    SizedBox(
                      height: 32,
                      child: VerticalDivider(width: 1, color: line),
                    ),
                  Expanded(child: stats[i]),
                ],
              ],
            );
    },
  );
}

class ProfileStatistic extends StatelessWidget {
  const ProfileStatistic({
    super.key,
    required this.label,
    required this.count,
    this.onPressed,
    this.horizontal = false,
  });
  final String label;
  final int count;
  final VoidCallback? onPressed;
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = AnimatedSwitcher(
      duration: AppTokens.motion(context),
      child: Text(
        count >= 10000 ? NumberFormat.compact().format(count) : '$count',
        key: ValueKey(count),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final caption = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Semantics(
      button: onPressed != null,
      onTap: onPressed,
      label: '$count $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 8 : 1,
            vertical: 8,
          ),
          child: horizontal
              ? Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 4,
                  children: [caption, number],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [number, const SizedBox(height: 2), caption],
                ),
        ),
      ),
    );
  }
}

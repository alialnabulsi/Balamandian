import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/avatars/app_avatar.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/brand.dart';
import 'profile_badges.dart';

class ProfileShareCard extends StatelessWidget {
  const ProfileShareCard({
    super.key,
    required this.username,
    this.identity,
    this.loadAvatar,
  });
  final String username;
  final PublicUserIdentity? identity;
  final Future<Uint8List> Function(String)? loadAvatar;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: AppBrandedBackground(
        variant: AppBackgroundVariant.architecture,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const UniversityCrest(size: 28, decorative: true),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Balamandian',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: .25),
                  ),
                ),
                child: identity != null && loadAvatar != null
                    ? MemberAvatar(
                        identity: identity,
                        loadAvatar: loadAvatar!,
                        size: 88,
                      )
                    : AppAvatar(name: identity?.displayName, size: 88),
              ),
              const SizedBox(height: 16),
              if (identity != null)
                Text(
                  identity!.displayName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 6),
              SelectableText(
                '@$username',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (identity?.verified ?? false) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VerificationMark(size: 16),
                    SizedBox(width: 5),
                    Text('University verified'),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

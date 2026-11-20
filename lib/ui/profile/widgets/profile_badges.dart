import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';

class ProfileBadges extends StatelessWidget {
  const ProfileBadges({super.key, required this.identity});
  final PublicUserIdentity identity;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final role in identity.roles) InstitutionalBadge(role: role),
    ],
  );
}

class VerificationMark extends StatelessWidget {
  const VerificationMark({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Identity verified through university SIS',
    child: Semantics(
      label: 'University verified',
      child: Icon(
        Icons.verified_rounded,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class InstitutionalBadge extends StatelessWidget {
  const InstitutionalBadge({super.key, required this.role});
  final String role;
  static String label(String role) => switch (role) {
    'verified' => 'SIS Verified',
    'student' => 'Student',
    'instructor' => 'Instructor',
    'advisor' => 'Advisor',
    'staff' => 'Staff',
    _ =>
      role
          .split('_')
          .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
          .join(' '),
  };
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, title = label(role);
    return Semantics(
      button: true,
      label: '$title badge. Tap for details.',
      child: ActionChip(
        avatar: Icon(
          role == 'verified'
              ? Icons.verified_rounded
              : role == 'student'
              ? Icons.school_outlined
              : Icons.badge_outlined,
          size: 16,
          color: scheme.primary,
        ),
        label: Text(title),
        labelStyle: Theme.of(context).textTheme.labelMedium,
        backgroundColor: role == 'verified'
            ? scheme.primaryContainer
            : scheme.tertiary.withValues(alpha: .18),
        side: BorderSide.none,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  role == 'verified'
                      ? 'This identity was confirmed through the university SIS during registration or identity synchronization.'
                      : 'This university role is supplied by SIS. Institutional roles do not grant Balamandian administrative privileges.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

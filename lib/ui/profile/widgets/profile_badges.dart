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
      if (identity.verified) const InstitutionalBadge(role: 'verified'),
      for (final role in identity.roles) InstitutionalBadge(role: role),
    ],
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
        backgroundColor: scheme.surfaceContainerLow,
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

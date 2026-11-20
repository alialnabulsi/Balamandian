import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import 'profile_badges.dart';
import 'profile_role_details.dart';

/// A lightweight public identity line; institutional detail remains available.
class ProfileRoleLabel extends StatelessWidget {
  const ProfileRoleLabel({super.key, required this.identity});
  final PublicUserIdentity identity;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = identity.roles.map(InstitutionalBadge.label).join(' · ');
    return Tooltip(
      message: 'University roles are supplied by SIS.',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => ProfileRoleDetails(
            roles: roles.isEmpty ? 'University member' : roles,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${roles.isEmpty ? 'Member' : roles} · University of Balamand',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

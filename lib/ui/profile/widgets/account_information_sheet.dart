import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/avatars/app_avatar.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import 'profile_badges.dart';
import 'account_information_group.dart';

class AccountInformationSheet extends StatelessWidget {
  const AccountInformationSheet({
    super.key,
    required this.profile,
    this.loadAvatar,
  });
  final UserProfile profile;
  final Future<Uint8List> Function(String)? loadAvatar;
  @override
  Widget build(BuildContext context) {
    final account = profile.isSelf ? profile.account : null;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: AppBrandedBackground(
        variant: AppBackgroundVariant.architecture,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'About this account',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close account information',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    loadAvatar == null
                        ? AppAvatar(
                            name: profile.identity.displayName,
                            size: 56,
                          )
                        : MemberAvatar(
                            identity: profile.identity,
                            loadAvatar: loadAvatar!,
                            size: 56,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.identity.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.identity.verified
                                ? 'Verified university member'
                                : 'University member',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile.identity.verified) const VerificationMark(),
                  ],
                ),
                AccountInformationGroup(
                  title: 'Balamandian account',
                  icon: Icons.alternate_email_rounded,
                  children: [
                    AccountInformationRow(
                      label: 'Username',
                      value: '@${profile.identity.username}',
                    ),
                    if (account != null)
                      AccountInformationRow(
                        label: 'Date joined',
                        value: DateFormat.yMMMd().format(
                          account.createdAt.toLocal(),
                        ),
                      ),
                    AccountInformationRow(
                      label: 'Verification',
                      value: profile.identity.verified
                          ? 'SIS Verified'
                          : 'Not verified',
                    ),
                  ],
                ),
                AccountInformationGroup(
                  title: 'University identity',
                  icon: Icons.verified_user_outlined,
                  children: [
                    AccountInformationRow(
                      label: 'Official name',
                      value: profile.identity.displayName,
                    ),
                    AccountInformationRow(
                      label: 'University roles',
                      value: profile.identity.roles
                          .map(InstitutionalBadge.label)
                          .join(', '),
                    ),
                    if (account != null) ...[
                      AccountInformationRow(
                        label: 'SIS ID',
                        value: account.sisId,
                      ),
                      AccountInformationRow(
                        label: 'Institutional email',
                        value: account.institutionalEmail,
                      ),
                      AccountInformationRow(
                        label: 'Email verified',
                        value:
                            'Verified ${DateFormat.yMMMd().format(account.emailVerifiedAt.toLocal())}',
                      ),
                    ],
                  ],
                ),
                if (account != null)
                  AccountInformationGroup(
                    title: 'Academic information',
                    icon: Icons.school_outlined,
                    children: [
                      AccountInformationRow(
                        label: 'Campus',
                        value: account.campus ?? 'Not provided',
                      ),
                      AccountInformationRow(
                        label: 'Admission year',
                        value:
                            account.admissionYear?.toString() ?? 'Not provided',
                      ),
                      if (account.programs.isEmpty)
                        const AccountInformationRow(
                          label: 'Academic programs',
                          value: 'Not provided',
                        ),
                      for (final program in account.programs) ...[
                        AccountInformationRow(
                          label: 'Academic program',
                          value: program.name,
                        ),
                        AccountInformationRow(
                          label: 'Faculty',
                          value: program.faculty,
                        ),
                        AccountInformationRow(
                          label: 'Department',
                          value: program.department,
                        ),
                      ],
                      for (final department in account.departments) ...[
                        AccountInformationRow(
                          label: 'Faculty',
                          value: department.faculty,
                        ),
                        AccountInformationRow(
                          label: 'Department',
                          value: department.name,
                        ),
                      ],
                      if (account.programs.isEmpty &&
                          account.departments.isEmpty) ...[
                        const AccountInformationRow(
                          label: 'Faculty',
                          value: 'Not provided',
                        ),
                        const AccountInformationRow(
                          label: 'Department',
                          value: 'Not provided',
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  account == null
                      ? 'SIS identifiers, email and academic details are private to the account owner.'
                      : 'Only you can see your SIS ID, email and academic details. University identity is managed by SIS.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

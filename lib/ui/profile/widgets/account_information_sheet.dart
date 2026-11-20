import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/profile_models.dart';
import 'profile_badges.dart';

class AccountInformationSheet extends StatelessWidget {
  const AccountInformationSheet({super.key, required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    final account = profile.account;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'About this account',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Official identity is managed by the university and cannot be changed inside Balamandian.',
          ),
          const SizedBox(height: 20),
          AccountInformationRow(
            label: 'Official name',
            value: profile.identity.displayName,
          ),
          AccountInformationRow(
            label: 'Username · Balamandian',
            value: '@${profile.identity.username}',
          ),
          if (account != null) ...[
            const Divider(),
            Text(
              'University identity · only visible to you',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            AccountInformationRow(label: 'SIS ID', value: account.sisId),
            AccountInformationRow(
              label: 'Institutional email',
              value: account.institutionalEmail,
            ),
            AccountInformationRow(
              label: 'Email verification',
              value:
                  'Verified ${DateFormat.yMMMd().format(account.emailVerifiedAt.toLocal())}',
            ),
            AccountInformationRow(
              label: 'University roles',
              value: account.roles.map(InstitutionalBadge.label).join(', '),
            ),
            AccountInformationRow(
              label: 'Campus',
              value: account.campus ?? 'Not provided',
            ),
            AccountInformationRow(
              label: 'Admission year',
              value: account.admissionYear?.toString() ?? 'Not provided',
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
              AccountInformationRow(label: 'Faculty', value: program.faculty),
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
            if (account.programs.isEmpty && account.departments.isEmpty) ...[
              const AccountInformationRow(
                label: 'Faculty',
                value: 'Not provided',
              ),
              const AccountInformationRow(
                label: 'Department',
                value: 'Not provided',
              ),
            ],
            const Divider(),
            AccountInformationRow(
              label: 'Joined Balamandian · application account',
              value: DateFormat.yMMMd().format(account.createdAt.toLocal()),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              'SIS identifiers, email and academic details are private to the account owner.',
            ),
          ],
        ],
      ),
    );
  }
}

class AccountInformationRow extends StatelessWidget {
  const AccountInformationRow({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

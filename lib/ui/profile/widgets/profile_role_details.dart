import 'package:flutter/material.dart';

class ProfileRoleDetails extends StatelessWidget {
  const ProfileRoleDetails({super.key, required this.roles});
  final String roles;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roles, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'University roles are supplied by SIS. They confirm your institutional identity and do not grant Balamandian administrative privileges.',
          ),
        ],
      ),
    ),
  );
}

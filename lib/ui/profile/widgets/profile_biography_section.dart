import 'package:flutter/material.dart';

import 'profile_biography_field.dart';

class ProfileBiographySection extends StatelessWidget {
  const ProfileBiographySection({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'A little about you',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Make your corner of campus feel like you.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      ProfileBiographyField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
      ),
    ],
  );
}

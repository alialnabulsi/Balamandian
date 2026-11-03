import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';
import '../view_models/auth_ui_controller.dart';

class UniversityDetailsCard extends StatelessWidget {
  const UniversityDetailsCard({super.key, this.identity});
  final UniversityIdentity? identity;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Read-only SIS details',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                AssetIcon('graduation-cap', size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'University details',
                        style: StartupTokens.text(
                          13,
                          20,
                          weight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        'From SIS · Read-only',
                        style: StartupTokens.text(
                          11,
                          18,
                          color: StartupPalette.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outline),
            const SizedBox(height: 12),
            IdentityDetail(label: 'Name', value: identity?.name),
            const SizedBox(height: 9),
            IdentityDetail(label: 'Major', value: identity?.major),
            const SizedBox(height: 9),
            IdentityDetail(label: 'Faculty', value: identity?.faculty),
          ],
        ),
      ),
    );
  }
}

class IdentityDetail extends StatelessWidget {
  const IdentityDetail({super.key, required this.label, this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: StartupTokens.text(
          12,
          18,
          color: StartupPalette.of(context).muted,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          value?.trim().isNotEmpty == true ? value! : 'Provided by SIS',
          textAlign: TextAlign.right,
          style: StartupTokens.text(12, 18, weight: FontWeight.w500),
        ),
      ),
    ],
  );
}

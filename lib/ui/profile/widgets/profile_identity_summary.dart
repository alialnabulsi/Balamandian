import 'package:flutter/material.dart';

import '../../../domain/models/profile_models.dart';
import 'profile_badges.dart';
import 'profile_role_label.dart';
import 'profile_tokens.dart';

class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({super.key, required this.identity});
  final PublicUserIdentity identity;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              identity.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: ProfileTokens.nameFontSize,
                height: 28 / 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
          ),
          if (identity.verified)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: VerificationMark(size: ProfileTokens.verificationSize),
            ),
        ],
      ),
      ProfileRoleLabel(identity: identity),
    ],
  );
}

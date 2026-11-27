import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../view_models/academic_profile_view_model.dart';

class StudentAccessPanel extends StatelessWidget {
  const StudentAccessPanel({
    super.key,
    required this.access,
    required this.onSignIn,
    required this.onRetry,
  });
  final StudentAccess access;
  final VoidCallback onSignIn, onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ContentState(
        icon: Icons.calculate_outlined,
        title: switch (access) {
          StudentAccess.guest => 'Sign in to explore your GPA',
          StudentAccess.loading => 'Checking student eligibility…',
          StudentAccess.profileError => 'Account eligibility unavailable',
          _ => 'Student accounts only',
        },
        message: switch (access) {
          StudentAccess.guest =>
            'Use your university account to open the calculator.',
          StudentAccess.loading => 'Waiting for your university profile.',
          StudentAccess.profileError =>
            'Retry your profile to check your access.',
          _ =>
            'GPA Calculator requires an account containing the student role.',
        },
        onRetry: access == StudentAccess.profileError ? onRetry : null,
      ),
      if (access == StudentAccess.guest)
        AsyncActionButton(label: 'Sign in', onPressed: onSignIn),
    ],
  );
}

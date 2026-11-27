import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../view_models/task_planner_view_model.dart';

class TaskAccessPanel extends StatelessWidget {
  const TaskAccessPanel({
    super.key,
    required this.access,
    required this.onSignIn,
    required this.onRetry,
  });
  final PlannerAccess access;
  final VoidCallback onSignIn, onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ContentState(
        icon: Icons.checklist_rounded,
        title: switch (access) {
          PlannerAccess.guest => 'Sign in to plan your day',
          PlannerAccess.loading => 'Checking account eligibility…',
          PlannerAccess.profileError => 'Account eligibility unavailable',
          _ => 'Student and advisor accounts',
        },
        message: switch (access) {
          PlannerAccess.guest =>
            'Your personal tasks stay with your university account.',
          PlannerAccess.loading =>
            'Your tasks will load after your university profile is ready.',
          PlannerAccess.profileError =>
            'Your profile could not be loaded. Retry to check your access.',
          _ => 'To-do Planner is available to accounts with a student or advisor role.',
        },
        onRetry: access == PlannerAccess.profileError ? onRetry : null,
      ),
      if (access == PlannerAccess.guest)
        AsyncActionButton(label: 'Sign in', onPressed: onSignIn),
    ],
  );
}

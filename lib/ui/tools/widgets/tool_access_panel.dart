import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/tool_session.dart';

class ToolAccessPanel extends StatelessWidget {
  const ToolAccessPanel({
    super.key,
    required this.session,
    required this.title,
  });
  final ToolSession session;
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ContentState(
        title: switch (session.access) {
          ToolAccess.guest => 'Sign in to $title',
          ToolAccess.loading => 'Checking account eligibility...',
          ToolAccess.profileError => 'Account eligibility unavailable',
          _ => 'Student and advisor accounts',
        },
        message: session.access == ToolAccess.guest
            ? 'Your personal information stays private to your account.'
            : '$title requires a verified student or advisor profile.',
        onRetry: session.access == ToolAccess.profileError
            ? session.retry
            : null,
      ),
      if (session.access == ToolAccess.guest)
        FilledButton(
          onPressed: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (_) => SignInPrompt(feature: title),
            );
            if (context.mounted &&
                yes == true &&
                session.access == ToolAccess.guest) {
              context.go('/welcome/sign-in');
            }
          },
          child: const Text('Sign in'),
        ),
    ],
  );
}

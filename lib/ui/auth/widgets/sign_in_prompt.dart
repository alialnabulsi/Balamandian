import 'package:flutter/material.dart';

/// Returns true only when the guest chooses to open the existing sign-in flow.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sign in to continue'),
    content: Text('Sign in with your university account to use $feature.'),
    scrollable: true,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Sign in'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../core/ui/action_button.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/form_message.dart';
import 'session_loading_state.dart';
import '../../onboarding/widgets/native_splash_reveal.dart';
import '../view_models/session_view_model.dart';

/// Protected content is never built while saved credentials are unvalidated.
class SessionGateScreen extends StatelessWidget {
  const SessionGateScreen({
    super.key,
    required this.model,
    this.entryError,
    this.onRetry,
    this.allowLocalSignOut = true,
  });
  final SessionViewModel model;
  final String? entryError;
  final VoidCallback? onRetry;
  final bool allowLocalSignOut;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => model.busy
        ? NativeSplashReveal(
            child: SessionLoadingState(label: model.activityLabel),
          )
        : NativeSplashReveal(
            child: Scaffold(
              body: AppBrandedBackground(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BalamandianBrand(),
                            const SizedBox(height: 32),
                            Text(
                              'We couldn’t open your session',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FormMessage(
                              entryError ??
                                  model.error ??
                                  'Please check your connection and try again.',
                            ),
                            const SizedBox(height: 24),
                            ActionButton(
                              label: 'Retry',
                              onPressed: onRetry ?? model.retry,
                              icon: null,
                            ),
                            if (allowLocalSignOut) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => model.logout(localOnly: true),
                                child: const Text('Sign out on this device'),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Device-only sign-out removes saved credentials. Server-side revocation cannot be confirmed.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}

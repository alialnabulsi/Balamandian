import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/action_button.dart';
import '../../core/ui/asset_icon.dart';
import '../../core/ui/form_message.dart';
import '../../onboarding/widgets/startup_flow.dart';
import '../view_models/auth_ui_controller.dart';
import '../view_models/credentials_view_model.dart';
import 'access_frame.dart';
import 'auth_field.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({
    super.key,
    required this.signingUp,
    required this.repository,
    this.onAuthenticated,
  });
  final bool signingUp;
  final AuthRepository repository;
  final ValueChanged<AuthUser>? onAuthenticated;
  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _identifier = TextEditingController(),
      _password = TextEditingController();
  final _identifierFocus = FocusNode(), _passwordFocus = FocusNode();
  late final _model = CredentialsViewModel(
    signingUp: widget.signingUp,
    repository: widget.repository,
  );

  Future<void> _submit() async {
    final host = AuthUiScope.of(context);
    final nav = StartupNavigation.of(context);
    if (host.pending || nav.busy || _model.pending) {
      return;
    }
    if (!_model.validate(_identifier.text, _password.text)) {
      (_model.identifierError != null ? _identifierFocus : _passwordFocus)
          .requestFocus();
      return;
    }
    _model.conceal();
    FocusManager.instance.primaryFocus?.unfocus();
    host.pending = true;
    var success = false;
    try {
      success = await _model.submit(_identifier.text, _password.text);
    } finally {
      if (mounted) host.pending = false;
    }
    if (!mounted || !success) return;
    _password.clear();
    if (widget.signingUp) {
      nav.navigate(
        StartupDestination.verifyEmail,
        extra: _model.pendingRegistration,
      );
    } else {
      if (_model.authenticatedUser case final user?) {
        widget.onAuthenticated?.call(user);
      }
      context.go('/');
    }
  }

  @override
  void dispose() {
    _password.clear();
    _identifier.dispose();
    _password.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = AuthUiScope.of(context), nav = StartupNavigation.of(context);
    final up = widget.signingUp;
    final gap = MediaQuery.sizeOf(context).height <= 780 ? 18.0 : 22.0;
    return AccessFrame(
      title: up ? 'Create your account' : 'Welcome back',
      label: up ? 'First-time setup' : 'Log in',
      step: up ? 1 : null,
      child: ListenableBuilder(
        listenable: _model,
        builder: (context, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_model.formError ?? host.formError case final message?) ...[
              FormMessage(message),
              SizedBox(height: gap),
            ],
            AuthField(
              label: up ? 'SIS ID' : 'Email or SIS ID',
              hint: up ? 'Enter your SIS ID' : 'Enter your email or SIS ID',
              controller: _identifier,
              focusNode: _identifierFocus,
              enabled: !nav.busy,
              error: _model.identifierError,
              onChanged: (_) => _model.editIdentifier(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            SizedBox(height: gap),
            AuthField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !nav.busy,
              sensitive: true,
              obscure: !_model.passwordVisible,
              error: _model.passwordError,
              onChanged: (_) => _model.editPassword(),
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              suffix: AppIconButton(
                icon: _model.passwordVisible ? 'eye-slash' : 'eye',
                label: _model.passwordVisible
                    ? 'Hide password'
                    : 'Show password',
                selected: _model.passwordVisible,
                color: StartupPalette.of(context).muted,
                onPressed: nav.busy ? null : _model.toggleVisibility,
              ),
            ),
            SizedBox(height: gap + 5),
            ActionButton(
              label: up ? 'Continue' : 'Log in',
              onPressed: nav.busy ? null : _submit,
              pending: host.pending,
            ),
            const Spacer(),
            SizedBox(height: gap + 26),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  up ? 'Already have an account?' : 'New to Balamandian?',
                  style: StartupTokens.text(
                    12,
                    20,
                    color: StartupPalette.of(context).muted,
                  ),
                ),
                TextButton(
                  onPressed: nav.busy
                      ? null
                      : () {
                          _password.clear();
                          _model.conceal();
                          nav.navigate(
                            up
                                ? StartupDestination.signIn
                                : StartupDestination.signUp,
                          );
                        },
                  child: Text(up ? 'Log in' : 'Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/pending_registration.dart';
import '../../../routing/startup_destination.dart';
import '../../core/ui/action_button.dart';
import '../../core/ui/form_message.dart';
import '../../onboarding/widgets/startup_flow.dart';
import '../view_models/auth_ui_controller.dart';
import '../view_models/otp_view_model.dart';
import 'access_frame.dart';
import 'otp_code_field.dart';
import 'otp_delivery_status.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.repository, this.registration});

  final AuthRepository repository;
  final PendingRegistration? registration;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _model = OtpViewModel(
    repository: widget.repository,
    registration: widget.registration,
  );

  Future<void> _verify() async {
    if (StartupNavigation.of(context).busy || !_model.canVerify) return;
    final host = AuthUiScope.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    host.pending = true;
    var success = false;
    try {
      success = await _model.verify(_code.text);
    } finally {
      if (mounted) host.pending = false;
    }
    if (!mounted) return;
    if (success) {
      _code.clear();
      context.go('/');
    } else if (_model.codeError != null) {
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (StartupNavigation.of(context).busy || !_model.canResend) return;
    final host = AuthUiScope.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    host.pending = true;
    var success = false;
    try {
      success = await _model.resend();
    } finally {
      if (mounted) host.pending = false;
    }
    if (mounted && success) {
      _code.clear();
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    _focus.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = StartupNavigation.of(context);
    return AccessFrame(
      title: 'Check your email',
      description: 'Enter the six-digit code sent to your university email.',
      label: 'Verify your email',
      child: ListenableBuilder(
        listenable: _model,
        builder: (context, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_model.formError case final message?) ...[
              FormMessage(message),
              const SizedBox(height: 18),
            ],
            if (_model.requiresRestart || _model.requiresLogin) ...[
              if (_model.formError == null) ...[
                const FormMessage(
                  'Start registration to request a verification code.',
                ),
                const SizedBox(height: 18),
              ],
              ActionButton(
                label: _model.requiresLogin ? 'Log in' : 'Start again',
                onPressed: nav.busy
                    ? null
                    : () => nav.navigate(
                        _model.requiresLogin
                            ? StartupDestination.signIn
                            : StartupDestination.signUp,
                      ),
              ),
            ] else ...[
              OtpCodeField(
                controller: _code,
                focusNode: _focus,
                enabled: !nav.busy && _model.canVerify,
                error: _model.codeError,
                onChanged: (_) => _model.editCode(),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),
              ActionButton(
                label: 'Verify email',
                pending: _model.verifying,
                onPressed: nav.busy || !_model.canVerify ? null : _verify,
              ),
              const SizedBox(height: 18),
              OtpDeliveryStatus(model: _model, onResend: _resend),
            ],
            const Spacer(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../view_models/otp_view_model.dart';

class OtpDeliveryStatus extends StatelessWidget {
  const OtpDeliveryStatus({
    super.key,
    required this.model,
    required this.onResend,
  });

  final OtpViewModel model;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final seconds = model.expirySeconds;
    final cooldown = model.retrySeconds > model.resendSeconds
        ? model.retrySeconds
        : model.resendSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          model.expired
              ? 'Your code has expired. Request a new one below.'
              : 'Code expires in ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.',
          style: StartupTokens.text(
            12,
            20,
            color: StartupPalette.of(context).muted,
          ),
        ),
        if (model.notice case final notice?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              notice,
              style: StartupTokens.text(
                13,
                20,
                color: StartupPalette.of(context).success,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: model.canResend ? onResend : null,
          child: Text(
            model.resending
                ? 'Sending code…'
                : cooldown > 0
                ? 'Resend code in ${cooldown}s'
                : 'Resend code',
          ),
        ),
      ],
    );
  }
}

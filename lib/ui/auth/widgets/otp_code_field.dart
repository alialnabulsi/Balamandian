import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_field.dart';

class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? error;
  final ValueChanged<String> onChanged, onSubmitted;

  @override
  Widget build(BuildContext context) => AuthField(
    label: 'Verification code',
    hint: 'Enter your six-digit code',
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    sensitive: true,
    keyboardType: TextInputType.number,
    action: TextInputAction.done,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    autofillHints: const [AutofillHints.oneTimeCode],
    error: error,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );
}

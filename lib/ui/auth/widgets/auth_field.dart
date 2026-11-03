import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/form_message.dart';

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.error,
    this.enabled = true,
    this.obscure = false,
    this.sensitive = false,
    this.suffix,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.multiline = false,
    this.maxLength,
    this.optional = false,
  });
  final String label, hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged, onSubmitted;
  final String? error;
  final bool enabled, obscure, sensitive, multiline, optional;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final int? maxLength;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              label,
              style: StartupTokens.text(
                13,
                20,
                weight: FontWeight.w600,
                color: error == null ? null : scheme.error,
              ),
            ),
            if (optional)
              Text(
                'Optional',
                style: StartupTokens.text(
                  11,
                  18,
                  color: StartupPalette.of(context).muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscure,
            enableSuggestions: !sensitive,
            autocorrect: false,
            autofillHints: const [],
            enableIMEPersonalizedLearning: !sensitive,
            textCapitalization: TextCapitalization.none,
            keyboardType:
                keyboardType ??
                (multiline
                    ? TextInputType.multiline
                    : sensitive
                    ? TextInputType.visiblePassword
                    : TextInputType.text),
            textInputAction: multiline ? TextInputAction.newline : action,
            minLines: multiline ? 3 : 1,
            maxLines: multiline ? 3 : 1,
            maxLength: maxLength,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            style: StartupTokens.text(15, 24),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            scrollPadding: const EdgeInsets.all(24),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: EdgeInsets.fromLTRB(
                14,
                multiline ? 14 : 15,
                14,
                multiline ? 26 : 15,
              ),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minHeight: 48,
                minWidth: 54,
              ),
              constraints: BoxConstraints(minHeight: multiline ? 112 : 54),
              fillColor: error == null ? scheme.surface : scheme.errorContainer,
              enabledBorder: error == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.error),
                    ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          FormMessage(error!, compact: true),
        ],
      ],
    );
  }
}

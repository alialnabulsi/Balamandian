import 'package:flutter/material.dart';

/// Configurable field; its form state survives ordinary rebuilds and rotation.
class GpaInput extends StatelessWidget {
  const GpaInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.helper,
    this.numeric = true,
    this.enabled = true,
  });
  final String label, value;
  final String? error, helper;
  final bool numeric, enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    enabled: enabled,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textInputAction: TextInputAction.next,
    textCapitalization: numeric
        ? TextCapitalization.none
        : TextCapitalization.words,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      errorText: error,
      errorMaxLines: 4,
      helperMaxLines: 4,
    ),
  );
}

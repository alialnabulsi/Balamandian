import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileBiographyField extends StatelessWidget {
  const ProfileBiographyField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      minLines: 3,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        TextInputFormatter.withFunction(
          (old, next) => next.text.runes.length > 250 ? old : next,
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Biography',
        hintText: 'Your interests, your clubs, a little about you…',
        alignLabelWithHint: true,
        counterText: '${value.text.runes.length} / 250',
      ),
    ),
  );
}

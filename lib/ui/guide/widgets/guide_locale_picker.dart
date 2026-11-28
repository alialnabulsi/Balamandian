import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';

class GuideLocalePicker extends StatelessWidget {
  const GuideLocalePicker({
    super.key,
    required this.locale,
    required this.onChanged,
  });
  final GuideLocale locale;
  final ValueChanged<GuideLocale> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<GuideLocale>(
      value: locale,
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      items: const [
        DropdownMenuItem(value: GuideLocale.en, child: Text('English')),
        DropdownMenuItem(value: GuideLocale.ar, child: Text('العربية')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      hint: const Text('Content language'),
    ),
  );
}

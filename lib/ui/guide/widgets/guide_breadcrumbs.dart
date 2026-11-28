import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';

class GuideBreadcrumbs extends StatelessWidget {
  const GuideBreadcrumbs({
    super.key,
    required this.sections,
    required this.onOpen,
  });
  final List<GuideSection> sections;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const Icon(Icons.chevron_right_rounded, size: 16),
        if (i == sections.length - 1)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              sections[i].label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          )
        else
          TextButton(
            onPressed: () => onOpen(sections[i].id),
            child: Text(sections[i].label),
          ),
      ],
    ],
  );
}

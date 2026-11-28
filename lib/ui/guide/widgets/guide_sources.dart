import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';

class GuideSources extends StatelessWidget {
  const GuideSources({super.key, required this.sources, required this.onOpen});
  final List<GuideSource> sources;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Official sources',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
      for (final source in sources)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.open_in_new_rounded),
          title: Text(source.label),
          subtitle: source.locator == null ? null : Text(source.locator!),
          onTap: () => onOpen(source.url),
        ),
    ],
  );
}

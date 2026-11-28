import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';

class GuideSectionTile extends StatelessWidget {
  const GuideSectionTile({
    super.key,
    required this.section,
    required this.onOpen,
  });
  final GuideSection section;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTokens.space),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(
          section.hasChildren
              ? Icons.folder_open_rounded
              : Icons.menu_book_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          section.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onOpen,
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';

class NotesBreadcrumbs extends StatelessWidget {
  const NotesBreadcrumbs({
    super.key,
    required this.folders,
    required this.onOpen,
  });
  final List<NoteFolder> folders;
  final ValueChanged<String?> onOpen;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(onPressed: () => onOpen(null), child: const Text('My Notes')),
      for (final f in folders) ...[
        const Icon(Icons.chevron_right_rounded, size: 18),
        TextButton(onPressed: () => onOpen(f.id), child: Text(f.name)),
      ],
    ],
  );
}

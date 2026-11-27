import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/note_models.dart';
import '../../core/ui/app_surface.dart';

class NotesFolderTile extends StatelessWidget {
  const NotesFolderTile({
    super.key,
    required this.folder,
    required this.onOpen,
    required this.onAction,
    this.enabled = true,
  });
  final NoteFolder folder;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  final bool enabled;
  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(4),
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(
          folder.playground
              ? Icons.auto_awesome_outlined
              : Icons.folder_outlined,
        ),
        title: Text(folder.name),
        subtitle: folder.playground
            ? const Text('Permanent · notes without a folder')
            : null,
        onTap: enabled ? onOpen : null,
        trailing: folder.playground
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Actions for folder ${folder.name}',
                enabled: enabled,
                onSelected: onAction,
                itemBuilder: (_) => [
                  for (final a in ['Rename', 'Move', 'Delete'])
                    PopupMenuItem(value: a, child: Text(a)),
                ],
              ),
      ),
    ),
  );
}

class NotesItemTile extends StatelessWidget {
  const NotesItemTile({
    super.key,
    required this.note,
    required this.onOpen,
    required this.onAction,
    this.path,
    this.enabled = true,
  });
  final PersonalNote note;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  final String? path;
  final bool enabled;
  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(4),
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(note.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.preview.isNotEmpty)
              Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              [
                ?path,
                DateFormat.yMMMd().add_jm().format(note.updatedAt.toLocal()),
              ].join(' · '),
            ),
          ],
        ),
        onTap: enabled ? onOpen : null,
        trailing: PopupMenuButton<String>(
          tooltip: 'Actions for note ${note.title}',
          enabled: enabled,
          onSelected: onAction,
          itemBuilder: (_) => [
            for (final a in ['Move', 'Delete'])
              PopupMenuItem(value: a, child: Text(a)),
          ],
        ),
      ),
    ),
  );
}

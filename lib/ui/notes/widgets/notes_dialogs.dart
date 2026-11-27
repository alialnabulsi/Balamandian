import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';

class NotesConfirmDialog extends StatelessWidget {
  const NotesConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.action = 'Delete',
  });
  final String title, message, action;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(action),
      ),
    ],
  );
}

class FolderNameDialog extends StatefulWidget {
  const FolderNameDialog({super.key, this.name = ''});
  final String name;
  @override
  State<FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<FolderNameDialog> {
  late final _text = TextEditingController(text: widget.name);
  bool _submitted = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name.isEmpty ? 'New folder' : 'Rename folder'),
    content: TextField(
      controller: _text,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: 'Folder name',
        errorMaxLines: 3,
        errorText: !_submitted
            ? null
            : _text.text.trim().isEmpty
            ? 'Enter a folder name.'
            : _text.text.runes.length > 80
            ? 'Use at most 80 Unicode characters.'
            : null,
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save folder')),
    ],
  );
  void _save() {
    setState(() => _submitted = true);
    if (_text.text.trim().isNotEmpty && _text.text.runes.length <= 80) {
      Navigator.pop(context, _text.text.trim());
    }
  }
}

class NotesDestinationDialog extends StatelessWidget {
  const NotesDestinationDialog({
    super.key,
    required this.folders,
    required this.path,
    this.includeRoot = false,
    this.excluded = const {},
  });
  final List<NoteFolder> folders;
  final String Function(String?) path;
  final bool includeRoot;
  final Set<String> excluded;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose destination'),
    content: SizedBox(
      width: 420,
      height: MediaQuery.sizeOf(context).height * .5,
      child: ListView(
        children: [
          if (includeRoot)
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('My Notes (root)'),
              onTap: () => Navigator.pop(context, ''),
            ),
          for (final f in folders)
            if (!excluded.contains(f.id))
              ListTile(
                leading: Icon(
                  f.playground
                      ? Icons.auto_awesome_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(path(f.id)),
                onTap: () => Navigator.pop(context, f.id),
              ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

enum NotesLeaveChoice { save, local, stay }

class NotesLeaveDialog extends StatelessWidget {
  const NotesLeaveDialog({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Unsaved changes'),
    content: const Text(
      'Save to your account or keep a private recovery draft on this device before leaving. Pending files and drawings remain in the local draft.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, NotesLeaveChoice.stay),
        child: const Text('Stay'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, NotesLeaveChoice.local),
        child: const Text('Keep local draft & leave'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, NotesLeaveChoice.save),
        child: const Text('Save & leave'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';

class NotesHeader extends StatefulWidget {
  const NotesHeader({
    super.key,
    required this.onBack,
    required this.onNote,
    required this.onFolder,
    required this.onSearch,
    required this.search,
  });
  final VoidCallback onBack;
  final VoidCallback? onNote, onFolder;
  final ValueChanged<String> onSearch;
  final String search;
  @override
  State<NotesHeader> createState() => _NotesHeaderState();
}

class _NotesHeaderState extends State<NotesHeader> {
  late final _search = TextEditingController(text: widget.search);
  @override
  void didUpdateWidget(NotesHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.search) {
      _search.value = TextEditingValue(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Tools'),
        ),
      ),
      Text('My Notes', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('A private place for your ideas, classes and sketches.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AsyncActionButton(label: 'New note', onPressed: widget.onNote),
          AsyncActionButton(
            label: 'New folder',
            onPressed: widget.onFolder,
            outlined: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _search,
        onChanged: widget.onSearch,
        decoration: const InputDecoration(
          labelText: 'Search all note titles',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    ],
  );
}

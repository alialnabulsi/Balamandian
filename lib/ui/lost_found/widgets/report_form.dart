import 'package:flutter/material.dart';

import '../../../data/repositories/lost_found_repository.dart';
import '../../../data/services/note_file_service.dart';
import '../view_models/report_composer_view_model.dart';
import '../../tools/view_models/tool_session.dart';

class ReportForm extends StatefulWidget {
  const ReportForm({
    super.key,
    required this.type,
    required this.repository,
    required this.files,
    required this.session,
  });
  final String type;
  final LostFoundRepository repository;
  final NoteFileService files;
  final ToolSession session;
  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _title = TextEditingController(),
      _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final model = ReportComposerViewModel(
    widget.repository,
    widget.files,
    widget.session,
    widget.type,
  );
  late final _epoch = widget.session.epoch;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted && widget.session.epoch != _epoch) {
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _title.dispose();
    _description.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!model.busy &&
        _form.currentState!.validate() &&
        await model.submit(_title.text, _description.text) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy,
      child: AlertDialog(
        scrollable: true,
        title: Text('Report ${widget.type.toUpperCase()}'),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Private to your account and authorized OSA review. No public listing or direct matching.',
              ),
              TextFormField(
                controller: _title,
                enabled: !model.busy,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Title *'),
                onChanged: (_) => model.changed(),
                validator: (s) => s == null || s.trim().isEmpty
                    ? 'Enter a title'
                    : s.runes.length > 160
                    ? 'Use at most 160 characters'
                    : null,
              ),
              TextFormField(
                controller: _description,
                enabled: !model.busy,
                maxLength: 4000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Private description (optional)',
                ),
                onChanged: (_) => model.changed(),
              ),
              for (final u in model.uploads)
                ListTile(
                  title: Text(u.filename),
                  trailing: IconButton(
                    tooltip: 'Remove upload',
                    onPressed: model.busy ? null : () => model.remove(u),
                    icon: const Icon(Icons.close),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: model.busy || model.uploads.length >= 5
                    ? null
                    : model.upload,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add optional image / PDF'),
              ),
              if (model.error != null)
                Text(
                  model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                'Submission is saved in a private review queue. OSA notification delivery is not currently configured.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: model.busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: model.busy ? null : _save,
            child: Text(model.busy ? 'Saving...' : 'Submit report'),
          ),
        ],
      ),
    ),
  );
}

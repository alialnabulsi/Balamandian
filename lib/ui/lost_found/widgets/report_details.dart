import '../view_models/report_details_view_model.dart';

import 'package:flutter/material.dart';

import '../../../data/repositories/lost_found_repository.dart';
import '../../../data/services/note_file_service.dart';
import '../../../domain/models/lost_found_models.dart';

class ReportDetails extends StatefulWidget {
  const ReportDetails({
    super.key,
    required this.report,
    required this.repository,
    required this.files,
  });
  final LostFoundReport report;
  final LostFoundRepository repository;
  final NoteFileService files;
  @override
  State<ReportDetails> createState() => _ReportDetailsState();
}

class _ReportDetailsState extends State<ReportDetails> {
  late final model = ReportDetailsViewModel(widget.repository, widget.files);
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> open(ReportUpload u) async {
    final bytes = await model.open(u);
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(bytes, semanticLabel: u.filename),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => AlertDialog(
      scrollable: true,
      title: Text(widget.report.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.report.type.toUpperCase()} - ${widget.report.statusLabel}',
          ),
          Text(widget.report.createdAt.toLocal().toString().split('.').first),
          if (widget.report.description != null)
            SelectableText(widget.report.description!),
          for (final u in widget.report.uploads)
            TextButton.icon(
              onPressed: model.busy ? null : () => open(u),
              icon: const Icon(Icons.attachment),
              label: Text(u.filename),
            ),
          if (model.error != null) Text(model.error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

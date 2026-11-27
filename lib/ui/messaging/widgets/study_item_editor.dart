import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/community.dart';
import '../../community/widgets/community_actions.dart';
import '../view_models/academic_model.dart';

Future<bool> showStudyEditor(
  BuildContext context,
  AcademicModel model,
  String thread,
  String kind, {
  String? parent,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StudyItemEditor(
        model: model,
        thread: thread,
        kind: kind,
        parent: parent,
      ),
    ) ??
    false;

class StudyItemEditor extends StatefulWidget {
  const StudyItemEditor({
    super.key,
    required this.model,
    required this.thread,
    required this.kind,
    this.parent,
  });
  final AcademicModel model;
  final String thread, kind;
  final String? parent;
  @override
  State<StudyItemEditor> createState() => _StudyItemEditorState();
}

class _StudyItemEditorState extends State<StudyItemEditor> {
  final title = TextEditingController(),
      body = TextEditingController(),
      location = TextEditingController();
  final form = GlobalKey<FormState>();
  String id = AcademicModel.newId();
  DateTime? start;
  XFile? file;
  bool busy = false, picking = false;
  double? progress;
  bool get resource => widget.kind == 'resource';
  bool get session => widget.kind == 'session';
  bool get answer => widget.kind == 'answer';
  String get heading => switch (widget.kind) {
    'resource' => 'Add resource',
    'note' => 'Write note',
    'question' => 'Ask question',
    'answer' => 'Write an answer',
    _ => 'Schedule session',
  };

  Future<void> pick() async {
    if (picking || busy) return;
    setState(() => picking = true);
    await communityCommand(context, () async {
      final result = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Study documents',
            extensions: ['pdf', 'txt'],
            mimeTypes: ['application/pdf', 'text/plain'],
          ),
        ],
      );
      if (result == null || !mounted) return;
      final length = await result.length();
      if (length < 1 || length > 8000000) {
        throw const CommunityFailure(
          'Choose a document between 1 byte and 8 MB.',
        );
      }
      if (mounted) {
        setState(() {
          file = result;
          id = AcademicModel.newId();
          if (title.text.isEmpty) title.text = result.name;
        });
      }
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> time() async {
    final now = DateTime.now();
    final initial = start ?? now.add(const Duration(hours: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || day == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || selected == null) return;
    setState(
      () => start = DateTime(
        day.year,
        day.month,
        day.day,
        selected.hour,
        selected.minute,
      ),
    );
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (resource && file == null) {
      communityFeedback(context, 'Choose a PDF or text document.');
      return;
    }
    if (session && start?.isAfter(DateTime.now()) != true) {
      communityFeedback(context, 'Choose a time in the future.');
      return;
    }
    setState(() => busy = true);
    await communityCommand(context, () async {
      if (resource) {
        final bytes = await file!.readAsBytes();
        await widget.model.upload(
          widget.thread,
          id,
          file!.name,
          title.text.trim(),
          bytes,
          (value) {
            if (mounted) setState(() => progress = value);
          },
        );
      } else {
        await widget.model.publish(
          widget.thread,
          id,
          widget.kind,
          title.text.trim(),
          body.text.trim(),
          parent: widget.parent,
          startsAt: start,
          location: location.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    });
    if (mounted) {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(heading, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (resource)
              OutlinedButton.icon(
                onPressed: busy || picking ? null : pick,
                icon: const Icon(Icons.attach_file),
                label: Text(file?.name ?? 'Choose PDF or text file'),
              ),
            if (!answer)
              TextFormField(
                controller: title,
                enabled: !busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v?.trim().length ?? 0) < (resource ? 1 : 2)
                    ? 'Enter a title.'
                    : null,
              ),
            if (session) ...[
              OutlinedButton.icon(
                onPressed: busy ? null : time,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  start == null
                      ? 'Date and time'
                      : DateFormat.MMMEd().add_jm().format(start!),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: location,
                enabled: !busy,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Location or meeting link',
                ),
              ),
            ],
            if (!resource)
              TextFormField(
                controller: body,
                enabled: !busy,
                minLines: 3,
                maxLines: 6,
                maxLength: 12000,
                decoration: InputDecoration(
                  labelText: session
                      ? 'What will you study? (optional)'
                      : answer
                      ? 'Your answer'
                      : 'Details',
                ),
                validator: (v) => !session && (v?.trim().isEmpty ?? true)
                    ? 'Write a short description.'
                    : null,
              ),
            if (progress != null)
              LinearProgressIndicator(
                value: progress,
                semanticsLabel: 'Uploading document',
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: busy || picking ? null : save,
              child: Text(
                busy
                    ? 'Saving…'
                    : resource
                    ? 'Upload resource'
                    : 'Publish',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

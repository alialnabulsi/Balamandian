import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/task_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/task_editor_view_model.dart';
import '../view_models/task_planner_view_model.dart';

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, required this.planner, this.task});
  final TaskPlannerViewModel planner;
  final PlannerTask? task;
  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final _model = TaskEditorViewModel(
    planner: widget.planner,
    original: widget.task,
  );
  late final _title = TextEditingController(text: _model.title);
  late final _details = TextEditingController(text: _model.details);
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    widget.planner.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (_model.current || _closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _title.clear();
    _details.clear();
    _model.title = _model.details = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await _model.save();
    if (mounted && saved) Navigator.pop(context);
  }

  @override
  void dispose() {
    widget.planner.removeListener(_accountChanged);
    _title.dispose();
    _details.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_model, widget.planner]),
    builder: (context, _) {
      if (!_model.current) return const SizedBox.shrink();
      return PopScope(
        canPop: !_model.saving,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.task == null ? 'Add task' : 'Edit task',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_model.error case final error?) ...[
                    FormMessage(error),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _title,
                    enabled: !_model.saving,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      helperText: 'Required · up to 160 characters',
                      errorText: _model.submitted ? _model.titleError : null,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: (value) => _model.title = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _details,
                    enabled: !_model.saving,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Details (optional)',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      helperText: 'Up to 2,000 characters',
                      errorText: _model.submitted ? _model.detailsError : null,
                    ),
                    onChanged: (value) => _model.details = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TaskStatus>(
                    initialValue: _model.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    isExpanded: true,
                    items: [
                      for (final status in TaskStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: _model.saving
                        ? null
                        : (value) => _model.status = value!,
                  ),
                  const SizedBox(height: 20),
                  AsyncActionButton(
                    label: 'Save task',
                    runningLabel: 'Saving task…',
                    running: _model.saving,
                    onPressed: () => unawaited(_save()),
                  ),
                  TextButton(
                    onPressed: _model.saving
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

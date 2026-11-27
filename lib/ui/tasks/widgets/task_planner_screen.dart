import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../domain/models/task_models.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/form_message.dart';
import '../view_models/task_planner_view_model.dart';
import 'task_access_panel.dart';
import 'task_card.dart';
import 'task_delete_dialog.dart';
import 'task_editor_sheet.dart';
import 'task_kanban_board.dart';
import 'task_planner_header.dart';
import 'task_progress_summary.dart';
import 'task_view_switch.dart';

class TaskPlannerScreen extends StatefulWidget {
  const TaskPlannerScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
  });
  final AuthRepository auth;
  final ProfileRepository profiles;
  final TaskRepository repository;
  @override
  State<TaskPlannerScreen> createState() => _TaskPlannerScreenState();
}

class _TaskPlannerScreenState extends State<TaskPlannerScreen> {
  late final _model = TaskPlannerViewModel(
    auth: widget.auth,
    profiles: widget.profiles,
    repository: widget.repository,
  );
  bool _modalOpen = false;
  Future<void> _edit([PlannerTask? task]) async {
    if (_modalOpen || !_model.canMutate) return;
    _modalOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        isDismissible: false,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (_) => TaskEditorSheet(planner: _model, task: task),
      );
    } finally {
      _modalOpen = false;
    }
  }

  Future<void> _delete(PlannerTask task) async {
    if (_modalOpen || !_model.canMutate) return;
    final epoch = _model.epoch;
    _modalOpen = true;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) =>
            TaskDeleteDialog(title: task.title, planner: _model, epoch: epoch),
      );
      if (confirm == true && epoch == _model.epoch) await _model.delete(task);
    } finally {
      _modalOpen = false;
    }
  }

  Future<void> _signIn() async {
    final signIn = await showDialog<bool>(
      context: context,
      builder: (_) => const SignInPrompt(feature: 'To-do Planner'),
    );
    if (mounted && signIn == true && _model.access == PlannerAccess.guest) {
      context.go('/welcome/sign-in');
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => RefreshIndicator(
      onRefresh: _model.refresh,
      child: ListView(
        key: const PageStorageKey('task-planner-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          8,
          AppTokens.gutter,
          112,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskPlannerHeader(
                    onBack: () => context.go('/tools'),
                    onAdd: _model.canMutate ? () => unawaited(_edit()) : null,
                  ),
                  const SizedBox(height: 16),
                  if (_model.access != PlannerAccess.eligible)
                    TaskAccessPanel(
                      access: _model.access,
                      onSignIn: () => unawaited(_signIn()),
                      onRetry: () => unawaited(_model.retryProfile()),
                    )
                  else ...[
                    TaskProgressSummary(
                      completed: _model.completed,
                      total: _model.tasks.length,
                    ),
                    const SizedBox(height: 16),
                    TaskViewSwitch(
                      selected: _model.view,
                      onChanged: _model.selectView,
                    ),
                    const SizedBox(height: 16),
                    if (_model.error case final error?) ...[
                      FormMessage(error),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _model.busy || _model.loading
                              ? null
                              : () => unawaited(_model.refresh()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh planner'),
                        ),
                      ),
                    ],
                    if (_model.loading)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Loading tasks',
                      ),
                    if (_model.busy)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_model.activity),
                        ),
                      ),
                    if (!_model.loading &&
                        _model.error == null &&
                        _model.tasks.isEmpty)
                      const ContentState(
                        title: 'A little room to plan',
                        message: 'Add your first task. Your list and board will stay in sync.',
                        icon: Icons.checklist_rounded,
                      ),
                    if (_model.view == PlannerView.kanban)
                      TaskKanbanBoard(
                        tasks: _model.tasks,
                        enabled: _model.canMutate,
                        pendingId: _model.pendingId,
                        onEdit: (task) => unawaited(_edit(task)),
                        onDelete: (task) => unawaited(_delete(task)),
                        onStatus: (task, status) =>
                            unawaited(_model.changeStatus(task, status)),
                      )
                    else
                      for (final task in _model.tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(
                            task: task,
                            pending: _model.pendingId == task.id,
                            onEdit: _model.canMutate
                                ? () => unawaited(_edit(task))
                                : null,
                            onDelete: _model.canMutate
                                ? () => unawaited(_delete(task))
                                : null,
                            onStatus: _model.canMutate
                                ? (status) => unawaited(
                                    _model.changeStatus(task, status),
                                  )
                                : null,
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

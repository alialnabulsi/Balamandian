import '../../core/themes/app_tokens.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/scheduler_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../../domain/models/schedule_models.dart';
import '../../tools/view_models/tool_session.dart';
import '../../tools/view_models/tools_hub_view_model.dart' show UniversityLinks;
import '../../tools/widgets/tool_access_panel.dart';
import '../../tools/widgets/tool_scoped_dialog.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/scheduler_view_model.dart';
import 'course_pool_selector.dart';
import 'schedule_timetable.dart';
import 'schedule_option_tile.dart';
import 'schedule_preview_dialog.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
    required this.externalUrls,
    this.syncReminders,
  });
  final Future<void> Function()? syncReminders;
  final AuthRepository auth;
  final ProfileRepository profiles;
  final SchedulerRepository repository;
  final ExternalUrlService externalUrls;
  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  late final session = ToolSession(
    auth: widget.auth,
    profiles: widget.profiles,
    cancelPending: widget.repository.cancelPending,
  );
  late final model = SchedulerViewModel(
    session,
    widget.repository,
    syncReminders: widget.syncReminders,
  );
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    model.dispose();
    session.dispose();
    super.dispose();
  }

  Future<void> option(ScheduleOption option) async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => ToolScopedDialog(
        session: session,
        child: SchedulePreviewDialog(option: option),
      ),
    );
  }

  void top() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  });

  Future<void> chooseOption(ScheduleOption option) async {
    await model.save(option);
    if (mounted && model.error == null && model.data?.draft != null) top();
  }

  Future<void> deleteProposal() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete proposed schedule?'),
        content: const Text(
          'You can create another while registration is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await model.deleteProposal();
      if (mounted && model.error == null) top();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, session]),
    builder: (context, _) {
      final d = model.data;
      final chosen = d?.registration != 'registered' && d?.draft != null;
      return RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            16,
            AppTokens.gutter,
            120,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to Tools',
                  onPressed: () => context.go('/tools'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Sync from SIS',
                  onPressed: model.busy
                      ? null
                      : () =>
                            d == null ? model.syncSemesters() : model.refresh(),
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            if (session.access != ToolAccess.eligible)
              ToolAccessPanel(session: session, title: 'Schedule')
            else ...[
              if (model.loading || model.busy) const LinearProgressIndicator(),
              if (model.error != null)
                ContentState(
                  title: 'Schedule unavailable',
                  message: model.error!,
                  onRetry: model.load,
                ),
              if (model.message != null) Text(model.message!),
              if (!model.loading && model.semesters.isEmpty)
                ContentState(
                  title: 'No semester data yet',
                  message:
                      'No semesters with usable dates are available in SIS.',
                  onRetry: model.syncSemesters,
                ),
              if (model.semesters.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(d?.semester.id),
                  initialValue: d?.semester.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: [
                    for (final s in model.semesters)
                      DropdownMenuItem(value: s.id, child: Text(s.label)),
                  ],
                  onChanged: model.busy
                      ? null
                      : (id) {
                          if (id != null) model.choose(id);
                        },
                ),
              if (d != null) ...[
                if (chosen) ...[
                  const SizedBox(height: 16),
                  if (d.canPlan)
                    OutlinedButton.icon(
                      onPressed: model.busy ? null : deleteProposal,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete proposed schedule'),
                    ),
                  ScheduleTimetable(courses: d.draft!.courses, proposed: true),
                  if (d.draftStale)
                    const Text(
                      'This proposal uses older course information. Refresh before relying on it.',
                    ),
                  const Text(
                    'Proposed schedule. Register these courses in SIS to complete enrollment.',
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await widget.externalUrls.launch(UniversityLinks.sis);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open SIS'),
                  ),
                  if (d.canPlan)
                    PopupMenuButton<int>(
                      tooltip: 'Registration reminder',
                      onSelected: model.reminder,
                      itemBuilder: (_) => [
                        for (final m in [15, 60, 1440])
                          PopupMenuItem(
                            value: m,
                            child: Text(
                              '$m minutes before registration closes',
                            ),
                          ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Remind me to register'),
                      ),
                    ),
                ] else if (d.canPlan) ...[
                  if (!model.creating)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: FilledButton.icon(
                        onPressed: model.startPlanning,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Create a schedule'),
                      ),
                    )
                  else ...[
                    if (d.requiredCredits != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Study-plan credits: ${d.earnedCredits}/${d.requiredCredits}',
                      ),
                      LinearProgressIndicator(
                        value: (d.earnedCredits! / d.requiredCredits!).clamp(
                          0.0,
                          1.0,
                        ),
                      ),
                    ],
                    CoursePoolSelector(
                      courses: model.candidates,
                      selected: model.selected,
                      onSelect: model.select,
                      onSearch: model.filter,
                      onCredits: model.credits,
                      enabled: !model.busy,
                      target: model.targetInput,
                      validTarget: model.targetValid,
                    ),
                    FilledButton.icon(
                      onPressed:
                          !model.busy &&
                              model.targetValid &&
                              model.selected.isNotEmpty
                          ? model.generate
                          : null,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Generate schedules'),
                    ),
                    if (model.generated != null) ...[
                      Text(model.generated!.message),
                      for (final reason in model.generated!.reasons)
                        Text(reason),
                      for (var i = 0; i < model.generated!.options.length; i++)
                        ScheduleOptionTile(
                          option: model.generated!.options[i],
                          index: i + 1,
                          onOpen: () => option(model.generated!.options[i]),
                          onSave: () =>
                              chooseOption(model.generated!.options[i]),
                          enabled: !model.busy,
                        ),
                    ],
                  ],
                ] else ...[
                  if (d.actual == null)
                    ContentState(
                      title: 'Timetable not available',
                      message: d.reason,
                      onRetry: model.refresh,
                    )
                  else if (d.actual!.isEmpty)
                    const ContentState(
                      title: 'No registered classes',
                      message: 'There are no classes in your SIS timetable for this semester.',
                    )
                  else
                    ScheduleTimetable(courses: d.actual!, proposed: false),
                ],
                if (d.syncedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Last synced: ${d.memberSyncedAt ?? d.syncedAt}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

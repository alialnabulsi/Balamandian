import 'campus_month_calendar.dart';
import '../../core/themes/app_tokens.dart';
import '../../tools/widgets/tool_scoped_dialog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../../domain/models/calendar_models.dart';
import '../../tools/view_models/tool_session.dart';
import '../../tools/widgets/tool_access_panel.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/calendar_view_model.dart';
import '../view_models/calendar_reminder_coordinator.dart';
import '../view_models/event_editor_view_model.dart';
import 'calendar_category_filter.dart';
import 'calendar_event_tile.dart';
import 'calendar_event_details.dart';
import 'event_editor.dart';

class CampusCalendarScreen extends StatefulWidget {
  const CampusCalendarScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.reminders,
    required this.externalUrls,
    this.eventId,
  });
  final CalendarRepository repository;
  final ToolSession session;
  final CalendarReminderCoordinator reminders;
  final ExternalUrlService externalUrls;
  final String? eventId;
  @override
  State<CampusCalendarScreen> createState() => _CampusCalendarScreenState();
}

class _CampusCalendarScreenState extends State<CampusCalendarScreen> {
  late final model = CalendarViewModel(
    widget.session,
    widget.repository,
    widget.reminders,
  );
  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openLink());
    }
  }

  @override
  void didUpdateWidget(CampusCalendarScreen old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId && widget.eventId != null) openLink();
  }

  Future<void> openLink() async {
    final epoch = widget.session.epoch;
    try {
      final e = await widget.repository.read(
        widget.eventId!,
        member: model.member,
      );
      if (mounted && epoch == widget.session.epoch) {
        model.select(DateTime.parse(e.start));
        open(e);
      }
    } catch (_) {
      if (mounted && epoch == widget.session.epoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Event unavailable. Sign in to its account or refresh the calendar.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void reminderFeedback() {
    final message = widget.reminders.message;
    if (mounted && message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> edit([CampusEvent? e]) async {
    if (!model.member) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventEditor(
        day: model.selected,
        model: EventEditorViewModel(
          widget.repository,
          widget.session,
          widget.reminders,
          e,
        ),
      ),
    );
    if (saved == true) {
      await model.load();
      reminderFeedback();
    }
  }

  Future<void> remove(CampusEvent e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete personal event?'),
        content: const Text(
          'Its synchronized device reminder will be cancelled.',
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
    if (yes == true) {
      await model.mutate(() async {
        await widget.repository.delete(e);
        return null;
      });
    }
  }

  Future<void> open(CampusEvent e) async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => ToolScopedDialog(
        session: widget.session,
        child: CalendarEventDetails(
          event: e,
          member: model.member,
          onEdit: () {
            Navigator.pop(dialog);
            edit(e);
          },
          onDelete: () {
            Navigator.pop(dialog);
            remove(e);
          },
          onReminder: (m) {
            Navigator.pop(dialog);
            model.mutate(() => widget.repository.reminder(e.id, m));
          },
          onSource: () async {
            final uri = Uri.tryParse(e.sourceUrl ?? '');
            if (uri != null) await widget.externalUrls.launch(uri);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, widget.session, widget.reminders]),
    builder: (context, _) => RefreshIndicator(
      onRefresh: model.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space * 2,
          AppTokens.gutter,
          AppTokens.space * 15,
        ),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Back to Tools',
                onPressed: () => context.go('/tools'),
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                'Calendar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton(onPressed: model.today, child: const Text('Today')),
              if (model.member)
                FilledButton.icon(
                  onPressed: model.busy ? null : () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Personal event'),
                ),
            ],
          ),
          CalendarCategoryFilter(
            selected: model.filters,
            member: model.member,
            onChanged: model.filter,
          ),
          CampusMonthCalendar(
            today: model.campusDay,
            events: model.events
                .where((e) => model.filters.contains(e.category))
                .toList(),
            selected: model.selected,
            onSelect: model.select,
            onMonthChanged: model.select,
          ),
          Text(
            MaterialLocalizations.of(context).formatFullDate(model.selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (model.loading || model.busy) const LinearProgressIndicator(),
          if (model.error != null)
            ContentState(
              title: 'Calendar unavailable',
              message: model.error!,
              onRetry: model.load,
            ),
          if (!model.loading && model.agenda.isEmpty)
            const ContentState(
              title: 'No events for this day',
              message: 'Choose another date, adjust filters, or add a personal event.',
              compact: true,
            ),
          for (final e in model.agenda)
            CalendarEventTile(event: e, onOpen: () => open(e)),
          if (!model.member)
            ToolAccessPanel(
              session: widget.session,
              title: 'Personal calendar',
            ),
          if (model.member) ...[
            TextButton.icon(
              onPressed: () => widget.reminders
                  .refresh(requestPermission: true)
                  .then((_) => reminderFeedback()),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Enable / sync device reminders'),
            ),
          ],
        ],
      ),
    ),
  );
}

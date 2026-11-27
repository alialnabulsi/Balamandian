import 'package:flutter/material.dart';

import '../../../domain/models/calendar_models.dart';
import '../view_models/event_editor_view_model.dart';
import 'event_date_range_fields.dart';

class EventEditor extends StatefulWidget {
  const EventEditor({super.key, required this.model, required this.day});
  final EventEditorViewModel model;
  final DateTime day;
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final title = TextEditingController(text: widget.model.existing?.title),
      details = TextEditingController(text: widget.model.existing?.details),
      location = TextEditingController(text: widget.model.existing?.location);
  late bool allDay = widget.model.existing?.allDay ?? false;
  late int? lead = widget.model.existing?.reminderMinutes;
  DateTime floating(String value) =>
      DateTime.parse(value.length == 10 ? '${value}T00:00:00Z' : '${value}Z');
  late DateTime start = floating(
        widget.model.existing?.start ?? '${calendarDate(widget.day)}T09:00',
      ),
      end = widget.model.existing == null
          ? floating('${calendarDate(widget.day)}T10:00')
          : allDay
          ? floating(widget.model.existing!.end)
                .subtract(const Duration(days: 1))
          : floating(widget.model.existing!.end);
  final form = GlobalKey<FormState>();
  late final epoch = widget.model.session.epoch;
  @override
  void initState() {
    super.initState();
    widget.model.session.addListener(sync);
  }

  void sync() {
    if (mounted && widget.model.session.epoch != epoch) {
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    widget.model.session.removeListener(sync);
    title.dispose();
    details.dispose();
    location.dispose();
    widget.model.dispose();
    super.dispose();
  }

  String stamp(DateTime d) => allDay
      ? calendarDate(d)
      : '${calendarDate(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final last = allDay ? DateTime.utc(end.year, end.month, end.day + 1) : end;
    final ok = await widget.model.save(
      title: title.text,
      details: details.text,
      location: location.text,
      allDay: allDay,
      start: stamp(start),
      end: stamp(last),
      lead: lead,
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) => PopScope(
      canPop: !widget.model.busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          widget.model.existing == null
              ? 'Add personal event'
              : 'Edit personal event',
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: title,
                enabled: !widget.model.busy,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  counterText: '',
                ),
                validator: (s) => s == null || s.trim().isEmpty
                    ? 'Enter a title'
                    : s.runes.length > 160
                    ? 'Use at most 160 characters'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: allDay,
                onChanged: widget.model.busy
                    ? null
                    : (v) => setState(() {
                        allDay = v;
                        if (v) {
                          start = DateTime.utc(
                            start.year,
                            start.month,
                            start.day,
                          );
                          end = DateTime.utc(end.year, end.month, end.day);
                        } else {
                          start = DateTime.utc(
                            start.year,
                            start.month,
                            start.day,
                            9,
                          );
                          end = DateTime.utc(end.year, end.month, end.day, 10);
                        }
                      }),
              ),
              EventDateRangeFields(
                start: start,
                end: end,
                allDay: allDay,
                enabled: !widget.model.busy,
                onStart: (d) => setState(() => start = d),
                onEnd: (d) => setState(() => end = d),
              ),
              TextFormField(
                controller: details,
                enabled: !widget.model.busy,
                maxLength: 4000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  counterText: '',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              TextFormField(
                controller: location,
                enabled: !widget.model.busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  counterText: '',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: lead ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Reminder',
                  prefixIcon: Icon(Icons.notifications_outlined),
                ),
                items: [
                  for (final m in reminderLeads)
                    DropdownMenuItem(
                      value: m ?? -1,
                      child: Text(reminderLabel(m)),
                    ),
                ],
                onChanged: widget.model.busy
                    ? null
                    : (v) => setState(() => lead = v == -1 ? null : v),
              ),
              if (widget.model.error != null)
                Text(
                  widget.model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.model.busy
                ? null
                : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: widget.model.busy ? null : save,
            child: Text(widget.model.busy ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    ),
  );
}

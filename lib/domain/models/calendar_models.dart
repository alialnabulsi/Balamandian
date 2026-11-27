enum CalendarCategory { academic, university, personal }

class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.allDay,
    required this.start,
    required this.end,
    required this.revision,
    this.details,
    this.location,
    this.sourceUrl,
    this.sourceLabel,
    this.academicYear,
    this.reminderMinutes,
    this.reminderAt,
  });
  final String id, title, start, end;
  final CalendarCategory category;
  final bool allDay;
  final int revision;
  final String? details, location, sourceUrl, sourceLabel, academicYear;
  final int? reminderMinutes;
  final DateTime? reminderAt;
  bool get personal => category == CalendarCategory.personal;
  bool onDay(DateTime day) {
    final a = DateTime.parse(allDay ? '${start}T00:00:00Z' : '${start}Z'),
        b = DateTime.parse(allDay ? '${end}T00:00:00Z' : '${end}Z');
    final d = DateTime.utc(day.year, day.month, day.day),
        next = d.add(const Duration(days: 1));
    return a.isBefore(next) && b.isAfter(d);
  }

  factory CampusEvent.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return CampusEvent(
      id: j['id'] as String,
      title: j['title'] as String,
      category: CalendarCategory.values.byName(j['category'] as String),
      allDay: j['allDay'] as bool,
      start: j['start'] as String,
      end: j['end'] as String,
      revision: j['revision'] as int,
      details: j['details'] as String?,
      location: j['location'] as String?,
      sourceUrl: j['sourceUrl'] as String?,
      sourceLabel: j['sourceLabel'] as String?,
      academicYear: j['academicYear'] as String?,
      reminderMinutes: j['reminderMinutes'] as int?,
      reminderAt: j['reminderAt'] == null
          ? null
          : DateTime.parse(j['reminderAt'] as String),
    );
  }
}

String calendarDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const reminderLeads = <int?>[null, 0, 5, 15, 30, 60, 1440, 10080];
String reminderLabel(int? m) => switch (m) {
  null => 'No reminder',
  0 => 'At event time',
  1440 => '1 day before',
  10080 => '1 week before',
  _ => '$m minutes before',
};

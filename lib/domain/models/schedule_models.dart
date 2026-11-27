class AcademicSemester {
  const AcademicSemester(this.id, this.label, this.phase, this.version);
  final String id, label, phase, version;
  factory AcademicSemester.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return AcademicSemester(
      j['id'] as String,
      j['label'] as String,
      j['phase'] as String,
      j['version'] as String,
    );
  }
}

class ClassMeeting {
  const ClassMeeting(
    this.days,
    this.startMinute,
    this.endMinute,
    this.startDate,
    this.endDate,
    this.weekInterval,
    this.weekAnchor,
    this.location,
  );
  final List<int> days;
  final int startMinute, endMinute, weekInterval;
  final String startDate, endDate, weekAnchor;
  final String? location;
  factory ClassMeeting.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return ClassMeeting(
      (j['days'] as List).cast<int>(),
      j['startMinute'] as int,
      j['endMinute'] as int,
      j['startDate'] as String,
      j['endDate'] as String,
      j['weekInterval'] as int,
      j['weekAnchor'] as String,
      j['location'] as String?,
    );
  }
  bool occurs(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    if (day.isBefore(DateTime.parse('${startDate}T00:00:00Z')) ||
        day.isAfter(DateTime.parse('${endDate}T00:00:00Z')) ||
        !days.contains(date.weekday)) {
      return false;
    }
    final diff = day
        .difference(DateTime.parse('${weekAnchor}T00:00:00Z'))
        .inDays;
    final week = (diff / 7).floor();
    return ((week % weekInterval) + weekInterval) % weekInterval == 0;
  }

  String get time =>
      '${(startMinute ~/ 60).toString().padLeft(2, '0')}:${(startMinute % 60).toString().padLeft(2, '0')}-${(endMinute ~/ 60).toString().padLeft(2, '0')}:${(endMinute % 60).toString().padLeft(2, '0')}';
}

class ClassComponent {
  const ClassComponent(this.id, this.kind, this.label, this.meetings);
  final String id, kind, label;
  final List<ClassMeeting>? meetings;
  factory ClassComponent.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return ClassComponent(
      j['id'] as String,
      j['kind'] as String,
      j['label'] as String,
      (j['meetings'] as List?)?.map(ClassMeeting.fromJson).toList(),
    );
  }
}

class ProposedCourse {
  const ProposedCourse(
    this.id,
    this.title,
    this.credits,
    this.bundleId,
    this.components,
  );
  final String id, title, bundleId;
  final double credits;
  final List<ClassComponent> components;
  factory ProposedCourse.fromJson(Object? value) {
    final j = value as Map<String, dynamic>,
        b = j['bundle'] as Map<String, dynamic>;
    return ProposedCourse(
      j['courseId'] as String,
      j['title'] as String,
      (j['credits'] as num).toDouble(),
      b['id'] as String,
      (b['components'] as List).map(ClassComponent.fromJson).toList(),
    );
  }
  factory ProposedCourse.actual(Object? value) {
    final j = value as Map<String, dynamic>;
    return ProposedCourse(
      j['courseId'] as String,
      j['title'] as String,
      (j['credits'] as num).toDouble(),
      'actual',
      (j['components'] as List).map(ClassComponent.fromJson).toList(),
    );
  }
}

class ScheduleOption {
  const ScheduleOption(this.key, this.credits, this.courses);
  final String key;
  final double credits;
  final List<ProposedCourse> courses;
  factory ScheduleOption.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return ScheduleOption(
      j['key'] as String,
      (j['credits'] as num).toDouble(),
      (j['courses'] as List).map(ProposedCourse.fromJson).toList(),
    );
  }
}

class CandidateCourse {
  const CandidateCourse(
    this.id,
    this.title,
    this.credits,
    this.status,
    this.reason,
  );
  final String id, title, status;
  final String? reason;
  final double credits;
}

class ScheduleData {
  ScheduleData.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    semester = AcademicSemester.fromJson(j['semester']);
    final p = j['planning'] as Map<String, dynamic>;
    canPlan = p['enabled'] == true;
    reason = p['reason'] as String;
    sourceStale = j['sourceStale'] == true;
    draftStale = j['draftStale'] == true;
    final o = j['offerings'] as Map<String, dynamic>?,
        m = j['member'] as Map<String, dynamic>?;
    offeringVersion = o?['version'] as String?;
    memberVersion = m?['version'] as String?;
    source = o?['source'] as String?;
    syncedAt = o?['syncedAt'] as String?;
    memberSyncedAt = m?['syncedAt'] as String?;
    final md = m?['data'] as Map<String, dynamic>?;
    registration = md?['registration'] as String? ?? 'unknown';
    final eligibility = (md?['eligibility'] as Map<String, dynamic>?) ?? {};
    final progress = md?['progress'] as Map<String, dynamic>?;
    earnedCredits = (progress?['earnedCredits'] as num?)?.toDouble();
    requiredCredits = (progress?['requiredCredits'] as num?)?.toDouble();
    candidates = [
      for (final raw
          in ((o?['data'] as Map<String, dynamic>?)?['courses'] as List?) ?? [])
        if (raw is Map<String, dynamic>)
          CandidateCourse(
            raw['id'] as String,
            raw['title'] as String,
            (raw['credits'] as num).toDouble(),
            (eligibility[raw['id']] as Map?)?['status'] as String? ?? 'unknown',
            (eligibility[raw['id']] as Map?)?['reason'] as String?,
          ),
    ];
    actual = (j['actual'] as List?)?.map(ProposedCourse.actual).toList();
    final d = j['draft'] as Map<String, dynamic>?;
    draft = d == null ? null : ScheduleOption.fromJson(d['option']);
    draftRevision = d?['revision'] as int?;
  }
  late final String registration;
  late final AcademicSemester semester;
  late final bool canPlan, sourceStale, draftStale;
  late final String reason;
  late final String? offeringVersion,
      memberVersion,
      source,
      syncedAt,
      memberSyncedAt;
  late final List<CandidateCourse> candidates;
  late final List<ProposedCourse>? actual;
  late final ScheduleOption? draft;
  late final int? draftRevision;
  late final double? earnedCredits, requiredCredits;
}

class ScheduleGeneration {
  ScheduleGeneration.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    outcome = j['outcome'] as String;
    message = j['message'] as String;
    options = (j['options'] as List).map(ScheduleOption.fromJson).toList();
    reasons = (j['reasons'] as List).cast<String>();
  }
  late final String outcome, message;
  late final List<ScheduleOption> options;
  late final List<String> reasons;
}

class AcademicMetric {
  const AcademicMetric(
    this.average,
    this.equivalent,
    this.countedCredits,
    this.weightedTotal,
  );
  final double? average, equivalent;
  final double countedCredits, weightedTotal;
  factory AcademicMetric.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['countedCredits'] is! num ||
        value['weightedTotal'] is! num ||
        (value['average'] != null && value['average'] is! num) ||
        (value['equivalent'] != null && value['equivalent'] is! num)) {
      throw const FormatException('Invalid academic metric');
    }
    final m = value;
    final credits = (m['countedCredits'] as num).toDouble(),
        total = (m['weightedTotal'] as num).toDouble(),
        average = (m['average'] as num?)?.toDouble(),
        points = (m['equivalent'] as num?)?.toDouble();
    if (!credits.isFinite ||
        credits < 0 ||
        !total.isFinite ||
        total < 0 ||
        (credits == 0
            ? (average != null || points != null || total != 0)
            : (average == null ||
                  points == null ||
                  !average.isFinite ||
                  average < 40 ||
                  average > 100 ||
                  !points.isFinite ||
                  points < 0 ||
                  points > 4 ||
                  (total / credits - average).abs() > .00501))) {
      throw const FormatException('Invalid academic metric');
    }
    return AcademicMetric(average, points, credits, total);
  }
}

class AcademicProfile {
  const AcademicProfile.unavailable({this.reason})
    : gpa = null,
      cgpa = null,
      semesterLabel = null,
      syncedAt = null,
      earnedCredits = null,
      calculation = null;
  const AcademicProfile({
    required this.gpa,
    required this.cgpa,
    required this.semesterLabel,
    required this.syncedAt,
    required this.earnedCredits,
    this.calculation,
    this.reason,
  });
  final AcademicMetric? gpa, cgpa;
  final String? semesterLabel, calculation, reason;
  final DateTime? syncedAt;
  final double? earnedCredits;
  bool get available => cgpa != null;
  static const unavailableMessage =
      'No academic results have been imported for this account yet.';
  String get importMessage => switch (reason) {
    'REPEAT_POLICY_REQUIRED' => 'SIS contains repeated course attempts. Enter your registrar-approved cumulative baseline manually.',
    'GRADE_DATA_INCOMPLETE' => 'SIS grade records are incomplete or use unsupported grades. Your manual entries are retained.',
    'NO_GRADED_COURSES' =>
      'No completed numeric grades are available in SIS yet.',
    'NO_STUDENT_RECORD' =>
      'No student academic record is available for this account.',
    _ => unavailableMessage,
  };
  factory AcademicProfile.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid academic results');
    }
    final j = value;
    if (j['source'] != 'sis') {
      throw const FormatException('Invalid result source');
    }
    if ((j['availability'] == 'empty' || j['availability'] == 'unavailable') &&
        j['summary'] == null) {
      return AcademicProfile.unavailable(reason: j['reason'] as String?);
    }
    if (j['availability'] != 'available') {
      throw const FormatException('Invalid academic availability');
    }
    if (j['summary'] is! Map<String, dynamic> ||
        j['syncedAt'] is! String ||
        DateTime.tryParse(j['syncedAt'] as String) == null) {
      throw const FormatException('Invalid academic results');
    }
    final s = j['summary'] as Map<String, dynamic>;
    if (s['semesterLabel'] is! String ||
        s['earnedCredits'] is! num ||
        !(s['earnedCredits'] as num).isFinite ||
        (s['earnedCredits'] as num) < 0) {
      throw const FormatException('Invalid academic summary');
    }
    return AcademicProfile(
      gpa: AcademicMetric.fromJson(s['gpa']),
      cgpa: AcademicMetric.fromJson(s['cgpa']),
      semesterLabel: s['semesterLabel'] as String,
      syncedAt: DateTime.parse(j['syncedAt'] as String),
      earnedCredits: (s['earnedCredits'] as num).toDouble(),
      calculation: j['calculation'] as String?,
    );
  }
}

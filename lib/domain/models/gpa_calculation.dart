/// Centralized, versioned policy. Calculate numeric averages first, then convert.
abstract final class GpaPolicy {
  static const version = 'uob-spring-2018-2019-floor-v1';
  static const tableSource =
      'https://www.balamand.edu.lb/Style%20Library/PDFs/CurrentStudents/AverageGPA.pdf';
  static const catalogueSource =
      'https://www.balamand.edu.lb/Style%20Library/PDFs/Catalogue/General-Section-Undergraduate.pdf';
  static const minimumGrade = 40.0, maximumGrade = 100.0;
  static const method =
      'Predictions for ordinary newly counted courses only. Semester average = '
      'sum(grade × counted credits) / counted credits. Cumulative projection = '
      '(prior cumulative weighted total + predicted weighted total) / '
      '(prior counted credits + predicted counted credits). A manual prior total '
      'is its numeric average × counted credits. A previous semester is already '
      'included in a cumulative baseline; never add it again. Earned credits '
      'are not necessarily counted credits. A /4 GPA cannot reconstruct a '
      'numeric /100 average. Repeats, withdrawals, transfer credits and special '
      'notations are outside this calculator’s scope. Final grades: 40–100. '
      'We convert the resulting numeric average using the detailed table’s '
      'Spring 2018-2019 column. For fractions, we use the lower integer before '
      'lookup. This conservative app convention is not a verified registrar '
      'rounding rule. Calculations keep full precision; only displayed values '
      'are rounded. Scenarios are temporary and clear when you leave.';

  static double equivalent(double average) {
    if (!average.isFinite || average < minimumGrade || average > maximumGrade) {
      throw ArgumentError.value(average, 'average', 'Expected 40–100.');
    }
    final value = average.floor();
    for (final (minimum, gpa) in const [
      (93, 4.0),
      (90, 3.9),
      (87, 3.7),
      (84, 3.5),
      (82, 3.3),
      (80, 3.0),
      (77, 2.7),
      (74, 2.5),
      (72, 2.3),
      (70, 2.0),
      (67, 1.7),
      (64, 1.5),
      (62, 1.3),
      (60, 1.0),
      (40, 0.0),
    ]) {
      if (value >= minimum) return gpa;
    }
    throw StateError('Unreachable policy interval.');
  }

  /// Plain decimal notation only; exponent/NaN/infinity cannot slip into forms.
  static double? number(String input) {
    final text = input.trim();
    if (!RegExp(r'^(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(text)) return null;
    final value = double.tryParse(text);
    return value != null && value.isFinite ? value : null;
  }

  static String? gradeError(String text) {
    final value = number(text);
    return value == null || value < minimumGrade || value > maximumGrade
        ? 'Enter a number from 40 to 100.'
        : null;
  }

  static String? creditsError(String text) {
    final value = number(text);
    return value == null || value <= 0
        ? 'Enter positive counted credits.'
        : null;
  }
}

enum BaselineMode { semesterOnly, firstSemester, manual }

class PredictedCourse {
  const PredictedCourse({
    required this.id,
    this.name = '',
    this.credits = '',
    this.grade = '',
  });
  final int id;
  final String name, credits, grade;
  String? get creditsError => GpaPolicy.creditsError(credits);
  String? get gradeError => GpaPolicy.gradeError(grade);
  String? get nameError => name.trim().isEmpty || name.runes.length > 100
      ? 'Enter a course name/code (up to 100 characters).'
      : null;
  bool get valid =>
      nameError == null &&
      GpaPolicy.creditsError(credits) == null &&
      GpaPolicy.gradeError(grade) == null;
  PredictedCourse copyWith({String? name, String? credits, String? grade}) =>
      PredictedCourse(
        id: id,
        name: name ?? this.name,
        credits: credits ?? this.credits,
        grade: grade ?? this.grade,
      );
}

class NumericBaseline {
  NumericBaseline({required this.countedCredits, required this.weightedTotal}) {
    if (!countedCredits.isFinite ||
        countedCredits < 0 ||
        !weightedTotal.isFinite ||
        (countedCredits == 0
            ? weightedTotal != 0
            : weightedTotal / countedCredits < GpaPolicy.minimumGrade ||
                  weightedTotal / countedCredits > GpaPolicy.maximumGrade)) {
      throw ArgumentError('Invalid numeric baseline.');
    }
  }
  final double countedCredits, weightedTotal;
}

class GpaPrediction {
  const GpaPrediction(this.average, this.countedCredits);
  final double average, countedCredits;
  double get equivalent => GpaPolicy.equivalent(average);
}

class GpaCalculation {
  const GpaCalculation({this.semester, this.cumulative, this.error});
  final GpaPrediction? semester, cumulative;
  final String? error;
  static GpaCalculation calculate(
    List<PredictedCourse> courses, {
    NumericBaseline? prior,
  }) {
    if (courses.isEmpty) return const GpaCalculation();
    if (courses.any((course) => !course.valid)) {
      return const GpaCalculation(
        error: 'Complete every course with a name, positive counted credits and a grade from 40 to 100.',
      );
    }
    var credits = 0.0, total = 0.0;
    for (final course in courses) {
      final weight = GpaPolicy.number(course.credits)!;
      credits += weight;
      total += weight * GpaPolicy.number(course.grade)!;
    }
    final combinedCredits = credits + (prior?.countedCredits ?? 0);
    final combinedTotal = total + (prior?.weightedTotal ?? 0);
    if (!credits.isFinite ||
        !total.isFinite ||
        !combinedCredits.isFinite ||
        !combinedTotal.isFinite) {
      return const GpaCalculation(
        error: 'The totals are too large. Check your credits.',
      );
    }
    return GpaCalculation(
      // Clamp only possible floating-point excursions beyond the mathematical
      // 40–100 bounds. Do not round intermediate averages or table boundaries.
      semester: GpaPrediction(
        (total / credits).clamp(GpaPolicy.minimumGrade, GpaPolicy.maximumGrade),
        credits,
      ),
      cumulative: prior == null
          ? null
          : GpaPrediction(
              (combinedTotal / combinedCredits).clamp(
                GpaPolicy.minimumGrade,
                GpaPolicy.maximumGrade,
              ),
              combinedCredits,
            ),
    );
  }
}

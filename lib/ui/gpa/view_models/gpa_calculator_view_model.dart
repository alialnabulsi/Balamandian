import 'package:flutter/foundation.dart';

import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/gpa_calculation.dart';
import 'academic_profile_view_model.dart';

class GpaCalculatorViewModel extends ChangeNotifier {
  GpaCalculatorViewModel({
    required AuthRepository auth,
    required ProfileRepository profiles,
    required AcademicRepository repository,
  }) : academic = AcademicProfileViewModel(
         auth: auth,
         profiles: profiles,
         repository: repository,
       ) {
    _accountEpoch = academic.epoch;
    academic.addListener(_sync);
  }
  final AcademicProfileViewModel academic;
  late int _accountEpoch;
  int generation = 0, _nextId = 0;
  BaselineMode mode = BaselineMode.manual;
  NumericBaseline? _imported;
  String priorAverage = '', priorCredits = '';
  List<PredictedCourse> _courses = const [];
  List<PredictedCourse> get courses => _courses;
  bool get eligible => academic.access == StudentAccess.eligible;
  String? get priorAverageError =>
      priorAverage.isEmpty ? null : GpaPolicy.gradeError(priorAverage);
  String? get priorCreditsError =>
      priorCredits.isEmpty || GpaPolicy.number(priorCredits) == 0
      ? null
      : GpaPolicy.creditsError(priorCredits);
  String get cumulativeHint {
    if (_courses.isEmpty) {
      return 'Add a course to project your cumulative average.';
    }
    if (baselineError case final error?) return error;
    if (mode == BaselineMode.semesterOnly) {
      return 'Select a manual cumulative baseline or explicitly choose First semester. Missing prior values are not zero.';
    }
    return 'Complete every course to see your cumulative projection.';
  }

  void _sync() {
    if (_accountEpoch != academic.epoch) {
      _accountEpoch = academic.epoch;
      _clear();
    }
    notifyListeners();
  }

  String? get baselineError {
    if (mode != BaselineMode.manual) return null;
    if (GpaPolicy.number(priorCredits) == 0) return null;
    if (GpaPolicy.gradeError(priorAverage) != null ||
        GpaPolicy.creditsError(priorCredits) != null) {
      return 'Enter your prior cumulative average /100 and positive GPA-counted credits. Choose First semester for zero prior credits.';
    }
    final total =
        GpaPolicy.number(priorAverage)! * GpaPolicy.number(priorCredits)!;
    return total.isFinite ? null : 'The prior weighted total is too large.';
  }

  GpaCalculation get calculation {
    if (!eligible) return const GpaCalculation();
    final prior =
        _imported ??
        (GpaPolicy.number(priorCredits) == 0
            ? NumericBaseline(countedCredits: 0, weightedTotal: 0)
            : mode == BaselineMode.firstSemester
            ? NumericBaseline(countedCredits: 0, weightedTotal: 0)
            : mode == BaselineMode.manual && baselineError == null
            ? NumericBaseline(
                countedCredits: GpaPolicy.number(priorCredits)!,
                weightedTotal:
                    GpaPolicy.number(priorAverage)! *
                    GpaPolicy.number(priorCredits)!,
              )
            : null);
    return GpaCalculation.calculate(_courses, prior: prior);
  }

  void selectMode(BaselineMode value) {
    if (!eligible) return;
    mode = value;
    notifyListeners();
  }

  Future<void> importSis() async {
    if (!eligible || academic.loading) return;
    final epoch = academic.epoch;
    await academic.load(synchronize: true);
    if (!eligible || epoch != academic.epoch || academic.error != null) return;
    final summary = academic.snapshot?.cgpa;
    if (summary == null) {
      academic.error =
          academic.snapshot?.importMessage ??
          'No academic results are available for this account yet.';
      notifyListeners();
      return;
    }
    {
      priorCredits = '${summary.countedCredits}';
      priorAverage = summary.average?.toString() ?? '';
      _imported = NumericBaseline(
        countedCredits: summary.countedCredits,
        weightedTotal: summary.weightedTotal,
      );
      generation++;
      mode = BaselineMode.manual;
      notifyListeners();
    }
  }

  void setBaseline({String? average, String? credits}) {
    _imported = null;
    if (!eligible) return;
    priorAverage = average ?? priorAverage;
    priorCredits = credits ?? priorCredits;
    notifyListeners();
  }

  void addCourse() {
    if (!eligible) return;
    _courses = List.unmodifiable([..._courses, PredictedCourse(id: ++_nextId)]);
    notifyListeners();
  }

  void updateCourse(PredictedCourse value) {
    if (!eligible) return;
    _courses = List.unmodifiable(
      _courses.map((course) => course.id == value.id ? value : course),
    );
    notifyListeners();
  }

  void removeCourse(int id) {
    if (!eligible) return;
    _courses = List.unmodifiable(_courses.where((course) => course.id != id));
    notifyListeners();
  }

  void _clear() {
    generation++;
    mode = BaselineMode.manual;
    _imported = null;
    priorAverage = priorCredits = '';
    _courses = const [];
  }

  void reset() {
    academic.invalidate();
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    academic.removeListener(_sync);
    academic.dispose();
    super.dispose();
  }
}

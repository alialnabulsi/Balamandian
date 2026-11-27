import 'package:balamandian/domain/models/gpa_calculation.dart';
import 'package:flutter_test/flutter_test.dart';

PredictedCourse course(String credits, String grade, [int id = 1]) =>
    PredictedCourse(id: id, name: 'Course $id', credits: credits, grade: grade);

void main() {
  test('unequal credits weight numeric grades before conversion', () {
    final result = GpaCalculation.calculate([
      course('1', '60'),
      course('3', '100', 2),
    ]);
    expect(result.semester!.average, 90);
    expect(result.semester!.equivalent, 3.9);
    expect(result.cumulative, isNull);
  });
  test(
    'nonoverlapping cumulative baseline uses weighted total exactly once',
    () {
      final result = GpaCalculation.calculate([
        course('6', '90'),
      ], prior: NumericBaseline(countedCredits: 30, weightedTotal: 75 * 30));
      expect(result.cumulative!.average, 77.5);
      expect(result.cumulative!.countedCredits, 36);
      expect(result.cumulative!.equivalent, 2.7);
      // A previous semester is not a separate argument or added again.
      final authoritative = GpaCalculation.calculate([
        course('6', '90'),
      ], prior: NumericBaseline(countedCredits: 30, weightedTotal: 2249.85));
      expect(authoritative.cumulative!.average, closeTo(2789.85 / 36, 1e-12));
    },
  );
  test('first semester is explicit; missing prior data is not zero', () {
    final courses = [course('3', '80')];
    expect(GpaCalculation.calculate(courses).cumulative, isNull);
    final first = GpaCalculation.calculate(
      courses,
      prior: NumericBaseline(countedCredits: 0, weightedTotal: 0),
    );
    expect(first.cumulative!.average, first.semester!.average);
    expect(GpaCalculation.calculate([]).semester, isNull);
  });
  test(
    'every integer in official Spring 2018-2019 column and all boundaries',
    () {
      const expected = <int, double>{
        100: 4,
        99: 4,
        98: 4,
        97: 4,
        96: 4,
        95: 4,
        94: 4,
        93: 4,
        92: 3.9,
        91: 3.9,
        90: 3.9,
        89: 3.7,
        88: 3.7,
        87: 3.7,
        86: 3.5,
        85: 3.5,
        84: 3.5,
        83: 3.3,
        82: 3.3,
        81: 3,
        80: 3,
        79: 2.7,
        78: 2.7,
        77: 2.7,
        76: 2.5,
        75: 2.5,
        74: 2.5,
        73: 2.3,
        72: 2.3,
        71: 2,
        70: 2,
        69: 1.7,
        68: 1.7,
        67: 1.7,
        66: 1.5,
        65: 1.5,
        64: 1.5,
        63: 1.3,
        62: 1.3,
        61: 1,
        60: 1,
      };
      for (var grade = 40; grade <= 100; grade++) {
        expect(
          GpaPolicy.equivalent(grade.toDouble()),
          expected[grade] ?? 0,
          reason: 'Grade $grade',
        );
        if (grade < 100) {
          expect(
            GpaPolicy.equivalent(grade + .9999),
            expected[grade] ?? 0,
            reason: 'Fraction above $grade',
          );
        }
      }
    },
  );
  test('fractional lookup floors and calculation retains precision', () {
    final result = GpaCalculation.calculate([
      course('1', '81.999999'),
      course('2', '82', 2),
    ]).semester!;
    expect(result.average, closeTo(81.99999966666667, 1e-12));
    expect(result.equivalent, 3);
    expect(GpaPolicy.equivalent(82), 3.3);
  });
  test('invalid, nonfinite, exponent, comma, incomplete and nonpositive input is rejected', () {
    for (final value in [
      '',
      'NaN',
      'Infinity',
      '-1',
      '1e2',
      '1,5',
      '0x50',
      ' ',
    ]) {
      expect(GpaPolicy.number(value), isNull);
      expect(GpaCalculation.calculate([course(value, '80')]).semester, isNull);
    }
    for (final value in ['0', '0.0']) {
      expect(GpaCalculation.calculate([course(value, '80')]).semester, isNull);
    }
    for (final value in ['39.99', '100.01', '4', 'NaN', '']) {
      expect(GpaCalculation.calculate([course('3', value)]).semester, isNull);
    }
    expect(GpaPolicy.number('.5'), .5);
    expect(
      GpaCalculation.calculate([
        const PredictedCourse(id: 1, credits: '3', grade: '80'),
      ]).error,
      isNotNull,
    );
    expect(
      GpaCalculation.calculate([course('3', '80'), course('', '90', 2)])
          .semester,
      isNull,
    );
    for (final value in [double.nan, double.infinity, 39.9, 100.1]) {
      expect(() => GpaPolicy.equivalent(value), throwsArgumentError);
    }
  });
  test('invalid authoritative baselines and overflowing totals cannot produce predictions', () {
    for (final pair in [
      (0.0, 1.0),
      (-1.0, 80.0),
      (3.0, 1.0),
      (double.infinity, 80.0),
    ]) {
      expect(
        () => NumericBaseline(countedCredits: pair.$1, weightedTotal: pair.$2),
        throwsArgumentError,
      );
    }
    final largeCredits = '1${'0' * 307}';
    expect(
      GpaCalculation.calculate([course(largeCredits, '100')]).error,
      isNotNull,
    );
  });
}

import 'dart:convert';

import 'package:balamandian/data/repositories/api_academic_repository.dart';
import 'package:balamandian/data/services/profile_api_service.dart';
import 'package:balamandian/domain/models/academic_profile.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';

const academicPayload = {
  'availability': 'unavailable',
  'reason': 'SIS_RESULTS_NOT_PROVIDED',
  'source': 'sis',
  'syncedAt': null,
  'summary': null,
};

void main() {
  test('read-only SIS calculation maps to private import response without a fake publication field', () async {
    final api = ProfileApiService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/profile/me/academics/sync');
        expect(request.headers['Authorization'], 'Bearer session');
        return http.Response(
          jsonEncode({
            'data': {
              'availability': 'available',
              'source': 'sis',
              'calculation': 'numeric_enrollments',
              'syncedAt': '2026-11-27T12:00:00Z',
              'summary': {
                'semesterId': '1',
                'semesterLabel': 'Fall 2026',
                'gpa': {
                  'average': 90,
                  'equivalent': 3.9,
                  'countedCredits': 3,
                  'weightedTotal': 270,
                },
                'cgpa': {
                  'average': 80.1,
                  'equivalent': 3,
                  'countedCredits': 30,
                  'weightedTotal': 2403,
                },
                'earnedCredits': 27,
              },
            },
          }),
          200,
        );
      }),
      baseUrl: Uri.parse('https://api.example.edu'),
    );
    addTearDown(api.close);
    final result = await api.syncAcademics('session');
    expect(result.cgpa!.weightedTotal, 2403);
    expect(result.calculation, 'numeric_enrollments');
    expect(
      AcademicProfile.fromJson({
        'availability': 'empty',
        'source': 'sis',
        'reason': 'REPEAT_POLICY_REQUIRED',
        'summary': null,
      }).importMessage,
      contains('repeated course attempts'),
    );
  });
  test(
    'actual backend contract maps absence without inventing a zero baseline',
    () {
      expect(AcademicProfile.fromJson(academicPayload), isA<AcademicProfile>());
      for (final data in [
        null,
        {},
        {
          ...academicPayload,
          'summary': {'gpa': 4},
        },
      ]) {
        expect(() => AcademicProfile.fromJson(data), throwsFormatException);
      }
    },
  );
  test('saved import uses existing bearer boundary and only the owner API, with no SIS request', () async {
    var calls = 0, sessions = 0;
    final api = ProfileApiService(
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.edu/api/v1/profile/me/academics',
        );
        expect(request.headers['Authorization'], 'Bearer private-session');
        expect(request.body, isEmpty);
        return http.Response(jsonEncode({'data': academicPayload}), 200);
      }),
      baseUrl: Uri.parse('https://api.example.edu'),
    );
    addTearDown(api.close);
    final repo = ApiAcademicRepository(
      api: api,
      withSession: <T>(request) {
        sessions++;
        return request('private-session');
      },
    );
    await repo.loadSaved();
    await repo.loadSaved();
    expect(calls, 2);
    expect(sessions, 2);
  });
  test(
    'protected 401 uses existing expiry handling; role errors retain safe code',
    () async {
      for (final code in ['UNAUTHENTICATED', 'ACADEMICS_FORBIDDEN']) {
        final api = ProfileApiService(
          client: MockClient(
            (_) async =>
                failure(code, status: code == 'UNAUTHENTICATED' ? 401 : 403),
          ),
          baseUrl: Uri.parse('https://api.example.edu'),
        );
        addTearDown(api.close);
        await expectLater(
          api.academics('token'),
          throwsA(
            code == 'UNAUTHENTICATED'
                ? isA<AuthFailure>()
                : isA<ProfileFailure>().having((e) => e.code, 'code', code),
          ),
        );
      }
    },
  );
}

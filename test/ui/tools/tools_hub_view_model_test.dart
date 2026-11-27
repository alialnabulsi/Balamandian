import 'dart:async';

import 'package:balamandian/data/services/external_url_service.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/tools/view_models/tools_hub_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';

void setRoles(FakeProfileRepository profiles, List<String> roles) {
  profiles.ownData = {
    ...profileJson(),
    'roles': roles,
    'account': {
      ...profileJson()['account']! as Map<String, Object?>,
      'institutionalRoles': roles,
    },
  };
}

void main() {
  for (final policy in <(List<String>, Set<CampusTool>)>[
    (['student'], CampusTool.values.toSet()),
    (['advisor'], CampusTool.values.where((t) => t != CampusTool.gpa).toSet()),
    (['advisor', 'student'], CampusTool.values.toSet()),
    (['instructor'], {CampusTool.calendar}),
    (['staff'], {CampusTool.calendar}),
    ([], {CampusTool.calendar}),
  ]) {
    test('Actual role list ${policy.$1} determines availability', () async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      setRoles(profiles, policy.$1);
      await profiles.loadOwn();
      final model = ToolsHubViewModel(
        auth: auth.repository,
        profiles: profiles,
        externalUrls: FakeExternalUrlService(),
      );
      addTearDown(model.dispose);
      expect(model.isGuest, isFalse);
      for (final tool in CampusTool.values) {
        expect(
          model.availability(tool),
          policy.$2.contains(tool)
              ? ToolAvailability.available
              : ToolAvailability.ineligible,
        );
      }
    });
  }

  test(
    'Guest has public Calendar and sign-in actions for five tools',
    () async {
      final auth = AuthTestHarness((_) async => fail('No request expected'));
      addTearDown(auth.close);
      await auth.repository.restoreSession();
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      // Even a leftover profile cannot grant guest availability.
      await profiles.loadOwn();
      final model = ToolsHubViewModel(
        auth: auth.repository,
        profiles: profiles,
        externalUrls: FakeExternalUrlService(),
      );
      addTearDown(model.dispose);
      expect(model.isGuest, isTrue);
      expect(model.rolesLoading, isFalse);
      expect(
        model.availability(CampusTool.calendar),
        ToolAvailability.available,
      );
      expect(model.availability(CampusTool.notes), ToolAvailability.signIn);
      expect(auth.store.writes, 0);
    },
  );

  test(
    'Profile failure, retry, account switch and logout never reuse roles',
    () async {
      var secondAccount = false;
      final auth = AuthTestHarness((request) async {
        if (request.url.path.endsWith('/logout')) return http.Response('', 204);
        final data = sessionData();
        if (secondAccount) {
          data['user'] = {...data['user']! as Map, 'id': otherId};
        }
        return success(data, 200);
      });
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      final model = ToolsHubViewModel(
        auth: auth.repository,
        profiles: profiles,
        externalUrls: FakeExternalUrlService(),
      );
      addTearDown(model.dispose);
      expect(model.isGuest, isFalse);
      expect(model.rolesLoading, isTrue);
      expect(model.availability(CampusTool.gpa), ToolAvailability.loading);
      profiles.failure = 'Your profile could not be loaded. Please retry.';
      profiles.notifyListeners();
      expect(model.availability(CampusTool.gpa), ToolAvailability.profileError);
      expect(model.isGuest, isFalse);
      profiles.failure = null;
      await model.retryProfile();
      expect(model.availability(CampusTool.gpa), ToolAvailability.available);
      secondAccount = true;
      await auth.repository.login('FICTION002', 'test');
      // The old profile deliberately remains in the fake repository.
      expect(model.availability(CampusTool.gpa), ToolAvailability.loading);
      expect(model.isGuest, isFalse);
      await auth.repository.logout();
      expect(model.availability(CampusTool.gpa), ToolAvailability.signIn);
      expect(model.roleError, isNull);
      expect(auth.repository.status, SessionStatus.unauthenticated);
    },
  );

  test('Owner institutional roles are used when public roles differ', () async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FICTION001', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, ['advisor']);
    profiles.ownData = {
      ...profiles.ownData,
      'roles': ['student'],
    };
    await profiles.loadOwn();
    final model = ToolsHubViewModel(
      auth: auth.repository,
      profiles: profiles,
      externalUrls: FakeExternalUrlService(),
    );
    addTearDown(model.dispose);
    expect(model.availability(CampusTool.gpa), ToolAvailability.ineligible);
  });

  test('Public links launch exactly; failures remain retryable', () async {
    final auth = AuthTestHarness((_) async => fail('No request expected'));
    addTearDown(auth.close);
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    final external = FakeExternalUrlService();
    final model = ToolsHubViewModel(
      auth: auth.repository,
      profiles: profiles,
      externalUrls: external,
    );
    addTearDown(model.dispose);
    final links = [
      UniversityLinks.sis,
      UniversityLinks.moodle,
      UniversityLinks.imail,
      UniversityLinks.academicCalendar,
    ];
    for (final uri in links) {
      await model.openLink(uri);
      expect(model.linkError, isNull);
    }
    expect(external.launched, links);
    expect(links.every((uri) => uri.scheme == 'https'), isTrue);
    external.result = false;
    await model.openLink(UniversityLinks.sis);
    expect(model.linkError, contains('could not be opened'));
    external.failure = StateError('Platform unavailable');
    await model.openLink(UniversityLinks.imail);
    expect(model.linkError, contains('could not be opened'));
    external.failure = null;
    external.result = true;
    await model.openLink(UniversityLinks.imail);
    expect(model.linkError, isNull);
    expect(model.launching, isFalse);
  });

  test(
    'In-flight link result cannot publish after account change or disposal',
    () async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.restoreSession();
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      final external = PendingExternalUrls();
      final model = ToolsHubViewModel(
        auth: auth.repository,
        profiles: profiles,
        externalUrls: external,
      );
      final pending = model.openLink(UniversityLinks.sis);
      expect(model.launching, isTrue);
      await model.openLink(UniversityLinks.imail);
      expect(external.calls, 1);
      await auth.repository.login('FICTION001', 'test');
      external.reply.complete(false);
      await pending;
      expect(model.linkError, isNull);
      expect(model.launching, isFalse);
      model.dispose();
      await model.openLink(UniversityLinks.imail);
      expect(external.calls, 1);
    },
  );
}

class PendingExternalUrls implements ExternalUrlService {
  final reply = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> launch(Uri uri) {
    calls++;
    return reply.future;
  }
}

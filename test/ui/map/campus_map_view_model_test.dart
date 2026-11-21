import 'dart:convert';

import 'package:balamandian/data/repositories/campus_location_repository.dart';
import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:balamandian/domain/models/campus/navigation_fix.dart';
import 'package:balamandian/domain/models/campus/campus_data.dart';
import 'package:balamandian/domain/services/destination_search.dart';
import 'package:balamandian/ui/map/view_models/campus_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';

void main() {
  test(
    'Ending real navigation retains the fix; session reset clears tracking',
    () async {
      // Exercise the real provider flow with test coordinates, never production assets.
      final docs = campusDocuments();
      final metadata = jsonDecode(docs['campus']!) as Map<String, dynamic>;
      metadata['fixture'] = false;
      docs['campus'] = jsonEncode(metadata);
      final data = CampusDatasetService().parse(docs);
      final gps = FakeCampusLocationService();
      final vm = CampusMapViewModel(
        repository: FakeCampusRepository(data),
        location: CampusLocationRepository(gps),
      );
      addTearDown(() {
        vm.dispose();
        gps.dispose();
      });
      await vm.load();
      await vm.select(data.destinations['demo-east']!);
      vm.directions();
      await vm.locate(asOrigin: true);
      final fix = NavigationFix(
        point: data.nodes['a']!.point,
        accuracy: 3,
        time: DateTime.now(),
      );
      gps.controller.add(fix);
      await vm.calculate();
      await vm.beginNavigation();
      expect(vm.navigating, isTrue);
      vm.endNavigation();
      expect(vm.fix, same(fix));
      expect(gps.tracking, isTrue);
      vm.resetSession();
      await Future<void>.delayed(Duration.zero);
      expect(vm.fix, isNull);
      expect(vm.plannedRoute, isNull);
      expect(gps.tracking, isFalse);
    },
  );
  late FakeCampusRepository repository;
  late FakeCampusLocationService location;
  late CampusMapViewModel model;
  setUp(() {
    repository = FakeCampusRepository(campusFixture());
    location = FakeCampusLocationService();
    model = CampusMapViewModel(
      repository: repository,
      location: CampusLocationRepository(location),
    );
  });
  tearDown(() {
    model.dispose();
    location.dispose();
  });
  Future<void> prepare() async {
    await model.load();
    await model.select(model.data!.destinations['demo-east']!);
    model.directions();
    model.startAtEntrance(model.data!.entrances['demo-west-door']!);
    await model.calculate();
  }

  test(
    'Load retries errors; cached state does not reload on tab changes',
    () async {
      repository.fail = true;
      await model.load();
      expect(model.error, isNotNull);
      repository.fail = false;
      await model.load();
      expect(model.data, isNotNull);
      model.visibility(false);
      model.visibility(true);
      await model.load();
      expect(repository.loads, 2);
    },
  );
  test(
    'Selection, planning, swap and close preserve valid transitions',
    () async {
      await prepare();
      expect(model.mode, CampusMapMode.planning);
      expect(model.plannedRoute, isNotNull);
      model.swap();
      expect(model.selected!.id, 'demo-west');
      expect(model.startDestinationId, 'demo-east');
      expect(model.plannedRoute, isNull);
      await model.calculate();
      expect(model.plannedRoute, isNotNull);
      model.closeSelection();
      expect(model.mode, CampusMapMode.explore);
      expect(model.selected, isNull);
    },
  );
  test(
    'Native adapter can fail and recover without losing local routing',
    () async {
      await prepare();
      final map = FakeCampusMapAdapter()..fail = true;
      await model.attach(map, dark: false);
      expect(model.mapError, isNotNull);
      map.fail = false;
      await model.attach(map, dark: true);
      expect(model.mapError, isNull);
      expect(map.renderedRoute, isNotNull);
      expect(map.installs, 1);
      model.detach(map);
      expect(model.mapAttached, isFalse);
    },
  );
  for (final access in [
    LocationAccess.denied,
    LocationAccess.permanentlyDenied,
    LocationAccess.disabled,
    LocationAccess.unavailable,
  ]) {
    test('$access does not prevent manual route planning', () async {
      location.state = access;
      await model.load();
      await model.locate(asOrigin: true);
      expect(model.locationAccess, access);
      expect(location.tracking, isFalse);
      await prepare();
      expect(model.plannedRoute, isNotNull);
      await model.locationSettings();
      expect(location.settingsOpened, 1);
    });
  }
  test(
    'GPS is contextual, foreground only, and resumes without requesting again',
    () async {
      await model.load();
      expect(location.requests, 0);
      expect(location.tracking, isFalse);
      await model.locate();
      expect(location.tracking, isTrue);
      expect(location.requests, 1);
      location.controller.add(
        NavigationFix(
          point: model.data!.center,
          accuracy: 65,
          time: DateTime.now(),
        ),
      );
      expect(model.locationAccess, LocationAccess.ready);
      expect(model.fix!.accuracy, 65);
      model.foreground(false);
      await Future<void>.delayed(Duration.zero);
      expect(location.tracking, isFalse);
      model.foreground(true);
      await Future<void>.delayed(Duration.zero);
      expect(location.tracking, isTrue);
      expect(location.requests, 1);
      model.visibility(false);
      await Future<void>.delayed(Duration.zero);
      expect(location.tracking, isFalse);
    },
  );
  testWidgets(
    'Simulation is labeled state, pauses on app suspension, and restores shell focus',
    (tester) async {
      await tester.runAsync(prepare);
      await model.beginNavigation(simulate: true);
      expect(model.mode, CampusMapMode.navigating);
      expect(model.simulated, isTrue);
      expect(model.navigationFocus.value, isTrue);
      expect(location.tracking, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(model.progress!.traveled, greaterThan(0));
      model.simulationSpeedTo(4);
      expect(model.simulationSpeed, 4);
      model.foreground(false);
      expect(model.simulationPaused, isTrue);
      model.foreground(true);
      expect(model.simulationPaused, isTrue);
      model.pauseSimulation();
      expect(model.simulationPaused, isFalse);
      model.endNavigation();
      expect(model.simulated, isFalse);
      expect(model.navigationFocus.value, isFalse);
      expect(model.mode, CampusMapMode.planning);
    },
  );
  test(
    'Real GPS navigation cannot run on synthetic demonstration geography',
    () async {
      await prepare();
      await model.beginNavigation();
      expect(model.mode, CampusMapMode.planning);
      expect(model.error, contains('synthetic'));
    },
  );
  test('Disposal during permission request cannot attach a stream', () async {
    final pending = model.locate();
    model.visibility(false);
    await pending;
    expect(location.tracking, isFalse);
  });
  test(
    'Search cancellation preserves context and ignores late edits',
    () async {
      await model.load();
      model.beginSearch();
      model.searchFor('LIB');
      expect(model.results.single.code, 'LIB');
      model.category('Gates');
      expect(model.results, isEmpty);
      model.cancelSearch();
      expect(model.searching, isFalse);
      expect(model.query, 'LIB');
      expect(model.queryCategory, 'Gates');
      model.searchFor('late result');
      expect(model.query, 'LIB');
    },
  );

  test(
    'One primary context, planner back, and session-scoped campus dismissal',
    () async {
      await model.load();
      model.dismissCampus();
      model.beginSearch();
      model.searchFor('LIB');
      await model.select(model.results.single);
      expect(model.searching, isFalse);
      expect(model.mode, CampusMapMode.selected);
      model.directions();
      expect(model.mode, CampusMapMode.planning);
      model.closeContext();
      expect(model.mode, CampusMapMode.selected);
      model.closeContext();
      expect(model.mode, CampusMapMode.explore);
      model.visibility(false);
      model.visibility(true);
      expect(model.campusSheetDismissed, isTrue);
      model.beginSearch();
      expect(model.query, 'LIB');
      expect(model.results.single.code, 'LIB');
      model.resetSession();
      expect(model.campusSheetDismissed, isFalse);
      expect(model.mode, CampusMapMode.explore);
    },
  );

  test(
    'Camera requests cancel on dismissal and passive changes never focus',
    () async {
      await model.load();
      final map = FakeCampusMapAdapter();
      await model.attach(map, dark: false);
      await model.select(model.data!.destinations['demo-east']!);
      final stale = model.cameraRequest!.revision;
      model.closeSelection();
      await model.frameCamera(stale);
      model.viewport(top: 80, right: 76, bottom: 240, legalBottom: 216);
      model.beginSearch();
      model.cancelSearch();
      model.visibility(false);
      model.visibility(true);
      await Future<void>.delayed(Duration.zero);
      expect(map.focuses, 0);
      expect(map.fits, 0);
      expect(map.selectedDestination, isNull);
      await model.select(model.data!.destinations['demo-east']!);
      await model.frameCamera(model.cameraRequest!.revision);
      expect(map.focuses, 1);
      expect(map.selectedDestination, 'demo-east');
      await model.select(model.data!.destinations['demo-east']!);
      expect(model.cameraRequest, isNull);
    },
  );

  test('Closing planning cancels an in-flight route calculation', () async {
    await model.load();
    await model.select(model.data!.destinations['demo-east']!);
    model.directions();
    model.startAtEntrance(model.data!.entrances['demo-west-door']!);
    final pending = model.calculate();
    model.closePlanning();
    await pending;
    expect(model.mode, CampusMapMode.selected);
    expect(model.plannedRoute, isNull);
    expect(model.calculating, isFalse);
  });

  test(
    'Repeated location taps share a single permission acquisition',
    () async {
      await model.load();
      await Future.wait([model.locate(), model.locate(), model.locate()]);
      expect(location.requests, 1);
      expect(model.locationAccess, LocationAccess.acquiring);
      await model.locate();
      expect(location.requests, 1);
    },
  );

  test(
    'Production reference point never opens unavailable directions',
    () async {
      final production = CampusDatasetService().parse(
        campusDocuments(fixture: false),
      );
      final vm = CampusMapViewModel(
        repository: FakeCampusRepository(production),
        location: CampusLocationRepository(location),
      );
      addTearDown(vm.dispose);
      await vm.load();
      await vm.select(production.destinations.values.single);
      expect(vm.directionsAvailable, isFalse);
      vm.directions();
      expect(vm.mode, CampusMapMode.selected);
    },
  );

  test('A shared location acquisition can become the planner origin', () async {
    await model.load();
    final pending = model.locate();
    await model.locate(asOrigin: true);
    await pending;
    expect(location.requests, 1);
    expect(model.usingGps, isTrue);
    expect(model.startLabel, 'Current location');
  });

  test(
    'A cancelled calculation cannot clear the newer loading state',
    () async {
      await model.load();
      await model.select(model.data!.destinations['demo-east']!);
      model.directions();
      model.startAtEntrance(model.data!.entrances['demo-west-door']!);
      final first = model.calculate();
      model.closePlanning();
      model.directions();
      final second = model.calculate();
      await first;
      expect(model.calculating, isTrue);
      await second;
      expect(model.calculating, isFalse);
      expect(model.plannedRoute, isNotNull);
    },
  );

  test(
    'Search distinguishes dataset loading, empty results and failures',
    () async {
      final pending = model.load();
      expect(model.searchSnapshot.loading, isTrue);
      await pending;
      model.beginSearch();
      model.searchFor('no-such-place');
      expect(model.searchSnapshot.places, isEmpty);
      expect(model.searchSnapshot.error, isNull);
      final failing = CampusMapViewModel(
        repository: repository,
        location: CampusLocationRepository(location),
        search: const _FailedSearch(),
      );
      addTearDown(failing.dispose);
      await failing.load();
      failing.beginSearch();
      expect(failing.searchSnapshot.error, isNotNull);
      expect(failing.searchSnapshot.loading, isFalse);
      failing.cancelSearch();
      failing.retrySearch();
      expect(failing.mode, CampusMapMode.explore);
    },
  );
}

class _FailedSearch extends DestinationSearch {
  const _FailedSearch();
  @override
  List<CampusDestination> search(
    Iterable<CampusDestination> destinations,
    String query, {
    String? category,
  }) => throw StateError('Local index unavailable');
}

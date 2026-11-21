import 'dart:async';
import 'dart:io';

import 'package:balamandian/data/repositories/campus_repository.dart';
import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:balamandian/data/services/campus_location_service.dart';
import 'package:balamandian/domain/models/campus/campus_data.dart';
import 'package:balamandian/domain/models/campus/campus_route.dart';
import 'package:balamandian/domain/models/campus/geo_point.dart';
import 'package:balamandian/domain/models/campus/navigation_fix.dart';
import 'package:balamandian/ui/map/mapbox/campus_map_adapter.dart';

Map<String, String> campusDocuments({bool fixture = true}) {
  final path = fixture ? 'assets/maps/fixtures' : 'assets/maps/campus';
  return {
    'campus': File('$path/campus.json').readAsStringSync(),
    for (final file in CampusDatasetService.files)
      file: File('$path/$file.geojson').readAsStringSync(),
  };
}

CampusData campusFixture() => CampusDatasetService().parse(campusDocuments());

class FakeCampusRepository implements CampusRepository {
  FakeCampusRepository(this.data);
  final CampusData data;
  int loads = 0;
  bool fail = false;
  @override
  Future<CampusData> load() async {
    loads++;
    if (fail) throw const FormatException('bad data');
    return data;
  }
}

class FakeCampusLocationService implements CampusLocationService {
  LocationAccess state = LocationAccess.ready;
  int requests = 0, settingsOpened = 0;
  final controller = StreamController<NavigationFix>.broadcast(sync: true);
  bool get tracking => controller.hasListener;
  @override
  Future<LocationAccess> access({required bool request}) async {
    if (request) requests++;
    return state;
  }

  @override
  Stream<NavigationFix> watch() => controller.stream;
  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() => openAppSettings();
  void dispose() => unawaited(controller.close());
}

class FakeCampusMapAdapter implements CampusMapAdapter {
  @override
  Future<void> viewport({
    required double top,
    required double right,
    required double bottom,
    required double legalBottom,
  }) async {}
  int installs = 0, fits = 0, positions = 0, focuses = 0, overviews = 0;
  String? selected, selectedDestination;
  CampusRoute? renderedRoute;
  bool fail = false;
  @override
  Future<void> install(
    CampusData data, {
    required bool debugGraph,
    required bool dark,
  }) async {
    if (fail) throw StateError('native renderer unavailable');
    installs++;
  }

  @override
  Future<void> route(CampusRoute? route) async {
    renderedRoute = route;
  }

  @override
  Future<void> fit(CampusRoute route) async {
    fits++;
  }

  @override
  Future<void> highlight(String? buildingId) async {
    selected = buildingId;
  }

  @override
  Future<void> selectDestination(String? destinationId) async {
    selectedDestination = destinationId;
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> position(NavigationFix? fix, {required bool simulated}) async {
    positions++;
  }

  @override
  Future<void> focus(
    GeoPoint point, {
    double? heading,
    bool navigation = false,
  }) async {
    focuses++;
  }

  @override
  Future<void> overview() async {
    overviews++;
  }

  @override
  Future<void> north() async {}
  @override
  Future<void> perspective(bool threeDimensional) async {}
  @override
  Future<void> light(bool dark) async {}
}

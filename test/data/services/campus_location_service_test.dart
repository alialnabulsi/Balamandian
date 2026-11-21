import 'package:balamandian/data/services/campus_location_service.dart';
import 'package:balamandian/domain/models/campus/navigation_fix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _PlatformLocation extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission response = LocationPermission.whileInUse;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return response;
  }
}

void main() {
  late GeolocatorPlatform previous;
  late _PlatformLocation platform;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = _PlatformLocation();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() {
    GeolocatorPlatform.instance = previous;
  });
  test('Permission is requested only by a contextual action', () async {
    final service = ForegroundCampusLocationService();
    expect(await service.access(request: false), LocationAccess.denied);
    expect(platform.requests, 0);
    expect(await service.access(request: true), LocationAccess.ready);
    expect(platform.requests, 1);
  });
  test('Permanent denial and disabled services do not request permission repeatedly', () async {
    final service = ForegroundCampusLocationService();
    platform.permission = LocationPermission.deniedForever;
    expect(
      await service.access(request: true),
      LocationAccess.permanentlyDenied,
    );
    expect(platform.requests, 0);
    platform.enabled = false;
    expect(await service.access(request: true), LocationAccess.disabled);
    expect(platform.requests, 0);
  });
  test(
    'Denied runtime request is explicit and foreground grants are accepted',
    () async {
      final service = ForegroundCampusLocationService();
      platform.response = LocationPermission.denied;
      expect(await service.access(request: true), LocationAccess.denied);
      platform.permission = LocationPermission.whileInUse;
      expect(await service.access(request: false), LocationAccess.ready);
    },
  );
}

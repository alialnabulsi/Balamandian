import 'package:geolocator/geolocator.dart';

import '../../domain/models/campus/geo_point.dart';
import '../../domain/models/campus/navigation_fix.dart';

abstract class CampusLocationService {
  Future<LocationAccess> access({required bool request});
  Stream<NavigationFix> watch();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class ForegroundCampusLocationService implements CampusLocationService {
  @override
  Future<LocationAccess> access({required bool request}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.disabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.denied => LocationAccess.denied,
      LocationPermission.deniedForever => LocationAccess.permanentlyDenied,
      LocationPermission.whileInUse ||
      LocationPermission.always => LocationAccess.ready,
      _ => LocationAccess.unavailable,
    };
  }

  @override
  Stream<NavigationFix> watch() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).map(
        (p) => NavigationFix(
          point: GeoPoint(p.longitude, p.latitude),
          accuracy: p.accuracy,
          time: p.timestamp,
          heading: p.heading.isFinite && p.heading >= 0 ? p.heading : null,
        ),
      );
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

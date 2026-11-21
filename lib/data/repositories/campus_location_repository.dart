import '../../domain/models/campus/navigation_fix.dart';
import '../services/campus_location_service.dart';

class CampusLocationRepository {
  const CampusLocationRepository(this.service);
  final CampusLocationService service;
  Future<LocationAccess> access({bool request = false}) =>
      service.access(request: request);
  Stream<NavigationFix> get fixes => service.watch();
  Future<bool> settings(LocationAccess state) =>
      state == LocationAccess.disabled
      ? service.openLocationSettings()
      : service.openAppSettings();
}

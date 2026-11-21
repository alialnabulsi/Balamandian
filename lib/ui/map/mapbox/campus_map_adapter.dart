import '../../../domain/models/campus/campus_data.dart';
import '../../../domain/models/campus/campus_route.dart';
import '../../../domain/models/campus/geo_point.dart';
import '../../../domain/models/campus/navigation_fix.dart';

/// Native rendering boundary. Pure routing never imports Mapbox SDK types.
abstract class CampusMapAdapter {
  Future<void> viewport({
    required double top,
    required double right,
    required double bottom,
    required double legalBottom,
  });
  Future<void> install(
    CampusData data, {
    required bool debugGraph,
    required bool dark,
  });
  Future<void> route(CampusRoute? route);
  Future<void> highlight(String? buildingId);
  Future<void> selectDestination(String? destinationId);
  Future<void> reload();
  Future<void> position(NavigationFix? fix, {required bool simulated});
  Future<void> focus(
    GeoPoint point, {
    double? heading,
    bool navigation = false,
  });
  Future<void> fit(CampusRoute route);
  Future<void> overview();
  Future<void> north();
  Future<void> perspective(bool threeDimensional);
  Future<void> light(bool dark);
}

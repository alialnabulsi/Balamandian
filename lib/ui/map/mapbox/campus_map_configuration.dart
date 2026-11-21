import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

abstract final class CampusMapConfiguration {
  static const publicToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static bool get configured =>
      publicToken.startsWith('pk.') && publicToken.length > 10;
  static void initialize() {
    if (configured) MapboxOptions.setAccessToken(publicToken);
  }
}

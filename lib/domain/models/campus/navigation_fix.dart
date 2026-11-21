import 'geo_point.dart';

class NavigationFix {
  const NavigationFix({
    required this.point,
    required this.accuracy,
    required this.time,
    this.heading,
  });
  final GeoPoint point;
  final double accuracy;
  final DateTime time;
  final double? heading;
}

enum LocationAccess {
  idle,
  acquiring,
  ready,
  denied,
  permanentlyDenied,
  disabled,
  unavailable,
}

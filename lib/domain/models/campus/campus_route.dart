import 'campus_data.dart';
import 'geo_point.dart';

class RouteArc {
  const RouteArc(this.edge, this.from, this.to, this.points);
  final PedestrianEdge edge;
  final String from, to;
  final List<GeoPoint> points;
  double get distance => lineLength(points);
}

class CampusRoute {
  CampusRoute({
    required List<RouteArc> arcs,
    required this.start,
    required this.end,
    this.entranceId,
    this.walkingSpeed = 1.25,
    double? cost,
  }) : arcs = List.unmodifiable(arcs) {
    if (!walkingSpeed.isFinite || walkingSpeed <= 0) {
      throw ArgumentError('Invalid walking speed.');
    }
    final joined = <GeoPoint>[start];
    for (final arc in arcs) {
      for (final p in arc.points) {
        if (joined.last.distanceTo(p) > .001) joined.add(p);
      }
    }
    points = List.unmodifiable(joined);
    distance = arcs.fold(0.0, (sum, arc) => sum + arc.distance);
    this.cost = cost ?? distance;
  }
  final List<RouteArc> arcs;
  final GeoPoint start, end;
  final String? entranceId;
  final double walkingSpeed;
  late final List<GeoPoint> points;
  late final double distance;
  late final double cost;
  Duration get duration => Duration(seconds: (distance / walkingSpeed).ceil());
  bool get accessibilityVerified =>
      arcs.isNotEmpty &&
      arcs.every(
        (a) =>
            a.edge.accessibility == PathAccessibility.verified &&
            a.edge.type != 'stairs',
      );
}

class RouteOrigin {
  const RouteOrigin.node(this.nodeId) : point = null, accuracy = null;
  const RouteOrigin.point(this.point, {this.accuracy}) : nodeId = null;
  final String? nodeId;
  final GeoPoint? point;
  final double? accuracy;
}

class CampusRoutingException implements Exception {
  const CampusRoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

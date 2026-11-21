import 'dart:math' as math;

import '../models/campus/campus_route.dart';
import '../models/campus/geo_point.dart';
import '../models/campus/navigation_fix.dart';

class WalkingManeuver {
  const WalkingManeuver(this.at, this.instruction);
  final double at;
  final String instruction;
}

class NavigationProgress {
  NavigationProgress(this.route) : maneuvers = _maneuvers(route);
  final CampusRoute route;
  final List<WalkingManeuver> maneuvers;
  double traveled = 0, deviation = 0;
  bool arrived = false, offRoute = false;
  int _deviations = 0;
  DateTime? _lastFix, _lastDeviation, _lastReroute;
  double get remaining => math.max(0, route.distance - traveled);
  int get remainingSeconds => (remaining / route.walkingSpeed).ceil();
  WalkingManeuver get upcoming {
    var start = 0.0;
    for (final arc in route.arcs) {
      if (traveled >= start - 3 && traveled < start + arc.distance) {
        final instruction = switch (arc.edge.type) {
          'stairs' => 'Take the stairs',
          'ramp' => 'Follow the ramp',
          'gate' => 'Pass through the gate',
          _ => null,
        };
        if (instruction != null) return WalkingManeuver(traveled, instruction);
      }
      start += arc.distance;
    }
    return maneuvers.firstWhere(
      (m) => m.at > 0 && m.at >= traveled - 3,
      orElse: () => WalkingManeuver(route.distance, 'Arrive at the entrance'),
    );
  }

  double get maneuverDistance => math.max(0, upcoming.at - traveled);

  /// Returns true once for a sustained deviation, then applies a 15s cooldown.
  bool update(NavigationFix fix) {
    if (!fix.accuracy.isFinite ||
        fix.accuracy < 0 ||
        fix.accuracy > 25 ||
        (_lastFix != null && !fix.time.isAfter(_lastFix!))) {
      return false;
    }
    if (route.points.length < 2) {
      arrived = fix.point.distanceTo(route.end) <= 8;
      return false;
    }
    final projection = projectOnLine(fix.point, route.points);
    deviation = projection.distance;
    final dt = _lastFix == null
        ? 5.0
        : fix.time.difference(_lastFix!).inMilliseconds / 1000;
    _lastFix = fix.time;
    if (deviation > math.max(18, fix.accuracy * 1.5)) {
      if (_lastDeviation == null ||
          fix.time.difference(_lastDeviation!).inSeconds >= 2) {
        _deviations++;
        _lastDeviation = fix.time;
      }
      offRoute = _deviations >= 3;
      if (offRoute &&
          (_lastReroute == null ||
              fix.time.difference(_lastReroute!).inSeconds >= 15)) {
        _lastReroute = fix.time;
        return true;
      }
      return false;
    }
    _deviations = 0;
    _lastDeviation = null;
    offRoute = false;
    // Reject implausible leaps across loops/parallel sections; retain progress
    // during short backtracking rather than jumping between route segments.
    if (projection.along <= traveled + math.max(20, dt * 4 + fix.accuracy)) {
      traveled = math.max(traveled, projection.along);
    }
    arrived =
        remaining <= 10 &&
        fix.point.distanceTo(route.end) <= 10 &&
        fix.accuracy <= 15;
    return false;
  }

  static List<WalkingManeuver> _maneuvers(CampusRoute route) {
    final result = <WalkingManeuver>[
      const WalkingManeuver(0, 'Follow the walking path'),
    ];
    final points = route.points;
    var walked = 0.0;
    for (var i = 1; i < points.length - 1; i++) {
      walked += points[i - 1].distanceTo(points[i]);
      if (points[i - 1].distanceTo(points[i]) < 4 ||
          points[i].distanceTo(points[i + 1]) < 4) {
        continue;
      }
      final angle =
          (points[i].bearingTo(points[i + 1]) -
                  points[i - 1].bearingTo(points[i]) +
                  540) %
              360 -
          180;
      if (angle.abs() >= 35) {
        result.add(
          WalkingManeuver(
            walked,
            angle.abs() > 150
                ? 'Turn around on the path'
                : angle > 0
                ? 'Turn right'
                : 'Turn left',
          ),
        );
      }
    }
    walked = 0;
    for (final arc in route.arcs) {
      if (arc.edge.type == 'stairs') {
        result.add(WalkingManeuver(walked, 'Take the stairs'));
      }
      walked += arc.distance;
    }
    result.add(WalkingManeuver(route.distance, 'Arrive at the entrance'));
    result.sort((a, b) => a.at.compareTo(b.at));
    return List.unmodifiable(result);
  }
}

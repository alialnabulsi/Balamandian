import 'package:balamandian/data/services/route_simulation_service.dart';
import 'package:balamandian/domain/models/campus/navigation_fix.dart';
import 'package:balamandian/domain/models/campus/geo_point.dart';
import 'package:balamandian/domain/services/campus_routing_service.dart';
import 'package:balamandian/domain/services/navigation_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';

void main() {
  final data = campusFixture();
  final route = const CampusRoutingService().find(data, 'a', 'e')!;
  final epoch = DateTime.utc(2026, 11, 20);
  test('A route starting on stairs announces stairs immediately', () {
    final stairRoute = const CampusRoutingService().find(data, 'b', 'd')!;
    final p = NavigationProgress(stairRoute);
    expect(p.upcoming.instruction, 'Take the stairs');
    expect(p.maneuverDistance, 0);
  });
  NavigationFix fix(GeoPoint p, int seconds, {double accuracy = 3}) =>
      NavigationFix(
        point: p,
        accuracy: accuracy,
        time: epoch.add(Duration(seconds: seconds)),
      );
  test('Follows geometry, derives guidance and arrives only near the end', () {
    final progress = NavigationProgress(route);
    expect(progress.maneuvers.last.instruction, contains('Arrive'));
    final total = lineLength(route.points);
    for (var s = 0; s < total / 1.25 + 10; s++) {
      final distance = (s * 1.25).clamp(0.0, total);
      progress.update(
        fix(sliceLine(route.points, distance, distance).first, s),
      );
    }
    expect(progress.arrived, isTrue);
    expect(progress.remaining, lessThanOrEqualTo(10));
  });
  test('Poor accuracy, stale updates and implausible leaps do not advance progress', () {
    final p = NavigationProgress(route);
    p.update(fix(route.start, 1));
    p.update(fix(route.end, 2, accuracy: 80));
    p.update(fix(route.end, 2));
    p.update(fix(route.end, 0));
    expect(p.traveled, 0);
    expect(p.arrived, isFalse);
  });
  test(
    'Off-route requires three spaced fixes and uses a rerouting cooldown',
    () {
      final p = NavigationProgress(route);
      const outside = GeoPoint(-.128, 51.532);
      expect(p.update(fix(outside, 1)), isFalse);
      expect(p.update(fix(outside, 2)), isFalse);
      expect(p.update(fix(outside, 3)), isFalse);
      expect(p.update(fix(outside, 5)), isTrue);
      expect(p.offRoute, isTrue);
      expect(p.update(fix(outside, 7)), isFalse);
      expect(p.update(fix(outside, 21)), isTrue);
      p.update(fix(route.start, 23));
      expect(p.offRoute, isFalse);
    },
  );
  test('Simulation follows route geometry, supports speed, pause/resume and clean stop', () async {
    final simulation = RouteSimulationService(route);
    final points = <NavigationFix>[];
    final subscription = simulation.fixes.listen(points.add);
    simulation.advance(const Duration(seconds: 4));
    expect(simulation.traveled, closeTo(5, .001));
    simulation.speed = 4;
    simulation.advance(const Duration(seconds: 4));
    expect(simulation.traveled, closeTo(25, .001));
    expect(
      points.last.point.distanceTo(sliceLine(route.points, 25, 25).first),
      lessThan(.01),
    );
    simulation.resume();
    expect(simulation.paused, isFalse);
    simulation.pause();
    expect(simulation.paused, isTrue);
    expect(() => simulation.speed = 0, throwsArgumentError);
    simulation.dispose();
    final count = points.length;
    simulation.advance(const Duration(seconds: 4));
    expect(points.length, count);
    await subscription.cancel();
  });
}

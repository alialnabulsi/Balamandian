import 'dart:async';

import '../../domain/models/campus/campus_route.dart';
import '../../domain/models/campus/geo_point.dart';
import '../../domain/models/campus/navigation_fix.dart';

/// Separate from GPS. The same NavigationProgress consumes both fix sources.
class RouteSimulationService {
  RouteSimulationService(this.route);
  final CampusRoute route;
  final _fixes = StreamController<NavigationFix>.broadcast(sync: true);
  final _watch = Stopwatch();
  Timer? _timer;
  double traveled = 0;
  double _speed = 1;
  double get speed => _speed;
  set speed(double value) {
    if (![1.0, 2.0, 4.0].contains(value)) {
      throw ArgumentError('Unsupported playback speed.');
    }
    _speed = value;
  }

  Stream<NavigationFix> get fixes => _fixes.stream;
  bool get paused => _timer == null;
  bool _disposed = false;

  void resume() {
    if (_disposed || _timer != null) return;
    _watch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final elapsed = _watch.elapsed;
      _watch.reset();
      advance(elapsed);
      if (traveled >= route.distance) pause();
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _watch.stop();
    _watch.reset();
  }

  /// Explicit elapsed-time input also makes demonstrations deterministic in tests.
  void advance(Duration elapsed) {
    if (_disposed || elapsed.isNegative) return;
    traveled =
        (traveled + elapsed.inMicroseconds / 1e6 * route.walkingSpeed * speed)
            .clamp(0, route.distance);
    final point = route.points.length < 2
        ? route.end
        : sliceLine(route.points, traveled, traveled).first;
    final projection = route.points.length < 2
        ? null
        : projectOnLine(point, route.points);
    final segment = projection?.segment ?? 0;
    _fixes.add(
      NavigationFix(
        point: point,
        accuracy: 1,
        time: DateTime.now(),
        heading: route.points.length < 2
            ? null
            : route.points[segment].bearingTo(route.points[segment + 1]),
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pause();
    unawaited(_fixes.close());
  }
}

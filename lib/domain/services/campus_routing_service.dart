import '../models/campus/campus_data.dart';
import '../models/campus/campus_route.dart';
import '../models/campus/geo_point.dart';

/// Policies may add nonnegative penalties; geometric distance remains a lower
/// bound, keeping the great-circle A* heuristic admissible and consistent.
class WalkingPolicy {
  const WalkingPolicy({
    this.avoidStairs = false,
    this.requireVerifiedAccess = false,
  });
  final bool avoidStairs, requireVerifiedAccess;
  bool permits(PedestrianEdge edge) =>
      !edge.restricted &&
      !(avoidStairs && edge.type == 'stairs') &&
      !(requireVerifiedAccess &&
          (edge.type == 'stairs' ||
              edge.accessibility != PathAccessibility.verified));
  double penalty(PedestrianEdge edge) => 0;
}

class CampusRoutingService {
  const CampusRoutingService();

  CampusRoute? find(
    CampusData data,
    String start,
    String goal, {
    WalkingPolicy policy = const WalkingPolicy(),
    bool dijkstra = false,
    List<RouteArc> extraArcs = const [],
    GeoPoint? virtualStart,
  }) {
    final coordinates = {
      for (final n in data.nodes.values) n.id: n.point,
      '@origin': ?virtualStart,
    };
    if (!coordinates.containsKey(start) || !coordinates.containsKey(goal)) {
      throw const CampusRoutingException('Choose a valid path entrance.');
    }
    final adjacent = <String, List<RouteArc>>{};
    void add(RouteArc arc) => adjacent.putIfAbsent(arc.from, () => []).add(arc);
    for (final e in data.edges.values) {
      if (!policy.permits(e)) continue;
      add(RouteArc(e, e.from, e.to, e.points));
      if (e.bidirectional) {
        add(RouteArc(e, e.to, e.from, e.points.reversed.toList()));
      }
    }
    for (final arc in extraArcs) {
      if (policy.permits(arc.edge)) add(arc);
    }
    for (final list in adjacent.values) {
      list.sort(
        (a, b) => '${a.edge.id}:${a.to}'.compareTo('${b.edge.id}:${b.to}'),
      );
    }
    // Account for endpoint digitizing tolerance without overestimating costs.
    var heuristicScale = 1.0;
    for (final arcs in adjacent.values) {
      for (final arc in arcs) {
        final direct = coordinates[arc.from]!.distanceTo(coordinates[arc.to]!);
        if (direct > 0 && arc.distance / direct < heuristicScale) {
          heuristicScale = arc.distance / direct;
        }
      }
    }
    final frontier = _MinHeap();
    final costs = <String, double>{start: 0};
    final previous = <String, RouteArc>{};
    double heuristic(String node) => dijkstra
        ? 0
        : coordinates[node]!.distanceTo(coordinates[goal]!) * heuristicScale;
    frontier.add(_Entry(start, heuristic(start), 0));
    while (frontier.isNotEmpty) {
      final current = frontier.remove();
      if (current.cost > costs[current.node]!) continue;
      if (current.node == goal) {
        final arcs = <RouteArc>[];
        var node = goal;
        while (node != start) {
          final arc = previous[node]!;
          arcs.add(arc);
          node = arc.from;
        }
        return CampusRoute(
          arcs: arcs.reversed.toList(),
          start: coordinates[start]!,
          end: coordinates[goal]!,
          cost: current.cost,
        );
      }
      for (final arc in adjacent[current.node] ?? <RouteArc>[]) {
        final penalty = policy.penalty(arc.edge);
        if (!penalty.isFinite || penalty < 0) {
          throw ArgumentError(
            'Routing penalties must be finite and nonnegative.',
          );
        }
        final candidate = current.cost + arc.distance + penalty;
        if (candidate >= (costs[arc.to] ?? double.infinity)) continue;
        costs[arc.to] = candidate;
        previous[arc.to] = arc;
        frontier.add(_Entry(arc.to, candidate + heuristic(arc.to), candidate));
      }
    }
    return null;
  }

  CampusRoute plan(
    CampusData data,
    RouteOrigin origin,
    CampusDestination destination, {
    WalkingPolicy policy = const WalkingPolicy(),
    String? entranceId,
  }) {
    if (!data.routingAvailable) {
      throw const CampusRoutingException(
        'Verified campus walkways and entrances are not available yet. You can still explore the map.',
      );
    }
    final targets = destination.entranceIds
        .where((id) => entranceId == null || entranceId == id)
        .map((id) => data.entrances[id]!)
        .toList();
    if (targets.isEmpty) {
      throw const CampusRoutingException(
        'This destination has no verified walking entrance yet.',
      );
    }
    if (origin.accuracy != null &&
        (!origin.accuracy!.isFinite ||
            origin.accuracy! > 25 ||
            origin.accuracy! < 0)) {
      throw const CampusRoutingException(
        'Your location is too imprecise. Move into open sky or choose a starting entrance.',
      );
    }
    final starts = <({String node, GeoPoint? point, List<RouteArc> arcs})>[];
    if (origin.nodeId != null) {
      starts.add((node: origin.nodeId!, point: null, arcs: const []));
    } else if (origin.point case final point?) {
      final bounds = data.cameraBounds;
      if (point.longitude < bounds.first.longitude ||
          point.longitude > bounds.last.longitude ||
          point.latitude < bounds.first.latitude ||
          point.latitude > bounds.last.latitude) {
        throw const CampusRoutingException(
          'You are outside the campus map area. Choose a starting entrance.',
        );
      }
      // This tolerance accommodates location noise, not permission to cross a
      // wall. Never draw or route a lateral connector from GPS to the path.
      for (final edge in data.edges.values) {
        if (!policy.permits(edge)) continue;
        final snap = projectOnLine(point, edge.points);
        if (snap.distance > (origin.accuracy == null ? 5 : 8)) continue;
        final arcs = <RouteArc>[
          RouteArc(
            edge,
            '@origin',
            edge.to,
            sliceLine(edge.points, snap.along, edge.distance),
          ),
          if (edge.bidirectional)
            RouteArc(
              edge,
              '@origin',
              edge.from,
              sliceLine(edge.points, 0, snap.along).reversed.toList(),
            ),
        ];
        starts.add((node: '@origin', point: snap.point, arcs: arcs));
      }
      if (starts.isEmpty) {
        throw const CampusRoutingException(
          'No verified walkway is close enough to safely match this location. Choose a starting entrance or press and hold on a verified path.',
        );
      }
      starts.sort(
        (a, b) =>
            a.point!.distanceTo(point).compareTo(b.point!.distanceTo(point)),
      );
      // Avoid selecting a different parallel walkway merely for a shorter route.
      final nearest = starts.first.point!.distanceTo(point);
      starts.removeWhere((s) => s.point!.distanceTo(point) > nearest + 1);
    } else {
      throw const CampusRoutingException('Choose your starting point.');
    }
    CampusRoute? best;
    for (final start in starts) {
      for (final entrance in targets) {
        final route = find(
          data,
          start.node,
          entrance.nodeId,
          policy: policy,
          extraArcs: start.arcs,
          virtualStart: start.point,
        );
        if (route != null && (best == null || route.cost < best.cost)) {
          best = CampusRoute(
            arcs: route.arcs,
            start: route.start,
            end: route.end,
            entranceId: entrance.id,
            cost: route.cost,
          );
        }
      }
    }
    if (best == null) {
      throw const CampusRoutingException(
        'No connected walking route is available with these preferences. Try another entrance or starting point.',
      );
    }
    return best;
  }
}

class _Entry {
  const _Entry(this.node, this.priority, this.cost);
  final String node;
  final double priority, cost;
}

class _MinHeap {
  final _items = <_Entry>[];
  bool get isNotEmpty => _items.isNotEmpty;
  bool _less(_Entry a, _Entry b) =>
      a.priority < b.priority ||
      (a.priority == b.priority && a.node.compareTo(b.node) < 0);
  void add(_Entry entry) {
    _items.add(entry);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (!_less(_items[i], _items[parent])) break;
      final swap = _items[parent];
      _items[parent] = _items[i];
      _items[i] = swap;
      i = parent;
    }
  }

  _Entry remove() {
    final first = _items.first, last = _items.removeLast();
    if (_items.isEmpty) return first;
    _items[0] = last;
    var i = 0;
    while (i * 2 + 1 < _items.length) {
      var child = i * 2 + 1;
      if (child + 1 < _items.length &&
          _less(_items[child + 1], _items[child])) {
        child++;
      }
      if (!_less(_items[child], _items[i])) break;
      final swap = _items[i];
      _items[i] = _items[child];
      _items[child] = swap;
      i = child;
    }
    return first;
  }
}

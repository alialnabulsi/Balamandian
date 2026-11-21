import 'dart:convert';

import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:balamandian/domain/models/campus/campus_data.dart';
import 'package:balamandian/domain/models/campus/campus_route.dart';
import 'package:balamandian/domain/models/campus/geo_point.dart';
import 'package:balamandian/domain/services/campus_routing_service.dart';
import 'package:balamandian/domain/services/destination_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';

void main() {
  const service = CampusRoutingService();
  final data = campusFixture();
  test('Nonnegative weighted penalties change the optimal path', () {
    final route = service.find(data, 'b', 'd', policy: const _StairPenalty())!;
    expect(route.arcs.any((a) => a.edge.type == 'stairs'), isFalse);
    final dijkstra = service.find(
      data,
      'b',
      'd',
      policy: const _StairPenalty(),
      dijkstra: true,
    )!;
    expect(route.cost, closeTo(dijkstra.cost, .001));
    expect(
      () => service.find(data, 'b', 'd', policy: const _InvalidPenalty()),
      throwsArgumentError,
    );
  });
  test(
    'Chooses the best reachable entrance and respects an explicit choice',
    () {
      final docs = campusDocuments();
      final dests = jsonDecode(docs['destinations']!) as Map<String, dynamic>;
      final entrances = jsonDecode(docs['entrances']!) as Map<String, dynamic>;
      dests['features'][1]['properties']['entrance_ids'].add('demo-east-short');
      entrances['features'].add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': data.nodes['b']!.point.toJson(),
        },
        'properties': {
          'id': 'demo-east-short',
          'name': 'Short test entrance',
          'destination_id': 'demo-east',
          'node_id': 'b',
        },
      });
      docs['destinations'] = jsonEncode(dests);
      docs['entrances'] = jsonEncode(entrances);
      final multiple = CampusDatasetService().parse(docs);
      final best = service.plan(
        multiple,
        const RouteOrigin.node('a'),
        multiple.destinations['demo-east']!,
      );
      expect(best.entranceId, 'demo-east-short');
      final chosen = service.plan(
        multiple,
        const RouteOrigin.node('a'),
        multiple.destinations['demo-east']!,
        entranceId: 'demo-east-door',
      );
      expect(chosen.entranceId, 'demo-east-door');
      expect(chosen.distance, greaterThan(best.distance));
    },
  );
  test('A* equals Dijkstra for every ordered pair, including disconnected nodes and policies', () {
    for (final policy in [
      const WalkingPolicy(),
      const WalkingPolicy(avoidStairs: true),
      const WalkingPolicy(requireVerifiedAccess: true),
    ]) {
      for (final from in data.nodes.keys) {
        for (final to in data.nodes.keys) {
          final a = service.find(data, from, to, policy: policy);
          final d = service.find(
            data,
            from,
            to,
            policy: policy,
            dijkstra: true,
          );
          expect(
            a?.distance,
            d == null ? isNull : closeTo(d.distance, .0001),
            reason: '$from → $to',
          );
          expect(a?.arcs.any((arc) => arc.edge.restricted) ?? false, isFalse);
          for (final arc in a?.arcs ?? <RouteArc>[]) {
            if (!arc.edge.bidirectional) expect(arc.from, arc.edge.from);
          }
        }
      }
    }
  });
  test('Reconstructs geometry and calculates actual distance, never direct endpoint distance', () {
    final route = service.find(data, 'a', 'e')!;
    expect(route.arcs.map((a) => a.from).first, 'a');
    expect(route.arcs.last.to, 'e');
    expect(
      route.distance,
      closeTo(route.arcs.fold<double>(0, (s, a) => s + a.edge.distance), .001),
    );
    expect(route.distance, greaterThan(route.start.distanceTo(route.end)));
    expect(route.duration.inSeconds, (route.distance / 1.25).ceil());
  });
  test('Avoids stairs and never upgrades unknown accessibility', () {
    final ordinary = service.find(data, 'b', 'd')!;
    final accessible = service.find(
      data,
      'b',
      'd',
      policy: const WalkingPolicy(avoidStairs: true),
    )!;
    expect(ordinary.arcs.any((a) => a.edge.type == 'stairs'), isTrue);
    expect(accessible.arcs.any((a) => a.edge.type == 'stairs'), isFalse);
    expect(accessible.distance, greaterThan(ordinary.distance));
    expect(accessible.accessibilityVerified, isFalse);
  });
  test(
    'Invalid nodes, disconnected networks and same-node paths are explicit',
    () {
      expect(
        () => service.find(data, 'missing', 'a'),
        throwsA(isA<CampusRoutingException>()),
      );
      expect(service.find(data, 'a', 'isolated'), isNull);
      expect(service.find(data, 'a', 'a')!.distance, 0);
    },
  );
  test(
    'Projects an origin to the nearby eligible edge and follows its direction',
    () {
      final edge = data.edges['ce']!;
      final midpoint = edge.points.first.interpolate(edge.points.last, .5);
      final route = service.plan(
        data,
        RouteOrigin.point(midpoint),
        data.destinations['demo-east']!,
      );
      expect(route.start.latitude, closeTo(midpoint.latitude, .000001));
      expect(route.arcs.first.to, 'e');
      expect(route.distance, lessThan(data.edges['ce']!.distance));
      expect(route.entranceId, 'demo-east-door');
      final reverse = service.plan(
        data,
        RouteOrigin.point(midpoint),
        data.destinations['demo-west']!,
      );
      expect(
        reverse.arcs.first.to,
        'e',
        reason: 'one-way edge cannot be traversed backwards',
      );
    },
  );
  test('Rejects distant origins, poor GPS and outside-campus starts', () {
    for (final origin in [
      const RouteOrigin.point(GeoPoint(35, 34)),
      const RouteOrigin.point(GeoPoint(-.128, 51.535)),
      const RouteOrigin.point(GeoPoint(-.127, 51.533), accuracy: 90),
    ]) {
      expect(
        () => service.plan(data, origin, data.destinations['demo-east']!),
        throwsA(isA<CampusRoutingException>()),
      );
    }
  });
  test('Handles disconnected target and selected entrance without fabricated connectors', () {
    expect(
      () => service.plan(
        data,
        const RouteOrigin.node('a'),
        data.destinations['demo-island']!,
      ),
      throwsA(isA<CampusRoutingException>()),
    );
    expect(
      () => service.plan(
        data,
        const RouteOrigin.node('a'),
        data.destinations['demo-east']!,
        entranceId: 'wrong',
      ),
      throwsA(isA<CampusRoutingException>()),
    );
  });
  test(
    'Local destination search supports code, aliases, category and no results',
    () {
      const search = DestinationSearch();
      final destinations = data.destinations.values;
      expect(search.search(destinations, 'LIB').first.id, 'demo-library');
      expect(search.search(destinations, 'west').single.id, 'demo-west');
      expect(
        search.search(destinations, 'library', category: 'Gates'),
        isEmpty,
      );
      expect(search.search(destinations, 'unknown'), isEmpty);
      expect(
        search.search(destinations, '', category: 'Academic').single.id,
        'demo-east',
      );
    },
  );
}

class _StairPenalty extends WalkingPolicy {
  const _StairPenalty();
  @override
  double penalty(PedestrianEdge edge) => edge.type == 'stairs' ? 1000 : 0;
}

class _InvalidPenalty extends WalkingPolicy {
  const _InvalidPenalty();
  @override
  double penalty(PedestrianEdge edge) => -1;
}

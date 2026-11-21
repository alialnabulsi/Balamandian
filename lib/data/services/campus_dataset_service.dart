import 'dart:convert';

import '../../domain/models/campus/campus_data.dart';
import '../../domain/models/campus/geo_point.dart';

/// Strict shared parser used by the asset repository and the GIS validation CLI.
class CampusDatasetService {
  static const files = [
    'boundary',
    'buildings',
    'replacement_areas',
    'destinations',
    'entrances',
    'pedestrian_nodes',
    'pedestrian_edges',
  ];

  CampusData parse(Map<String, String> documents) {
    final meta = _object(jsonDecode(documents['campus']!), 'campus');
    if (meta['schema_version'] != 1) _fail('Unsupported schema_version.');
    final collections = <String, Json>{};
    for (final name in files) {
      final collection = _object(jsonDecode(documents[name]!), name);
      if (collection['type'] != 'FeatureCollection' ||
          collection['features'] is! List) {
        _fail('$name must be a FeatureCollection.');
      }
      final ids = <String>{};
      for (final raw in collection['features'] as List) {
        final f = _object(raw, name);
        if (f['type'] != 'Feature') _fail('$name: expected Feature.');
        final p = _object(f['properties'], '$name properties');
        final id = _text(p, 'id');
        if (!ids.add(id)) _fail('$name: duplicate id $id.');
        final g = _object(f['geometry'], '$name geometry');
        if (['boundary', 'buildings', 'replacement_areas'].contains(name)) {
          _polygon(g);
          _text(p, 'source');
          _text(p, 'revision');
        } else if (name == 'pedestrian_edges') {
          if (g['type'] != 'LineString' ||
              g['coordinates'] is! List ||
              (g['coordinates'] as List).length < 2) {
            _fail('Invalid edge geometry.');
          }
          final points = (g['coordinates'] as List)
              .map(GeoPoint.parse)
              .toList();
          if (points.first.distanceTo(points.last) < .05 ||
              lineLength(points) < .1) {
            _fail('Degenerate edge $id.');
          }
        } else {
          if (g['type'] != 'Point') _fail('$name requires Point geometry.');
          GeoPoint.parse(g['coordinates']);
        }
      }
      collections[name] = collection;
    }
    final buildingIds = <String>{};
    for (final f in _features(collections['buildings']!)) {
      final p = f['properties'] as Json;
      buildingIds.add(_text(p, 'building_id'));
      for (final field in ['name', 'code', 'category']) {
        _text(p, field);
      }
      final height = _number(p, 'height'), base = _number(p, 'base_height');
      if (base < 0 || height <= base) {
        _fail('Height must exceed nonnegative base_height.');
      }
      if (p['levels'] != null &&
          (p['levels'] is! int || (p['levels'] as int) < 1)) {
        _fail('Invalid levels.');
      }
    }
    final destinations = <String, CampusDestination>{};
    for (final f in _features(collections['destinations']!)) {
      final p = f['properties'] as Json;
      _text(p, 'source');
      _text(p, 'revision');
      final d = CampusDestination(
        id: _text(p, 'id'),
        name: _text(p, 'name'),
        code: _text(p, 'code'),
        category: _text(p, 'category'),
        point: GeoPoint.parse(f['geometry']['coordinates']),
        aliases: _strings(p['aliases']),
        entranceIds: _strings(p['entrance_ids']),
        buildingId: _optionalText(p, 'building_id'),
        image: _optionalText(p, 'image'),
        description: _optionalText(p, 'description'),
      );
      // A destination may reference a stable building ID without a custom footprint.
      destinations[d.id] = d;
    }
    final nodes = <String, PedestrianNode>{};
    for (final f in _features(collections['pedestrian_nodes']!)) {
      final p = f['properties'] as Json;
      final node = PedestrianNode(
        // Source/revision are required even when no custom building exists.
        id: _text(p, 'id'),
        type: _text(p, 'type'),
        point: GeoPoint.parse(f['geometry']['coordinates']),
        destinationId: _optionalText(p, 'destination_id'),
        buildingId: _optionalText(p, 'building_id'),
      );
      _text(p, 'source');
      _text(p, 'revision');
      if (node.destinationId != null &&
          !destinations.containsKey(node.destinationId)) {
        _fail('Unknown node destination.');
      }
      nodes[node.id] = node;
    }
    final edges = <String, PedestrianEdge>{};
    for (final f in _features(collections['pedestrian_edges']!)) {
      final p = f['properties'] as Json;
      if (p['bidirectional'] is! bool) _fail('bidirectional must be boolean.');
      if (p['restricted'] != null && p['restricted'] is! bool) {
        _fail('restricted must be boolean.');
      }
      final accessibility = switch (p['accessibility']) {
        'verified' => PathAccessibility.verified,
        'inaccessible' => PathAccessibility.inaccessible,
        'unknown' => PathAccessibility.unknown,
        _ => throw const FormatException('Invalid accessibility status.'),
      };
      final e = PedestrianEdge(
        id: _text(p, 'id'),
        from: _text(p, 'from'),
        to: _text(p, 'to'),
        points: (f['geometry']['coordinates'] as List)
            .map(GeoPoint.parse)
            .toList(),
        type: _text(p, 'type'),
        bidirectional: p['bidirectional'] as bool,
        accessibility: accessibility,
        restricted: p['restricted'] == true,
        slope: p['slope'] == null ? null : _number(p, 'slope'),
      );
      if (!nodes.containsKey(e.from) || !nodes.containsKey(e.to)) {
        _fail('Missing endpoint on ${e.id}.');
      }
      // Connectivity is explicit; crossing lines never create graph junctions.
      if (e.points.first.distanceTo(nodes[e.from]!.point) > .05 ||
          e.points.last.distanceTo(nodes[e.to]!.point) > .05) {
        _fail('Edge ${e.id} endpoints do not match node geometry.');
      }
      final stored = _number(p, 'distance_m');
      if (stored <= 0 ||
          (stored - e.distance).abs() > (e.distance * .03 + .5)) {
        _fail('Edge ${e.id} distance_m disagrees with WGS84 geometry.');
      }
      edges[e.id] = e;
    }
    final entrances = <String, CampusEntrance>{};
    for (final f in _features(collections['entrances']!)) {
      final p = f['properties'] as Json;
      final e = CampusEntrance(
        id: _text(p, 'id'),
        name: _text(p, 'name'),
        destinationId: _text(p, 'destination_id'),
        nodeId: _text(p, 'node_id'),
        point: GeoPoint.parse(f['geometry']['coordinates']),
        buildingId: _optionalText(p, 'building_id'),
      );
      if (!destinations.containsKey(e.destinationId) ||
          !nodes.containsKey(e.nodeId)) {
        _fail('Invalid entrance reference.');
      }
      if (e.point.distanceTo(nodes[e.nodeId]!.point) > .05) {
        _fail('Entrance must coincide with its graph node.');
      }
      entrances[e.id] = e;
    }
    for (final d in destinations.values) {
      for (final id in d.entranceIds) {
        if (entrances[id]?.destinationId != d.id) {
          _fail('Invalid destination entrance $id.');
        }
      }
    }
    for (final e in entrances.values) {
      if (!destinations[e.destinationId]!.entranceIds.contains(e.id)) {
        _fail('Entrance missing from destination.');
      }
    }
    for (final f in _features(collections['replacement_areas']!)) {
      final p = f['properties'] as Json;
      if (!buildingIds.contains(_text(p, 'building_id'))) {
        _fail('Replacement has no valid custom building.');
      }
      if (p['approved'] is! bool) {
        _fail('Replacement requires explicit approved flag.');
      }
    }
    final bounds = (meta['camera_bounds'] as List).map(GeoPoint.parse).toList();
    if (bounds.length != 2 ||
        bounds[0].longitude >= bounds[1].longitude ||
        bounds[0].latitude >= bounds[1].latitude) {
      _fail('Invalid camera bounds.');
    }
    final center = GeoPoint.parse(meta['center']);
    if (center.longitude < bounds[0].longitude ||
        center.longitude > bounds[1].longitude ||
        center.latitude < bounds[0].latitude ||
        center.latitude > bounds[1].latitude) {
      _fail('Center outside camera bounds.');
    }
    if (meta['fixture'] is! bool || meta['provisional_bounds'] is! bool) {
      _fail('Missing dataset status.');
    }
    return CampusData(
      id: _text(meta, 'id'),
      revision: _text(meta, 'revision'),
      name: _text(meta, 'name'),
      center: center,
      cameraBounds: List.unmodifiable(bounds),
      provisionalBounds: meta['provisional_bounds'] as bool,
      fixture: meta['fixture'] as bool,
      destinations: Map.unmodifiable(destinations),
      entrances: Map.unmodifiable(entrances),
      nodes: Map.unmodifiable(nodes),
      edges: Map.unmodifiable(edges),
      buildings: collections['buildings']!,
      replacementAreas: collections['replacement_areas']!,
      boundary: collections['boundary']!,
    );
  }

  Iterable<Json> _features(Json collection) =>
      (collection['features'] as List).cast<Json>();
  Json _object(Object? value, String label) {
    if (value is! Json) _fail('Expected object: $label.');
    return value;
  }

  String _text(Json p, String key) {
    final value = p[key];
    if (value is! String || value.trim().isEmpty) {
      _fail('Missing/invalid $key.');
    }
    if (key == 'id' &&
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]*$').hasMatch(value)) {
      _fail('Invalid stable identifier.');
    }
    return value;
  }

  String? _optionalText(Json p, String key) =>
      p[key] == null ? null : _text(p, key);
  List<String> _strings(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.any((v) => v is! String || v.trim().isEmpty)) {
      _fail('Expected string array.');
    }
    if (raw.toSet().length != raw.length) _fail('Duplicate array reference.');
    return List.unmodifiable(raw.cast<String>());
  }

  double _number(Json p, String key) {
    final value = p[key];
    if (value is! num || !value.isFinite) _fail('Invalid number $key.');
    return value.toDouble();
  }

  void _polygon(Json geometry) {
    final raw = geometry['coordinates'];
    if (raw is! List || raw.isEmpty) _fail('Empty polygon.');
    final polygons = switch (geometry['type']) {
      'Polygon' => [raw],
      'MultiPolygon' => raw,
      _ => throw const FormatException('Expected Polygon or MultiPolygon.'),
    };
    for (final polygon in polygons) {
      if (polygon is! List || polygon.isEmpty) _fail('Empty polygon rings.');
      for (final ring in polygon) {
        if (ring is! List || ring.length < 4) _fail('Invalid polygon ring.');
        final points = ring.map(GeoPoint.parse).toList();
        if (points.first.distanceTo(points.last) > .001) {
          _fail('Polygon ring must close.');
        }
        for (var i = 0; i < points.length - 1; i++) {
          if (points[i].distanceTo(points[i + 1]) < .001) {
            _fail('Duplicate polygon vertex.');
          }
          for (var j = i + 2; j < points.length - 1; j++) {
            if (i == 0 && j == points.length - 2) continue;
            if (_crosses(points[i], points[i + 1], points[j], points[j + 1])) {
              _fail('Self-intersecting polygon ring.');
            }
          }
        }
        var area = 0.0;
        for (var i = 1; i < points.length; i++) {
          area +=
              (points[i - 1].longitude - points.first.longitude) *
                  (points[i].latitude - points.first.latitude) -
              (points[i].longitude - points.first.longitude) *
                  (points[i - 1].latitude - points.first.latitude);
        }
        if (area.abs() < 1e-14) _fail('Degenerate polygon.');
      }
    }
  }

  Never _fail(String message) => throw FormatException(message);

  bool _crosses(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
    double turn(GeoPoint p, GeoPoint q, GeoPoint r) =>
        (q.longitude - p.longitude) * (r.latitude - p.latitude) -
        (q.latitude - p.latitude) * (r.longitude - p.longitude);
    bool on(GeoPoint p, GeoPoint q, GeoPoint r) =>
        r.longitude >=
            (p.longitude < q.longitude ? p.longitude : q.longitude) &&
        r.longitude <=
            (p.longitude > q.longitude ? p.longitude : q.longitude) &&
        r.latitude >= (p.latitude < q.latitude ? p.latitude : q.latitude) &&
        r.latitude <= (p.latitude > q.latitude ? p.latitude : q.latitude);
    final x = turn(a, b, c),
        y = turn(a, b, d),
        z = turn(c, d, a),
        w = turn(c, d, b);
    return (x * y < 0 && z * w < 0) ||
        (x.abs() < 1e-18 && on(a, b, c)) ||
        (y.abs() < 1e-18 && on(a, b, d)) ||
        (z.abs() < 1e-18 && on(c, d, a)) ||
        (w.abs() < 1e-18 && on(c, d, b));
  }
}

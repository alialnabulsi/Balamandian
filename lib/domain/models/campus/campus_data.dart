import 'geo_point.dart';

typedef Json = Map<String, dynamic>;

class CampusDestination {
  const CampusDestination({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.point,
    this.aliases = const [],
    this.entranceIds = const [],
    this.buildingId,
    this.image,
    this.description,
  });
  final String id, name, code, category;
  final GeoPoint point;
  final List<String> aliases, entranceIds;
  final String? buildingId, image, description;
}

class CampusEntrance {
  const CampusEntrance({
    required this.id,
    required this.name,
    required this.destinationId,
    required this.nodeId,
    required this.point,
    this.buildingId,
  });
  final String id, name, destinationId, nodeId;
  final String? buildingId;
  final GeoPoint point;
}

class PedestrianNode {
  const PedestrianNode({
    required this.id,
    required this.point,
    required this.type,
    this.destinationId,
    this.buildingId,
  });
  final String id, type;
  final GeoPoint point;
  final String? destinationId, buildingId;
}

enum PathAccessibility { verified, inaccessible, unknown }

class PedestrianEdge {
  PedestrianEdge({
    required this.id,
    required this.from,
    required this.to,
    required List<GeoPoint> points,
    required this.type,
    required this.bidirectional,
    required this.accessibility,
    this.restricted = false,
    this.slope,
  }) : points = List.unmodifiable(points),
       distance = lineLength(points);
  final String id, from, to, type;
  final List<GeoPoint> points;
  final double distance;
  final bool bidirectional, restricted;
  final PathAccessibility accessibility;
  final double? slope;
}

class CampusData {
  CampusData({
    required this.id,
    required this.revision,
    required this.name,
    required this.center,
    required this.cameraBounds,
    required this.provisionalBounds,
    required this.fixture,
    required this.destinations,
    required this.entrances,
    required this.nodes,
    required this.edges,
    required this.buildings,
    required this.replacementAreas,
    required this.boundary,
  });
  final String id, revision, name;
  final GeoPoint center;
  final List<GeoPoint> cameraBounds;
  final bool provisionalBounds, fixture;
  final Map<String, CampusDestination> destinations;
  final Map<String, CampusEntrance> entrances;
  final Map<String, PedestrianNode> nodes;
  final Map<String, PedestrianEdge> edges;
  final Json buildings, replacementAreas, boundary;
  bool get routingAvailable => edges.isNotEmpty && entrances.isNotEmpty;
}

Json featureCollection(Iterable<Json> features) => {
  'type': 'FeatureCollection',
  'features': features.toList(),
};
Json pointFeature(GeoPoint point, Json properties) => {
  'type': 'Feature',
  'properties': properties,
  'geometry': {'type': 'Point', 'coordinates': point.toJson()},
};
Json lineFeature(List<GeoPoint> points, [Json properties = const {}]) => {
  'type': 'Feature',
  'properties': properties,
  'geometry': {
    'type': 'LineString',
    'coordinates': points.map((p) => p.toJson()).toList(),
  },
};

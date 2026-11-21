import 'dart:convert';

import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:balamandian/domain/models/campus/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';

void main() {
  test('Production contains a sourced campus reference and no invented paths or footprints', () {
    final data = CampusDatasetService().parse(campusDocuments(fixture: false));
    expect(data.fixture, isFalse);
    expect(data.destinations.values.single.code, 'UOB');
    expect(data.nodes, isEmpty);
    expect(data.edges, isEmpty);
    expect(data.buildings['features'], isEmpty);
    expect(data.boundary['features'], isEmpty);
    expect(data.routingAvailable, isFalse);
    expect(data.provisionalBounds, isTrue);
  });
  test('Fixture is separate, parses all geometry contracts and multiple building sections', () {
    final documents = campusDocuments();
    final buildings =
        jsonDecode(documents['buildings']!) as Map<String, dynamic>;
    final copy = jsonDecode(
      jsonEncode(buildings['features'][0]),
    ) as Map<String, dynamic>;
    copy['properties']['id'] = 'demo-building-roof';
    copy['properties']['base_height'] = 16;
    copy['properties']['height'] = 20;
    copy['geometry']['type'] = 'MultiPolygon';
    copy['geometry']['coordinates'] = [copy['geometry']['coordinates']];
    buildings['features'].add(copy);
    documents['buildings'] = jsonEncode(buildings);
    final data = CampusDatasetService().parse(documents);
    expect(data.fixture, isTrue);
    expect(data.buildings['features'], hasLength(2));
  });
  for (final value in [
    [181, 1],
    [1, 91],
    [double.nan, 1],
    [1],
    [1, 2, 3],
    ['1', 2],
  ]) {
    test(
      'Reject invalid coordinate $value',
      () => expect(() => GeoPoint.parse(value), throwsFormatException),
    );
  }
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'duplicate identifiers': (d) => d['features'].add(d['features'][0]),
    'missing endpoints': (d) =>
        d['features'][0]['properties']['from'] = 'missing',
    'mismatched geometry': (d) =>
        d['features'][0]['geometry']['coordinates'][0] = [0, 0],
    'empty geometry': (d) => d['features'][0]['geometry']['coordinates'] = [],
    'wrong geometry': (d) => d['features'][0]['geometry']['type'] = 'Polygon',
    'negative lengths': (d) =>
        d['features'][0]['properties']['distance_m'] = -1,
    'incorrect lengths': (d) =>
        d['features'][0]['properties']['distance_m'] = 5000,
    'invalid accessibility': (d) =>
        d['features'][0]['properties']['accessibility'] = 'probably',
    'invalid direction': (d) =>
        d['features'][0]['properties']['bidirectional'] = 'true',
  };
  for (final entry in mutations.entries) {
    test('Reject ${entry.key}', () {
      final docs = campusDocuments();
      final edges =
          jsonDecode(docs['pedestrian_edges']!) as Map<String, dynamic>;
      entry.value(edges);
      docs['pedestrian_edges'] = jsonEncode(edges);
      expect(() => CampusDatasetService().parse(docs), throwsFormatException);
    });
  }
  for (final kind in [
    'open ring',
    'invalid height',
    'orphan clip',
    'orphan entrance',
  ]) {
    test('Reject $kind', () {
      final docs = campusDocuments();
      final name = kind == 'orphan clip'
          ? 'replacement_areas'
          : kind == 'orphan entrance'
          ? 'entrances'
          : 'buildings';
      final collection = jsonDecode(docs[name]!) as Map<String, dynamic>;
      final f = collection['features'][0];
      switch (kind) {
        case 'open ring':
          f['geometry']['coordinates'][0].removeLast();
        case 'invalid height':
          f['properties']['height'] = -1;
        case 'orphan clip':
          f['properties']['building_id'] = 'no-building';
        case 'orphan entrance':
          f['properties']['node_id'] = 'no-node';
      }
      docs[name] = jsonEncode(collection);
      expect(() => CampusDatasetService().parse(docs), throwsFormatException);
    });
  }
}

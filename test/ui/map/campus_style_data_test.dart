import 'dart:convert';

import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:balamandian/ui/map/mapbox/campus_style_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';

void main() {
  test('No clip or custom extrusion activates before explicit approval', () {
    final documents = campusDocuments();
    final replacements =
        jsonDecode(documents['replacement_areas']!) as Map<String, dynamic>;
    replacements['features'][0]['properties']['approved'] = false;
    documents['replacement_areas'] = jsonEncode(replacements);
    final data = CampusDatasetService().parse(documents);
    expect(CampusStyleData.clips(data)['features'], isEmpty);
    expect(CampusStyleData.approvedBuildings(data)['features'], isEmpty);
    expect(CampusStyleData.destinations(data)['features'], hasLength(4));
  });
  test('Approved custom geometry and replacement masks remain separate', () {
    final data = campusFixture();
    final geometry = CampusStyleData.approvedBuildings(
      data,
    )['features'][0]['geometry'];
    final clip = CampusStyleData.clips(data)['features'][0]['geometry'];
    expect(geometry, isNot(equals(clip)));
    final extrusion = CampusStyleData.overlayLayers.firstWhere(
      (layer) => layer['id'] == 'campus-buildings',
    );
    expect(extrusion['paint']['fill-extrusion-height'], ['get', 'height']);
    expect(extrusion['paint']['fill-extrusion-base'], ['get', 'base_height']);
  });
}

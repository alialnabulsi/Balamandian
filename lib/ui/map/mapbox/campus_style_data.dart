import 'dart:math' as math;

import '../../../domain/models/campus/campus_data.dart';
import '../../../domain/models/campus/campus_route.dart';
import '../../../domain/models/campus/navigation_fix.dart';
import '../widgets/campus_map_tokens.dart';

/// Source construction is kept inspectable without a native renderer.
abstract final class CampusStyleData {
  static Json approvedBuildings(CampusData data) {
    final ids = (data.replacementAreas['features'] as List)
        .where((f) => f['properties']['approved'] == true)
        .map((f) => f['properties']['building_id'])
        .toSet();
    return featureCollection(
      (data.buildings['features'] as List).cast<Json>().where(
        (f) => ids.contains(f['properties']['building_id']),
      ),
    );
  }

  static Json clips(CampusData data) {
    final buildings = (approvedBuildings(data)['features'] as List)
        .map((f) => f['properties']['building_id'])
        .toSet();
    return featureCollection(
      (data.replacementAreas['features'] as List).cast<Json>().where(
        (f) =>
            f['properties']['approved'] == true &&
            buildings.contains(f['properties']['building_id']),
      ),
    );
  }

  static Json destinations(CampusData data) => featureCollection(
    data.destinations.values.map(
      (d) =>
          pointFeature(d.point, {'id': d.id, 'name': d.name, 'code': d.code}),
    ),
  );
  static Json route(CampusRoute? route) => featureCollection(
    route == null || route.points.length < 2 ? [] : [lineFeature(route.points)],
  );
  static Json endpoints(CampusRoute? route) => featureCollection(
    route == null
        ? []
        : [
            pointFeature(route.start, {'kind': 'start'}),
            pointFeature(route.end, {'kind': 'destination'}),
          ],
  );
  static Json position(NavigationFix? fix, {required bool simulated}) =>
      featureCollection(
        fix == null
            ? []
            : [
                pointFeature(fix.point, {
                  'accuracy': fix.accuracy,
                  'heading': fix.heading ?? 0,
                  'simulated': simulated,
                  'latitude': fix.point.latitude,
                  'metres_per_pixel_z0':
                      78271.516964 *
                      math.cos(fix.point.latitude * math.pi / 180),
                }),
              ],
      );
  static List<Json> get overlayLayers => [
    {
      'id': 'campus-boundary-line',
      'type': 'line',
      'source': 'campus-boundary',
      'slot': 'middle',
      'paint': {
        'line-color': CampusMapTokens.start,
        'line-width': 2,
        'line-dasharray': [3, 2],
        'line-opacity': .7,
      },
    },
    {
      'id': 'campus-buildings',
      'type': 'fill-extrusion',
      'source': 'campus-buildings',
      'slot': 'middle',
      'paint': {
        'fill-extrusion-height': ['get', 'height'],
        'fill-extrusion-base': ['get', 'base_height'],
        'fill-extrusion-base-alignment': 'terrain',
        'fill-extrusion-height-alignment': 'terrain',
        'fill-extrusion-color': CampusMapTokens.building,
        'fill-extrusion-opacity': 1,
      },
    },
    {
      'id': 'campus-selected',
      'type': 'fill-extrusion',
      'source': 'campus-buildings',
      'slot': 'middle',
      'filter': [
        '==',
        ['get', 'building_id'],
        '',
      ],
      'paint': {
        'fill-extrusion-height': [
          '+',
          ['get', 'height'],
          .15,
        ],
        'fill-extrusion-base': ['get', 'base_height'],
        'fill-extrusion-base-alignment': 'terrain',
        'fill-extrusion-height-alignment': 'terrain',
        'fill-extrusion-color': CampusMapTokens.selection,
        'fill-extrusion-opacity': 1,
      },
    },
    {
      'id': 'campus-route-casing',
      'type': 'line',
      'source': 'campus-route',
      'slot': 'top',
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': CampusMapTokens.casing,
        'line-width': 9,
        'line-emissive-strength': 1,
      },
    },
    {
      'id': 'campus-route-line',
      'type': 'line',
      'source': 'campus-route',
      'slot': 'top',
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': CampusMapTokens.route,
        'line-width': 5,
        'line-emissive-strength': 1,
      },
    },
    {
      'id': 'campus-destination-dots',
      'type': 'symbol',
      'source': 'campus-destinations',
      'slot': 'top',
      'layout': {
        'icon-image': 'campus-pin',
        'icon-anchor': 'bottom',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'icon-pitch-alignment': 'viewport',
        'icon-rotation-alignment': 'viewport',
      },
      'paint': {'icon-emissive-strength': 1},
    },
    {
      'id': 'campus-destination-labels',
      'type': 'symbol',
      'source': 'campus-destinations',
      'slot': 'top',
      'layout': {
        'text-field': ['get', 'name'],
        'text-size': 12,
        'text-anchor': 'top',
        'text-offset': [0, 1.2],
        'text-max-width': 12,
      },
      'paint': {
        'text-color': CampusMapTokens.destination,
        'text-halo-color': CampusMapTokens.casing,
        'text-halo-width': 2,
      },
    },
    {
      'id': 'campus-route-endpoints',
      'type': 'circle',
      'source': 'campus-endpoints',
      'paint': {
        'circle-radius': 8,
        'circle-color': [
          'match',
          ['get', 'kind'],
          'start',
          CampusMapTokens.start,
          CampusMapTokens.selection,
        ],
        'circle-stroke-color': CampusMapTokens.casing,
        'circle-stroke-width': 3,
        'circle-emissive-strength': 1,
      },
    },
    {
      'id': 'campus-accuracy',
      'type': 'circle',
      'source': 'campus-position',
      'paint': {
        'circle-radius': [
          'interpolate',
          ['exponential', 2],
          ['zoom'],
          0,
          [
            '/',
            ['get', 'accuracy'],
            ['get', 'metres_per_pixel_z0'],
          ],
          24,
          [
            '*',
            [
              '/',
              ['get', 'accuracy'],
              ['get', 'metres_per_pixel_z0'],
            ],
            16777216,
          ],
        ],
        'circle-color': CampusMapTokens.route,
        'circle-opacity': .12,
        'circle-stroke-color': CampusMapTokens.route,
        'circle-stroke-width': 1,
      },
    },
    {
      'id': 'campus-position-dot',
      'type': 'circle',
      'source': 'campus-position',
      'paint': {
        'circle-radius': 7,
        'circle-color': [
          'case',
          ['get', 'simulated'],
          CampusMapTokens.simulation,
          CampusMapTokens.route,
        ],
        'circle-stroke-color': CampusMapTokens.casing,
        'circle-stroke-width': 3,
        'circle-emissive-strength': 1,
      },
    },
  ];
}

import 'dart:convert';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../../domain/models/campus/campus_data.dart';
import '../../../domain/models/campus/campus_route.dart';
import '../../../domain/models/campus/geo_point.dart';
import '../../../domain/models/campus/navigation_fix.dart';
import 'campus_map_adapter.dart';
import 'campus_style_data.dart';
import 'campus_marker_images.dart';

class MapboxCampusAdapter implements CampusMapAdapter {
  MapboxCampusAdapter(this.map, {required this.reducedMotion});
  final mb.MapboxMap map;
  bool Function() reducedMotion;
  CampusData? _data;
  bool _threeDimensional = true;
  bool _installed = false;
  int _cameraGeneration = 0;
  double? _legalBottom;
  double topPadding = 140, bottomPadding = 180, rightPadding = 80;
  @override
  Future<void> viewport({
    required double top,
    required double right,
    required double bottom,
    required double legalBottom,
  }) async {
    topPadding = top;
    rightPadding = right;
    bottomPadding = bottom;
    _legalBottom = legalBottom;
    await ornaments();
  }

  mb.Point point(GeoPoint p) =>
      mb.Point(coordinates: mb.Position(p.longitude, p.latitude));
  mb.MbxEdgeInsets get padding => mb.MbxEdgeInsets(
    top: topPadding,
    left: 32,
    right: rightPadding,
    bottom: bottomPadding,
  );

  @override
  Future<void> install(
    CampusData data, {
    required bool debugGraph,
    required bool dark,
  }) async {
    _installed = false;
    _data = data;
    await map.setBounds(
      mb.CameraBoundsOptions(
        bounds: mb.CoordinateBounds(
          southwest: point(data.cameraBounds.first),
          northeast: point(data.cameraBounds.last),
          infiniteBounds: false,
        ),
        minZoom: 14,
        maxZoom: 21,
        minPitch: 0,
        maxPitch: 65,
      ),
    );
    await light(dark);
    await map.compass.updateSettings(mb.CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
    // Keep required logo and attribution visible in an unobstructed map strip.
    await ornaments();
    final sources = <String, Json>{
      'campus-buildings': CampusStyleData.approvedBuildings(data),
      'campus-replacements': CampusStyleData.clips(data),
      'campus-destinations': CampusStyleData.destinations(data),
      'campus-boundary': data.boundary,
      'campus-route': featureCollection([]),
      'campus-endpoints': featureCollection([]),
      'campus-position': featureCollection([]),
    };
    for (final entry in sources.entries) {
      if (await map.styleSourceExists(entry.key)) {
        await map.setStyleSourceProperty(
          entry.key,
          'data',
          jsonEncode(entry.value),
        );
      } else {
        await map.addSource(
          mb.GeoJsonSource(id: entry.key, data: jsonEncode(entry.value)),
        );
      }
    }
    // Clip 3D basemap content only. `building` and `fill-extrusion` are NOT
    // valid clip-layer-types. Models are opt-in; symbols are intentionally kept.
    if (!await map.styleLayerExists('campus-clip')) {
      await map.addLayer(
        mb.ClipLayer(
          id: 'campus-clip',
          sourceId: 'campus-replacements',
          clipLayerScope: ['basemap'],
          clipLayerTypes: ['model'],
        ),
      );
    }
    await CampusMarkerImages.install(map);
    for (final layer in CampusStyleData.overlayLayers) {
      if (!await map.styleLayerExists(layer['id'] as String)) {
        await map.addStyleLayer(jsonEncode(layer), null);
      }
    }
    if (debugGraph) await _debug(data);
    _installed = true;
  }

  Future<void> ornaments() async {
    await map.logo.updateSettings(
      mb.LogoSettings(
        enabled: true,
        position: mb.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 12,
        marginBottom: _legalBottom ?? bottomPadding - 24,
      ),
    );
    await map.attribution.updateSettings(
      mb.AttributionSettings(
        enabled: true,
        clickable: true,
        position: mb.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 104,
        marginBottom: _legalBottom ?? bottomPadding - 24,
      ),
    );
  }

  Future<void> _debug(CampusData data) async {
    for (final entry in <String, Json>{
      'campus-debug-edges': featureCollection(
        data.edges.values.map((e) => lineFeature(e.points, {'id': e.id})),
      ),
      'campus-debug-nodes': featureCollection(
        data.nodes.values.map((n) => pointFeature(n.point, {'id': n.id})),
      ),
      'campus-debug-entrances': featureCollection(
        data.entrances.values.map((e) => pointFeature(e.point, {'id': e.id})),
      ),
    }.entries) {
      if (!await map.styleSourceExists(entry.key)) {
        await map.addSource(
          mb.GeoJsonSource(id: entry.key, data: jsonEncode(entry.value)),
        );
      }
    }
    for (final layer in <Json>[
      {
        'id': 'campus-debug-edges',
        'type': 'line',
        'source': 'campus-debug-edges',
        'paint': {'line-color': '#D14FAD', 'line-width': 2},
      },
      {
        'id': 'campus-debug-nodes',
        'type': 'circle',
        'source': 'campus-debug-nodes',
        'paint': {'circle-color': '#D14FAD', 'circle-radius': 4},
      },
      {
        'id': 'campus-debug-entrances',
        'type': 'circle',
        'source': 'campus-debug-entrances',
        'paint': {'circle-color': '#2D9D4C', 'circle-radius': 7},
      },
      for (final type in ['nodes', 'edges', 'entrances'])
        {
          'id': 'campus-debug-$type-labels',
          'type': 'symbol',
          'source': 'campus-debug-$type',
          'layout': {
            'text-field': ['get', 'id'],
            'text-size': 10,
            'text-offset': [0, 1.5],
            'text-allow-overlap': true,
          },
          'paint': {
            'text-color': '#79276A',
            'text-halo-color': '#FFFFFF',
            'text-halo-width': 1,
          },
        },
    ]) {
      if (!await map.styleLayerExists(layer['id'] as String)) {
        await map.addStyleLayer(jsonEncode(layer), null);
      }
    }
  }

  @override
  Future<void> light(bool dark) => map.setStyleImportConfigProperty(
    'basemap',
    'lightPreset',
    dark ? 'night' : 'day',
  );
  @override
  Future<void> route(CampusRoute? route) async {
    if (!_installed) return;
    await map.setStyleSourceProperty(
      'campus-route',
      'data',
      jsonEncode(CampusStyleData.route(route)),
    );
    await map.setStyleSourceProperty(
      'campus-endpoints',
      'data',
      jsonEncode(CampusStyleData.endpoints(route)),
    );
  }

  @override
  Future<void> highlight(String? buildingId) async {
    if (_installed) {
      await map.setStyleLayerProperty('campus-selected', 'filter', [
        '==',
        ['get', 'building_id'],
        buildingId ?? '',
      ]);
    }
  }

  @override
  Future<void> selectDestination(String? destinationId) async {
    if (!_installed) return;
    await map.setStyleLayerProperty('campus-destination-dots', 'icon-image', [
      'case',
      [
        '==',
        ['get', 'id'],
        destinationId ?? '',
      ],
      'campus-pin-selected',
      'campus-pin',
    ]);
    await map.setStyleLayerProperty('campus-destination-dots', 'icon-size', [
      'case',
      [
        '==',
        ['get', 'id'],
        destinationId ?? '',
      ],
      1.15,
      1,
    ]);
  }

  @override
  Future<void> reload() => map.loadStyleURI(mb.MapboxStyles.STANDARD);

  @override
  Future<void> position(NavigationFix? fix, {required bool simulated}) async {
    if (_installed) {
      await map.setStyleSourceProperty(
        'campus-position',
        'data',
        jsonEncode(CampusStyleData.position(fix, simulated: simulated)),
      );
    }
  }

  Future<void> _camera(
    mb.CameraOptions camera, {
    int milliseconds = 650,
  }) async {
    final generation = ++_cameraGeneration;
    await map.cancelCameraAnimation();
    if (generation != _cameraGeneration) return;
    if (reducedMotion()) {
      await map.setCamera(camera);
    } else {
      await map.easeTo(camera, mb.MapAnimationOptions(duration: milliseconds));
    }
  }

  @override
  Future<void> focus(
    GeoPoint coordinate, {
    double? heading,
    bool navigation = false,
  }) => _camera(
    mb.CameraOptions(
      center: point(coordinate),
      zoom: navigation ? 18.5 : null,
      pitch: navigation ? (_threeDimensional ? 50 : 0) : null,
      bearing: navigation ? heading : null,
      padding: padding,
    ),
    milliseconds: navigation ? 450 : 650,
  );
  @override
  Future<void> fit(CampusRoute route) async {
    if (route.points.length < 2) {
      await focus(route.end);
      return;
    }
    final camera = await map.cameraForCoordinatesPadding(
      route.points.map(point).toList(),
      mb.CameraOptions(
        bearing: (await map.getCameraState()).bearing,
        pitch: (await map.getCameraState()).pitch,
        padding: padding,
      ),
      null,
      19,
      null,
    );
    await _camera(camera);
  }

  @override
  Future<void> overview() => _camera(
    mb.CameraOptions(
      center: point(_data!.center),
      zoom: 15.6,
      pitch: _threeDimensional ? 45 : 0,
      bearing: 0,
      padding: padding,
    ),
  );
  @override
  Future<void> north() => _camera(mb.CameraOptions(bearing: 0));
  @override
  Future<void> perspective(bool threeDimensional) async {
    _threeDimensional = threeDimensional;
    await _camera(mb.CameraOptions(pitch: threeDimensional ? 45 : 0));
  }
}

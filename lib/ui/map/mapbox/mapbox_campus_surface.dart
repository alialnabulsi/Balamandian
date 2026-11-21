import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../../domain/models/campus/geo_point.dart';
import '../view_models/campus_map_view_model.dart';
import 'mapbox_campus_adapter.dart';

class MapboxCampusSurface extends StatefulWidget {
  const MapboxCampusSurface({
    super.key,
    required this.model,
    required this.topPadding,
    required this.bottomPadding,
    this.onReady,
  });
  final CampusMapViewModel model;
  final double topPadding, bottomPadding;
  final ValueChanged<MapboxCampusAdapter>? onReady;
  @override
  State<MapboxCampusSurface> createState() => _MapboxCampusSurfaceState();
}

class _MapboxCampusSurfaceState extends State<MapboxCampusSurface> {
  MapboxCampusAdapter? _adapter;
  StreamSubscription<mb.MapContentGestureContext>? _pan;
  int _retry = 0;
  bool _reduced = false;
  bool _selectionInstalled = false;
  int _retryRevision = 0;
  late final _initialViewport = mb.CameraViewportState(
    center: mb.Point(
      coordinates: mb.Position(
        widget.model.data!.center.longitude,
        widget.model.data!.center.latitude,
      ),
    ),
    zoom: 15.6,
    pitch: 45,
  );
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    unawaited(widget.model.theme(_dark));
  }

  @override
  void didUpdateWidget(covariant MapboxCampusSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_retryRevision != widget.model.mapRetryRevision) {
      _retryRevision = widget.model.mapRetryRevision;
      if (_adapter == null) {
        _retry++;
      } else if (!widget.model.mapAttached) {
        unawaited(_safe(_adapter!.reload));
      }
    }
    _padding();
  }

  void _padding() {
    final adapter = _adapter;
    if (adapter == null) return;
    final changed =
        adapter.topPadding != widget.topPadding ||
        adapter.bottomPadding != widget.bottomPadding;
    adapter.topPadding = widget.topPadding;
    adapter.bottomPadding = widget.bottomPadding;
    if (changed) unawaited(_safe(adapter.ornaments));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted) widget.model.mapFailed();
    }
  }

  void _created(mb.MapboxMap map) {
    final adapter = MapboxCampusAdapter(map, reducedMotion: () => _reduced);
    _adapter = adapter;
    _selectionInstalled = false;
    _padding();
    _pan = map.gestures.pan.gestureEvents.listen(
      (_) => widget.model.stopFollowing(),
    );
    map.addInteraction(
      mb.LongTapInteraction.onMap((context) {
        final p = context.point.coordinates;
        widget.model.startAtMapPoint(
          GeoPoint(p.lng.toDouble(), p.lat.toDouble()),
        );
      }),
      interactionID: 'campus-manual-start',
    );
  }

  Future<void> _styleLoaded() async {
    if (_adapter case final adapter?) {
      await widget.model.attach(adapter, dark: _dark);
      if (mounted && widget.model.mapError == null) {
        _selectionInteractions(adapter.map);
        widget.onReady?.call(adapter);
      }
    }
  }

  void _selectionInteractions(mb.MapboxMap map) {
    // Custom layers must exist before their interactions are registered.
    for (final id in [
      'campus-destination-dots',
      'campus-destination-labels',
      'campus-buildings',
      'campus-selected',
    ]) {
      if (_selectionInstalled) map.removeInteraction('$id-tap');
      map.addInteraction(
        mb.TapInteraction(mb.FeaturesetDescriptor(layerId: id), (
          feature,
          context,
        ) {
          if (id.startsWith('campus-destination')) {
            final destination =
                widget.model.data?.destinations[feature.properties['id']];
            if (destination != null) {
              unawaited(widget.model.select(destination));
            }
          } else {
            final building = feature.properties['building_id'];
            if (building is String) {
              unawaited(widget.model.selectBuilding(building));
            }
          }
        }, radius: 24),
        interactionID: '$id-tap',
      );
    }
    _selectionInstalled = true;
  }

  @override
  void dispose() {
    unawaited(_pan?.cancel());
    if (_adapter case final adapter?) widget.model.detach(adapter);
    // MapWidget owns disposal of the native MapboxMap and its interactions.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: mb.MapWidget(
          key: ValueKey('campus-map-$_retry'),
          viewport: _initialViewport,
          styleUri: mb.MapboxStyles.STANDARD,
          onMapCreated: _created,
          onStyleLoadedListener: (_) => _styleLoaded(),
          onMapLoadedListener: (_) => widget.model.mapReady(),
          onCameraChangeListener: (event) =>
              widget.model.cameraChanged(event.cameraState.bearing),
          onMapLoadErrorListener: (_) => widget.model.mapFailed(),
        ),
      ),
    ],
  );
}

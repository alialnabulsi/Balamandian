import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/campus_repository.dart';
import '../../../data/repositories/campus_location_repository.dart';
import '../../../data/services/route_simulation_service.dart';
import '../../../domain/models/campus/campus_data.dart';
import '../../../domain/models/campus/campus_route.dart';
import '../../../domain/models/campus/geo_point.dart';
import '../../../domain/models/campus/navigation_fix.dart';
import '../../../domain/services/campus_routing_service.dart';
import '../../../domain/services/destination_search.dart';
import '../../../domain/services/navigation_progress.dart';
import '../mapbox/campus_map_adapter.dart';

enum CampusMapMode { explore, search, selected, planning, navigating, arrived }

/// A deliberate camera request, consumed by the view after overlay layout.
class CampusCameraRequest {
  const CampusCameraRequest(this.revision, {this.point, this.route});
  final int revision;
  final GeoPoint? point;
  final CampusRoute? route;
}

class CampusSearchSnapshot {
  const CampusSearchSnapshot({
    this.places = const [],
    this.loading = false,
    this.error,
  });
  final List<CampusDestination> places;
  final bool loading;
  final String? error;
}

class CampusMapViewModel extends ChangeNotifier {
  CampusMapViewModel({
    required this.repository,
    required this.location,
    this.routing = const CampusRoutingService(),
    this.search = const DestinationSearch(),
    this.debugGraph = false,
  });
  final CampusRepository repository;
  final CampusLocationRepository location;
  final CampusRoutingService routing;
  final DestinationSearch search;
  final bool debugGraph;
  final navigationFocus = ValueNotifier<bool>(false);
  CampusData? data;
  CampusMapAdapter? _map;
  CampusMapMode mode = CampusMapMode.explore;
  bool loading = false,
      calculating = false,
      mapLoading = true,
      threeDimensional = true;
  bool follow = true, avoidStairs = false, usingGps = false, _disposed = false;
  bool _visible = true,
      _foreground = true,
      _wantsLocation = false,
      _dark = false;
  String? error, mapError, queryCategory, startDestinationId, entranceId;
  String query = '';
  double cameraBearing = 0;
  bool get searching => mode == CampusMapMode.search;
  CampusMapMode _beforeSearch = CampusMapMode.explore;
  bool campusSheetDismissed = false;
  bool _requestingLocation = false;
  int _cameraRevision = 0;
  CampusCameraRequest? cameraRequest;
  int mapRetryRevision = 0;
  ({double top, double right, double bottom, double legalBottom})? _viewport;
  bool get directionsAvailable =>
      data?.routingAvailable == true &&
      destinationEntrances.any((e) => data!.nodes.containsKey(e.nodeId));
  bool get canSwap =>
      startDestinationId != null && destinationEntrances.isNotEmpty;
  CampusDestination? selected;
  RouteOrigin? origin;
  String startLabel = 'Choose a starting point';
  CampusRoute? plannedRoute;
  NavigationProgress? progress;
  NavigationFix? fix;
  LocationAccess locationAccess = LocationAccess.idle;
  StreamSubscription<NavigationFix>? _gpsSubscription, _simulationSubscription;
  RouteSimulationService? _simulation;
  Timer? _acquisition;
  DateTime? _lastRerouteAttempt;
  Future<void> _rendering = Future<void>.value();
  int _locationGeneration = 0, _routeGeneration = 0;
  bool get simulated => _simulation != null;
  bool get simulationPaused => _simulation?.paused ?? true;
  double get simulationSpeed => _simulation?.speed ?? 1;
  bool get navigating =>
      mode == CampusMapMode.navigating || mode == CampusMapMode.arrived;
  bool get focused => navigating && _visible;
  CampusSearchSnapshot get searchSnapshot {
    if (loading) return const CampusSearchSnapshot(loading: true);
    if (data == null) {
      return CampusSearchSnapshot(
        error: error ?? 'Places unavailable. Try again.',
      );
    }
    try {
      return CampusSearchSnapshot(
        places: search.search(
          data!.destinations.values,
          query,
          category: queryCategory,
        ),
      );
    } on Object {
      return const CampusSearchSnapshot(
        error: 'Places could not be searched. Try again.',
      );
    }
  }

  List<CampusDestination> get results => searchSnapshot.places;
  List<String> get categories =>
      (data?.destinations.values.map((d) => d.category).toSet().toList() ?? [])
        ..sort();
  List<CampusEntrance> get destinationEntrances =>
      selected?.entranceIds.map((id) => data!.entrances[id]!).toList() ?? [];
  bool get mapAttached => _map != null;
  void retrySearch() {
    if (!searching) return;
    if (data == null) {
      unawaited(load());
    } else {
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    if (navigationFocus.value != focused) navigationFocus.value = focused;
    notifyListeners();
  }

  Future<void> load() async {
    if (loading || data != null) return;
    loading = true;
    error = null;
    _notify();
    try {
      final loaded = await repository.load();
      if (_disposed) return;
      data = loaded;
    } on Object {
      if (!_disposed) {
        error = 'Campus data could not be loaded or validated. Please retry.';
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> attach(CampusMapAdapter map, {required bool dark}) async {
    _map = map;
    _dark = dark;
    mapLoading = true;
    mapError = null;
    _notify();
    await _render(() async {
      await map.install(
        data!,
        debugGraph: kDebugMode && debugGraph,
        dark: dark,
      );
      await map.route(plannedRoute);
      await map.highlight(selected?.buildingId);
      await map.selectDestination(selected?.id);
      await map.position(fix, simulated: simulated);
      if (_viewport case final insets?) {
        await map.viewport(
          top: insets.top,
          right: insets.right,
          bottom: insets.bottom,
          legalBottom: insets.legalBottom,
        );
      }
    });
    if (_disposed || _map != map) return;
    mapLoading = false;
    _notify();
  }

  void detach(CampusMapAdapter map) {
    if (_map == map) _map = null;
  }

  void viewport({
    required double top,
    required double right,
    required double bottom,
    required double legalBottom,
  }) {
    final insets = (
      top: top,
      right: right,
      bottom: bottom,
      legalBottom: legalBottom,
    );
    if (_viewport == insets) return;
    _viewport = insets;
    if (_map case final map?) {
      unawaited(
        _render(() async {
          final latest = _viewport!;
          await map.viewport(
            top: latest.top,
            right: latest.right,
            bottom: latest.bottom,
            legalBottom: latest.legalBottom,
          );
        }),
      );
    }
  }

  void mapFailed() {
    if (mapError != null || _disposed) return;
    mapLoading = false;
    mapError = 'Map imagery unavailable. Check your connection.';
    _notify();
  }

  void mapReady() {
    if (mapError == null) {
      mapLoading = false;
      _notify();
    }
  }

  void retryMap() {
    if (mapLoading) return;
    mapError = null;
    mapLoading = true;
    mapRetryRevision++;
    _notify();
    if (_map case final map?) unawaited(_render(map.reload));
  }

  Future<void> _render(Future<void> Function() action) {
    final target = _map;
    return _rendering = _rendering.then((_) async {
      if (_disposed || target == null || target != _map) return;
      try {
        await action();
      } on Object {
        if (!_disposed && target == _map) {
          mapError = 'The map could not update. Try again.';
          _notify();
        }
      }
    });
  }

  Future<void> theme(bool dark) async {
    if (_dark == dark) return;
    _dark = dark;
    if (_map case final map?) await _render(() => map.light(dark));
  }

  void searchFor(String value) {
    if (!searching) return;
    query = value;
    _notify();
  }

  void beginSearch() {
    if (navigating || searching) return;
    _beforeSearch = mode;
    mode = CampusMapMode.search;
    ++_routeGeneration;
    calculating = false;
    _cancelCamera();
    _notify();
  }

  void cancelSearch() {
    if (!searching) return;
    mode = _beforeSearch;
    _notify();
  }

  void category(String? value) {
    if (!searching) beginSearch();
    queryCategory = value;
    _notify();
  }

  Future<void> select(CampusDestination destination) async {
    if (navigating ||
        (mode == CampusMapMode.selected && selected?.id == destination.id)) {
      return;
    }
    ++_routeGeneration;
    follow = false;
    calculating = false;
    selected = destination;
    entranceId = null;
    plannedRoute = null;
    progress = null;
    mode = CampusMapMode.selected;
    cameraRequest = CampusCameraRequest(
      ++_cameraRevision,
      point: destination.point,
    );
    _notify();
    if (_map case final map?) {
      await _render(() async {
        await map.route(null);
        await map.highlight(destination.buildingId);
        await map.selectDestination(destination.id);
      });
    }
  }

  Future<void> selectBuilding(String id) async {
    final candidates = data!.destinations.values.where(
      (d) => d.buildingId == id,
    );
    if (candidates.isNotEmpty) await select(candidates.first);
  }

  void directions() {
    if (selected == null ||
        !directionsAvailable ||
        mode != CampusMapMode.selected) {
      return;
    }
    mode = CampusMapMode.planning;
    error = null;
    _notify();
  }

  void chooseEntrance(String? id) {
    entranceId = id;
    _invalidateRoute();
  }

  void stairs(bool value) {
    avoidStairs = value;
    _invalidateRoute();
  }

  void _invalidateRoute() {
    _routeGeneration++;
    calculating = false;
    _cancelCamera();
    plannedRoute = null;
    progress = null;
    error = null;
    if (_map case final map?) unawaited(_render(() => map.route(null)));
    _notify();
  }

  void startAtEntrance(CampusEntrance entrance) {
    usingGps = false;
    startDestinationId = entrance.destinationId;
    origin = RouteOrigin.node(entrance.nodeId);
    startLabel = entrance.name;
    _invalidateRoute();
  }

  void startAtMapPoint(GeoPoint point) {
    if (mode != CampusMapMode.planning) return;
    usingGps = false;
    startDestinationId = null;
    origin = RouteOrigin.point(point);
    startLabel = 'Selected path location';
    _invalidateRoute();
  }

  void swap() {
    if (startDestinationId == null ||
        selected == null ||
        destinationEntrances.isEmpty) {
      error = 'Choose a starting place before swapping.';
      _notify();
      return;
    }
    final old = selected!;
    final from = destinationEntrances.firstWhere(
      (e) => e.id == entranceId,
      orElse: () => destinationEntrances.first,
    );
    selected = data!.destinations[startDestinationId]!;
    if (_map case final map?) {
      unawaited(
        _render(() async {
          await map.selectDestination(selected?.id);
          await map.highlight(selected?.buildingId);
        }),
      );
    }
    entranceId = null;
    startAtEntrance(from);
    startLabel = old.name;
    _notify();
  }

  Future<void> calculate() async {
    if (selected == null ||
        calculating ||
        mode != CampusMapMode.planning ||
        !directionsAvailable) {
      return;
    }
    final generation = ++_routeGeneration;
    calculating = true;
    error = null;
    _notify();
    // Yield one event-loop turn so the actual computation has visible feedback.
    await Future<void>.delayed(Duration.zero);
    if (_disposed || generation != _routeGeneration) {
      return;
    }
    try {
      final start = usingGps && fix != null
          ? RouteOrigin.point(fix!.point, accuracy: fix!.accuracy)
          : origin;
      if (start == null) {
        throw const CampusRoutingException(
          'Choose a starting point or use your current location.',
        );
      }
      final route = routing.plan(
        data!,
        start,
        selected!,
        entranceId: entranceId,
        policy: WalkingPolicy(avoidStairs: avoidStairs),
      );
      plannedRoute = route;
      cameraRequest = CampusCameraRequest(++_cameraRevision, route: route);
      if (_map case final map?) {
        await _render(() async {
          if (generation != _routeGeneration ||
              mode != CampusMapMode.planning) {
            return;
          }
          await map.route(route);
        });
      }
    } on CampusRoutingException catch (e) {
      plannedRoute = null;
      error = e.message;
      if (_map case final map?) await _render(() => map.route(null));
    } finally {
      if (generation == _routeGeneration) {
        calculating = false;
        _notify();
      }
    }
  }

  Future<void> locate({bool asOrigin = false, bool request = true}) async {
    if (_disposed || simulated || !_visible || !_foreground) {
      return;
    }
    if (asOrigin) {
      usingGps = true;
      startDestinationId = null;
      origin = null;
      startLabel = 'Current location';
      _invalidateRoute();
    }
    if (_requestingLocation || locationAccess == LocationAccess.acquiring) {
      return;
    }
    _requestingLocation = true;
    _wantsLocation = true;
    final generation = ++_locationGeneration;
    _acquisition?.cancel();
    locationAccess = LocationAccess.acquiring;
    _notify();
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    try {
      final access = await location.access(request: request);
      if (_disposed ||
          generation != _locationGeneration ||
          !_visible ||
          !_foreground) {
        return;
      }
      locationAccess = access;
      if (access == LocationAccess.ready) {
        locationAccess = LocationAccess.acquiring;
        _gpsSubscription = location.fixes.listen(
          _onGps,
          onError: (Object _) {
            if (_disposed) return;
            locationAccess = LocationAccess.unavailable;
            _notify();
            unawaited(_gpsSubscription?.cancel());
            _gpsSubscription = null;
          },
        );
      }
      if (locationAccess == LocationAccess.acquiring) {
        _acquisition = Timer(const Duration(seconds: 25), () {
          if (_disposed ||
              generation != _locationGeneration ||
              locationAccess != LocationAccess.acquiring) {
            return;
          }
          locationAccess = LocationAccess.unavailable;
          unawaited(_gpsSubscription?.cancel());
          _gpsSubscription = null;
          _notify();
        });
      }
    } on Object {
      if (!_disposed && generation == _locationGeneration) {
        locationAccess = LocationAccess.unavailable;
      }
    } finally {
      _requestingLocation = false;
    }
    _notify();
  }

  void _onGps(NavigationFix value) {
    if (_disposed || simulated || !_visible || !_foreground) return;
    if (DateTime.now().difference(value.time).abs() >
        const Duration(seconds: 20)) {
      return;
    }
    if (!value.accuracy.isFinite ||
        value.accuracy < 0 ||
        !value.point.longitude.isFinite ||
        !value.point.latitude.isFinite ||
        value.point.longitude.abs() > 180 ||
        value.point.latitude.abs() > 90 ||
        (fix != null && !value.time.isAfter(fix!.time))) {
      return;
    }
    _acquisition?.cancel();
    fix = value;
    locationAccess = LocationAccess.ready;
    if (navigating) _advance(value);
    if (_map case final map?) {
      unawaited(
        _render(() async {
          await map.position(value, simulated: false);
          if (follow) {
            await map.focus(
              value.point,
              heading: value.heading,
              navigation: navigating,
            );
          }
        }),
      );
    }
    _notify();
  }

  Future<void> locationSettings() async {
    try {
      await location.settings(locationAccess);
    } on Object {
      error = 'Settings could not be opened. Open location permissions in Android settings.';
      _notify();
    }
  }

  Future<void> beginNavigation({bool simulate = false}) async {
    if (mode != CampusMapMode.planning || calculating) return;
    final generation = _routeGeneration;
    final route = plannedRoute;
    if (route == null || route.points.length < 2) {
      error = 'Choose a walking route with some distance to navigate.';
      _notify();
      return;
    }
    if (!simulate) {
      if (data!.fixture) {
        error = 'Real GPS navigation is disabled for the synthetic demonstration network.';
        _notify();
        return;
      }
      if (fix == null ||
          locationAccess != LocationAccess.ready ||
          DateTime.now().difference(fix!.time).abs() >
              const Duration(seconds: 20)) {
        error = 'Acquire a current GPS location before starting outdoor navigation.';
        await locate();
        return;
      }
      // A preview from a manual entrance must be recomputed from actual GPS.
      usingGps = true;
      await calculate();
      if (plannedRoute == null || _disposed || mode != CampusMapMode.planning) {
        return;
      }
    }
    error = null;
    progress = NavigationProgress(plannedRoute!);
    _lastRerouteAttempt = null;
    follow = true;
    mode = CampusMapMode.navigating;
    if (simulate) {
      ++_locationGeneration;
      await _gpsSubscription?.cancel();
      if (_disposed ||
          generation != _routeGeneration ||
          mode != CampusMapMode.navigating) {
        return;
      }
      _gpsSubscription = null;
      _simulation = RouteSimulationService(plannedRoute!);
      _simulationSubscription = _simulation!.fixes.listen((value) {
        if (_disposed) return;
        fix = value;
        _advance(value);
        if (_map case final map?) {
          unawaited(
            _render(() async {
              await map.position(value, simulated: true);
              if (follow) {
                await map.focus(
                  value.point,
                  heading: value.heading,
                  navigation: true,
                );
              }
            }),
          );
        }
        _notify();
      });
      _simulation!.advance(Duration.zero);
      _simulation!.resume();
    }
    _notify();
  }

  void _advance(NavigationFix value) {
    final reroute = progress?.update(value) ?? false;
    if (progress?.arrived == true) {
      mode = CampusMapMode.arrived;
      _simulation?.pause();
    }
    if (reroute &&
        !simulated &&
        !calculating &&
        (_lastRerouteAttempt == null ||
            value.time.difference(_lastRerouteAttempt!).inSeconds >= 15)) {
      _lastRerouteAttempt = value.time;
      unawaited(_reroute(value));
    }
  }

  Future<void> _reroute(NavigationFix value) async {
    calculating = true;
    _notify();
    try {
      final route = routing.plan(
        data!,
        RouteOrigin.point(value.point, accuracy: value.accuracy),
        selected!,
        entranceId: entranceId,
        policy: WalkingPolicy(avoidStairs: avoidStairs),
      );
      plannedRoute = route;
      progress = NavigationProgress(route);
      error = null;
      if (_map case final map?) await _render(() => map.route(route));
    } on CampusRoutingException catch (e) {
      error = e.message;
    } finally {
      calculating = false;
      _notify();
    }
  }

  void pauseSimulation() {
    if (simulationPaused) {
      _simulation?.resume();
    } else {
      _simulation?.pause();
    }
    _notify();
  }

  void simulationSpeedTo(double value) {
    _simulation?.speed = value;
    _notify();
  }

  void stopFollowing() {
    _cancelCamera();
    if (!follow) return;
    follow = false;
    _notify();
  }

  void cameraChanged(double bearing) {
    if ((bearing - cameraBearing).abs() < 1) return;
    cameraBearing = bearing;
    _notify();
  }

  /// Clear in-memory location/route state when the authenticated account leaves.
  void resetSession() {
    _lastRerouteAttempt = null;
    _wantsLocation = false;
    ++_locationGeneration;
    ++_routeGeneration;
    _acquisition?.cancel();
    unawaited(_gpsSubscription?.cancel());
    _gpsSubscription = null;
    _simulation?.dispose();
    _simulation = null;
    unawaited(_simulationSubscription?.cancel());
    _simulationSubscription = null;
    fix = null;
    progress = null;
    plannedRoute = null;
    selected = null;
    origin = null;
    usingGps = false;
    startDestinationId = null;
    entranceId = null;
    startLabel = 'Choose a starting point';
    locationAccess = LocationAccess.idle;
    mode = CampusMapMode.explore;
    query = '';
    queryCategory = null;
    campusSheetDismissed = false;
    _cancelCamera();
    error = null;
    _notify();
  }

  Future<void> recenter() async {
    follow = true;
    if (fix == null) {
      await locate();
      return;
    }
    if (_map case final map?) {
      await _render(
        () => map.focus(
          fix!.point,
          heading: fix!.heading,
          navigation: navigating,
        ),
      );
    }
    _notify();
  }

  void endNavigation() {
    final wasSimulated = simulated;
    _simulation?.dispose();
    _simulation = null;
    unawaited(_simulationSubscription?.cancel());
    _simulationSubscription = null;
    progress = null;
    if (wasSimulated) fix = null;
    _lastRerouteAttempt = null;
    mode = CampusMapMode.planning;
    error = null;
    if (_map case final map?) {
      unawaited(_render(() => map.position(fix, simulated: false)));
    }
    if (wasSimulated && _wantsLocation && _visible && _foreground) {
      unawaited(locate(request: false));
    }
    _notify();
  }

  void closeSelection() {
    if (navigating) endNavigation();
    selected = null;
    mode = CampusMapMode.explore;
    error = null;
    _invalidateRoute();
    if (_map case final map?) {
      unawaited(
        _render(() async {
          await map.highlight(null);
          await map.selectDestination(null);
        }),
      );
    }
  }

  void dismissCampus() {
    campusSheetDismissed = true;
    _notify();
  }

  void closePlanning() {
    if (mode != CampusMapMode.planning) return;
    mode = CampusMapMode.selected;
    _invalidateRoute();
  }

  void closeContext() {
    switch (mode) {
      case CampusMapMode.search:
        cancelSearch();
      case CampusMapMode.planning:
        closePlanning();
      case CampusMapMode.selected:
        closeSelection();
      case CampusMapMode.navigating || CampusMapMode.arrived:
        endNavigation();
      case CampusMapMode.explore:
        dismissCampus();
    }
  }

  void _cancelCamera() {
    ++_cameraRevision;
    cameraRequest = null;
  }

  Future<void> frameCamera(int revision) async {
    final request = cameraRequest;
    final map = _map;
    if (request == null || request.revision != revision || map == null) return;
    cameraRequest = null;
    await _render(() async {
      if (_cameraRevision != revision || !_visible) return;
      if (request.route case final route?) {
        await map.fit(route);
      } else if (request.point case final point?) {
        await map.focus(point);
      }
    });
  }

  Future<void> overview() async {
    _cancelCamera();
    follow = false;
    if (_map case final map?) await _render(map.overview);
  }

  Future<void> north() async {
    if (_map case final map?) await _render(map.north);
  }

  Future<void> togglePerspective() async {
    threeDimensional = !threeDimensional;
    _notify();
    if (_map case final map?) {
      await _render(() => map.perspective(threeDimensional));
    }
  }

  void visibility(bool visible) {
    if (_disposed) return;
    if (_visible == visible) return;
    _visible = visible;
    _syncActivity();
  }

  void foreground(bool active) {
    if (_foreground == active) return;
    _foreground = active;
    _syncActivity();
  }

  void _syncActivity() {
    if (!_visible || !_foreground) {
      _cancelCamera();
      _acquisition?.cancel();
      ++_locationGeneration;
      if (locationAccess == LocationAccess.acquiring) {
        locationAccess = LocationAccess.idle;
      }
      unawaited(_gpsSubscription?.cancel());
      _gpsSubscription = null;
      _simulation?.pause();
    } else if (_wantsLocation && !simulated) {
      unawaited(locate(request: false));
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _acquisition?.cancel();
    ++_locationGeneration;
    ++_routeGeneration;
    _map = null;
    unawaited(_gpsSubscription?.cancel());
    unawaited(_simulationSubscription?.cancel());
    _simulation?.dispose();
    navigationFocus.dispose();
    super.dispose();
  }
}

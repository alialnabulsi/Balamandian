import 'dart:async';
import 'dart:convert';

import 'package:balamandian/data/repositories/campus_repository.dart';
import 'package:balamandian/data/repositories/campus_location_repository.dart';
import 'package:balamandian/data/services/campus_location_service.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/map/mapbox/campus_map_configuration.dart';
import 'package:balamandian/ui/map/mapbox/mapbox_campus_adapter.dart';
import 'package:balamandian/ui/map/mapbox/mapbox_campus_surface.dart';
import 'package:balamandian/ui/map/view_models/campus_map_view_model.dart';
import 'package:balamandian/ui/map/widgets/campus_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

/// Explicit native test entry; no account or authentication state is modified.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native Standard layers, selective clipping, route and simulation', (
    tester,
  ) async {
    expect(
      CampusMapConfiguration.configured,
      isTrue,
      reason: 'Pass an ignored public-token defines file.',
    );
    CampusMapConfiguration.initialize();
    final model = CampusMapViewModel(
      repository: AssetCampusRepository(
        read: rootBundle.loadString,
        fixture: true,
      ),
      location: CampusLocationRepository(ForegroundCampusLocationService()),
    );
    await model.load();
    MapboxCampusAdapter? adapter;
    final style = Completer<void>();
    final snapshots = <String, String>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CampusMapScreen(
            model: model,
            surfaceBuilder: (context, top, bottom) => MapboxCampusSurface(
              model: model,
              topPadding: top,
              bottomPadding: bottom,
              onReady: (created) {
                adapter = created;
                if (!style.isCompleted) style.complete();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await const MethodChannel('balamandian/splash')
        .invokeMethod<void>('reveal');
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!style.isCompleted && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await style.future.timeout(const Duration(seconds: 1));
    expect(model.mapError, isNull);
    final map = adapter!.map;
    final libraryPoint = adapter!.point(
      model.data!.destinations['demo-library']!.point,
    );
    await map.setCamera(
      mb.CameraOptions(
        center: libraryPoint,
        zoom: 17,
        pitch: 0,
        padding: mb.MbxEdgeInsets(top: 0, left: 0, right: 0, bottom: 0),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final pixel = await map.pixelForCoordinate(libraryPoint);
    var hits = <mb.QueriedRenderedFeature?>[];
    final renderDeadline = DateTime.now().add(const Duration(seconds: 15));
    while (hits.isEmpty && DateTime.now().isBefore(renderDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      hits = await map.queryRenderedFeatures(
        mb.RenderedQueryGeometry.fromScreenCoordinate(pixel),
        mb.RenderedQueryOptions(
          layerIds: ['campus-destination-dots'],
          filter: null,
        ),
      );
    }
    debugPrint(
      'CAMPUS_MARKER_HITS ${hits.map((h) => h?.queriedFeature.feature['properties']).toList()} at ${pixel.x},${pixel.y}',
    );
    expect(
      hits,
      isNotEmpty,
      reason:
          'Marker geometry must be rendered at its projected screen location.',
    );
    // Native GestureDetector requires monotonic timestamps. The test default
    // of zero can be interpreted as an already expired Android long press.
    final tap = await tester.createGesture();
    await tap.down(
      tester.getTopLeft(find.byType(mb.MapWidget)) + Offset(pixel.x, pixel.y),
      timeStamp: binding.currentSystemFrameTimeStamp,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tap.up(timeStamp: binding.currentSystemFrameTimeStamp);
    final tapDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (model.selected == null && DateTime.now().isBefore(tapDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    expect(
      model.selected?.id,
      'demo-library',
      reason: 'Native destination marker tap must resolve its catalog record.',
    );
    model.closeSelection();
    expect(await map.styleLayerExists('campus-clip'), isTrue);
    expect(await map.styleLayerExists('campus-buildings'), isTrue);
    expect(
      (await map.getStyleLayerProperty(
        'campus-clip',
        'clip-layer-scope',
      )).value,
      ['basemap'],
    );
    expect(
      (await map.getStyleLayerProperty(
        'campus-clip',
        'clip-layer-types',
      )).value,
      ['model'],
    );
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
        snapshots[name] = base64Encode(await map.snapshot());
      });
    }

    await map.setCamera(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(-.126, 51.5339)),
        zoom: 18,
        pitch: 55,
        bearing: 0,
        padding: mb.MbxEdgeInsets(top: 0, left: 0, right: 0, bottom: 0),
      ),
    );
    await map.setStyleLayerProperty('campus-clip', 'visibility', 'none');
    await map.setStyleLayerProperty('campus-buildings', 'visibility', 'none');
    await capture('native-baseline-3d');
    await map.setStyleLayerProperty('campus-clip', 'visibility', 'visible');
    await capture('native-clipped-3d');
    await map.setStyleLayerProperty(
      'campus-buildings',
      'visibility',
      'visible',
    );
    await capture('native-replacement-3d');
    await adapter!.perspective(false);
    await capture('native-replacement-2d');
    await adapter!.perspective(true);
    await map.addSource(
      mb.RasterDemSource(
        id: 'test-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14,
      ),
    );
    await map.setStyleTerrain(
      jsonEncode({'source': 'test-dem', 'exaggeration': 1}),
    );
    await capture('native-terrain');
    await model.select(model.data!.destinations['demo-east']!);
    model.directions();
    model.startAtEntrance(model.data!.entrances['demo-west-door']!);
    await tester.runAsync(model.calculate);
    expect(model.plannedRoute, isNotNull);
    await capture('native-route');
    await model.beginNavigation(simulate: true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 4)),
    );
    await tester.pump();
    expect(model.progress!.traveled, greaterThan(0));
    await capture('native-simulation');
    model.pauseSimulation();
    expect(model.simulationPaused, isTrue);
    debugPrint('CAMPUS_CAPTURE_READY');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 8)),
    );
    model.endNavigation();
    expect(model.navigationFocus.value, isFalse);
    // Reload the same native map with sourced production data to verify Qalhat.
    final real = await AssetCampusRepository(read: rootBundle.loadString)
        .load();
    await adapter!.install(real, debugGraph: false, dark: false);
    await adapter!.overview();
    await capture('native-qalhat');
    binding.reportData = {
      'snapshots': snapshots,
      'nativeSdk': '11.35.2',
      'flutterSdk': '3.35.2',
    };
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

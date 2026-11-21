import 'dart:async';

import 'package:balamandian/data/repositories/campus_repository.dart';
import 'package:balamandian/data/repositories/campus_location_repository.dart';
import 'package:balamandian/data/services/campus_location_service.dart';
import 'package:balamandian/domain/models/campus/navigation_fix.dart';
import 'package:balamandian/routing/shell_destination.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/measure_size.dart';
import 'package:balamandian/ui/core/ui/navigation/app_bottom_bar.dart';
import 'package:balamandian/ui/core/ui/navigation/bottom_chrome_scope.dart';
import 'package:balamandian/ui/map/mapbox/campus_map_configuration.dart';
import 'package:balamandian/ui/map/mapbox/mapbox_campus_adapter.dart';
import 'package:balamandian/ui/map/mapbox/mapbox_campus_surface.dart';
import 'package:balamandian/ui/map/view_models/campus_map_view_model.dart';
import 'package:balamandian/ui/map/widgets/campus_map_screen.dart';
import 'package:balamandian/ui/map/widgets/campus_panel.dart';
import 'package:balamandian/ui/map/widgets/campus_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

/// Uses real native rendering and the production map UI/chrome. Permission
/// outcomes use an injected provider; this never changes account or OS consent.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Galaxy map presentation and native camera retention',
    (tester) async {
      CampusMapConfiguration.initialize();
      final provider = _LocationOutcomes();
      final model = CampusMapViewModel(
        repository: AssetCampusRepository(read: rootBundle.loadString),
        location: CampusLocationRepository(provider),
      );
      await model.load();
      MapboxCampusAdapter? adapter;
      final harness = GlobalKey<_MapHarnessState>();
      Future<void> settle([int milliseconds = 800]) async {
        for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
      }

      Future<void> capture(String name) async {
        await settle();
        expect(tester.takeException(), isNull);
        debugPrint('MAP_UI_CAPTURE $name');
        // Host tool captures the actual Android display, including the native
        // map, legal ornaments, Flutter UI, status bar and keyboard.
        await settle(2000);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: _MapHarness(
            key: harness,
            model: model,
            onReady: (value) => adapter = value,
          ),
        ),
      );
      await tester.pump();
      await const MethodChannel('balamandian/splash')
          .invokeMethod<void>('reveal');
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (adapter == null && DateTime.now().isBefore(deadline)) {
        await settle(100);
      }
      expect(adapter, isNotNull);
      expect(model.mapError, isNull);
      final media = MediaQuery.of(tester.element(find.byType(CampusMapScreen)));
      binding.reportData = {
        'viewport': [media.size.width, media.size.height],
        'devicePixelRatio': media.devicePixelRatio,
        'textScaleAt16': media.textScaler.scale(16) / 16,
        'viewPadding': [media.viewPadding.top, media.viewPadding.bottom],
        'provider':
            'Injected denied/unavailable outcomes; no OS permission changes',
      };
      debugPrint('MAP_UI_METRICS ${binding.reportData}');
      final map = adapter!.map;
      await capture('01-explore-collapsed');
      expect(
        tester.getSize(find.byType(CampusSearchBar)).height,
        inInclusiveRange(48, 60),
      );
      await tester.tap(find.byTooltip('Expand map panel'));
      await capture('02-campus-expanded');
      await tester.dragFrom(
        tester.getTopLeft(find.byType(CampusPanelHeader)) +
            const Offset(40, 32),
        const Offset(0, 240),
      );
      await settle();
      await tester.tap(find.byTooltip('Close map panel'));
      await capture('03-explore-dismissed');
      final before = await map.getCameraState();
      await tester.tap(find.byTooltip('Search campus'));
      await capture('04-search-keyboard');
      await tester.enterText(find.byType(TextField), 'balamand');
      await capture('05-search-results');
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await capture('06-search-empty');
      expect(find.text('No campus places found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await settle();
      expect(model.query, isEmpty);
      await tester.tap(find.text('University of Balamand'));
      await capture('07-destination-unavailable');
      expect(find.text('Directions'), findsNothing);
      expect(find.text('Walking directions coming soon'), findsOneWidget);
      await tester.tap(find.byTooltip('Close map panel'));
      await settle();
      expect(find.byType(CampusPanel), findsNothing);
      // Keyboard and sheet changes must not change the established camera.
      final established = await map.getCameraState();
      await tester.tap(find.byTooltip('Search campus'));
      await settle();
      await tester.binding.handlePopRoute();
      await settle();
      expect(model.searching, isTrue);
      await tester.binding.handlePopRoute();
      await settle();
      expect(model.mode, CampusMapMode.explore);
      final after = await map.getCameraState();
      expect(after.zoom, closeTo(established.zoom, .01));
      expect(
        after.center.coordinates.lng,
        closeTo(established.center.coordinates.lng, .000001),
      );
      expect(
        after.center.coordinates.lat,
        closeTo(established.center.coordinates.lat, .000001),
      );
      expect(before.zoom, closeTo(after.zoom, .01));
      await tester.tap(find.byTooltip('Switch to 2D'));
      await settle();
      expect((await map.getCameraState()).pitch, closeTo(0, 1));
      await tester.tap(find.byTooltip('Switch to 3D'));
      await settle();
      expect((await map.getCameraState()).pitch, closeTo(45, 1));
      await map.setCamera(mb.CameraOptions(zoom: 16.8, pitch: 32, bearing: 27));
      final manual = await map.getCameraState();
      final mapElement = tester.element(find.byType(mb.MapWidget));
      harness.currentState!.tab(ShellDestination.home);
      await settle();
      harness.currentState!.tab(ShellDestination.map);
      await settle();
      expect(tester.element(find.byType(mb.MapWidget)), same(mapElement));
      expect(find.byType(CampusPanel), findsNothing);
      final returned = await map.getCameraState();
      expect(returned.zoom, closeTo(manual.zoom, .01));
      expect(returned.bearing, closeTo(manual.bearing, .01));
      await tester.tap(find.byTooltip('Campus overview'));
      await settle();
      await capture('08-reset-3d');
      await tester.tap(find.byTooltip('Recenter on my location'));
      await capture('09-location-denied');
      provider.state = LocationAccess.unavailable;
      await tester.tap(find.text('Retry location'));
      await capture('10-location-unavailable');
      harness.currentState!.scale(2);
      await model.select(model.data!.destinations.values.single);
      await capture('11-enlarged-text');
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();

      final fixture = CampusMapViewModel(
        repository: AssetCampusRepository(
          read: rootBundle.loadString,
          fixture: true,
        ),
        location: CampusLocationRepository(_LocationOutcomes()),
      );
      await fixture.load();
      adapter = null;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: _MapHarness(
            model: fixture,
            onReady: (value) => adapter = value,
          ),
        ),
      );
      final fixtureDeadline = DateTime.now().add(const Duration(seconds: 45));
      while (adapter == null && DateTime.now().isBefore(fixtureDeadline)) {
        await settle(100);
      }
      expect(adapter, isNotNull);
      await fixture.select(fixture.data!.destinations['demo-east']!);
      await settle();
      await tester.tap(find.text('Directions'));
      await capture('12-fixture-planner');
      fixture.startAtEntrance(fixture.data!.entrances['demo-west-door']!);
      await tester.runAsync(fixture.calculate);
      await settle();
      await capture('13-fixture-route-preview');
      await tester.tap(find.byTooltip('Expand map panel'));
      await settle();
      final draggable = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(draggable.controller!.size, closeTo(draggable.maxChildSize, .01));
      await capture('15-fixture-planner-expanded');
      await tester.dragFrom(
        tester.getTopLeft(find.byType(CampusPanelHeader)) +
            const Offset(40, 32),
        const Offset(0, -450),
      );
      await settle();
      await tester.ensureVisible(find.text('Simulate this route'));
      await tester.tap(find.text('Simulate this route'));
      await settle();
      fixture.pauseSimulation();
      await capture('14-fixture-simulation');
      expect(fixture.simulated, isTrue);
      expect(fixture.navigating, isTrue);
      expect(find.byType(AppBottomBar), findsNothing);
      fixture.endNavigation();
      await settle();
      fixture.closePlanning();
      await settle();
      expect(fixture.mode, CampusMapMode.selected);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
    skip: const bool.fromEnvironment('CAMPUS_INTERACTION_SMOKE'),
  );

  testWidgets(
    'Native finger pan, keyboard selection and attribution dialog',
    (tester) async {
      binding.shouldPropagateDevicePointerEvents = true;
      try {
        CampusMapConfiguration.initialize();
        final model = CampusMapViewModel(
          repository: AssetCampusRepository(read: rootBundle.loadString),
          location: CampusLocationRepository(_LocationOutcomes()),
        );
        await model.load();
        MapboxCampusAdapter? adapter;
        final harness = GlobalKey<_MapHarnessState>();
        Future<void> settle([int milliseconds = 700]) async {
          for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
          }
        }

        Future<void> capture(String name) async {
          await settle();
          debugPrint('MAP_UI_CAPTURE $name');
          await settle(name == '18-attribution-dialog' ? 2000 : 1000);
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: _MapHarness(
              key: harness,
              model: model,
              onReady: (value) => adapter = value,
            ),
          ),
        );
        await tester.pump();
        await const MethodChannel('balamandian/splash')
            .invokeMethod<void>('reveal');
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (adapter == null && DateTime.now().isBefore(deadline)) {
          await settle(100);
        }
        expect(adapter, isNotNull);
        final map = adapter!.map;
        await map.setCamera(mb.CameraOptions(zoom: 17.2, pitch: 0));
        await settle();
        final before = await map.getCameraState();
        // The host injects through Android input after confirming this app is
        // foregrounded. Flutter synthetic drags do not cover native ornaments.
        final deviceScale = View.of(
          tester.element(find.byType(CampusMapScreen)),
        ).devicePixelRatio;
        debugPrint(
          'MAP_UI_NATIVE_PAN ${(120 * deviceScale).round()} ${(320 * deviceScale).round()} ${(216 * deviceScale).round()} ${(384 * deviceScale).round()}',
        );
        await settle(2000);
        await settle();
        final panned = await map.getCameraState();
        expect(
          (panned.center.coordinates.lng - before.center.coordinates.lng)
                  .abs() +
              (panned.center.coordinates.lat - before.center.coordinates.lat)
                  .abs(),
          greaterThan(.00001),
        );
        expect(model.follow, isFalse);
        final nativeElement = tester.element(find.byType(mb.MapWidget));
        harness.currentState!.tab(ShellDestination.home);
        await settle();
        harness.currentState!.tab(ShellDestination.map);
        await settle();
        final returned = await map.getCameraState();
        expect(tester.element(find.byType(mb.MapWidget)), same(nativeElement));
        expect(
          returned.center.coordinates.lng,
          closeTo(panned.center.coordinates.lng, .000001),
        );
        expect(
          returned.center.coordinates.lat,
          closeTo(panned.center.coordinates.lat, .000001),
        );
        await capture('16-native-pan-retained');
        await tester.tap(find.byTooltip('Search campus'));
        await settle();
        expect(
          MediaQuery.viewInsetsOf(tester.element(find.byType(CampusMapScreen)))
              .bottom,
          greaterThan(0),
        );
        await tester.tap(find.text('University of Balamand'));
        await settle();
        expect(
          MediaQuery.viewInsetsOf(tester.element(find.byType(CampusMapScreen)))
              .bottom,
          0,
        );
        expect(model.mode, CampusMapMode.selected);
        await capture('17-native-keyboard-selection');
        final attribution = await map.attribution.getSettings();
        expect(attribution.enabled, isTrue);
        expect(attribution.clickable, isTrue);
        final mapRect = tester.getRect(find.byType(mb.MapWidget));
        final icon =
            mapRect.topLeft +
            Offset(
              (attribution.marginLeft ?? 0) + 12,
              mapRect.height - (attribution.marginBottom ?? 0) - 12,
            );
        debugPrint(
          'MAP_UI_NATIVE_ATTRIBUTION ${(icon.dx * deviceScale).round()} ${(icon.dy * deviceScale).round()}',
        );
        await settle(1000);
        await capture('18-attribution-dialog');
        binding.reportData = {
          'nativeFingerPan': true,
          'tabCameraRetention': true,
          'keyboardSelection': true,
          'attributionEnabledAndClickable': true,
        };
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        expect(tester.takeException(), isNull);
      } finally {
        binding.shouldPropagateDevicePointerEvents = false;
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !const bool.fromEnvironment('CAMPUS_INTERACTION_SMOKE'),
  );
}

class _LocationOutcomes implements CampusLocationService {
  LocationAccess state = LocationAccess.denied;
  @override
  Future<LocationAccess> access({required bool request}) async => state;
  @override
  Stream<NavigationFix> watch() => const Stream.empty();
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<bool> openLocationSettings() async => false;
}

class _MapHarness extends StatefulWidget {
  const _MapHarness({super.key, required this.model, required this.onReady});
  final CampusMapViewModel model;
  final ValueChanged<MapboxCampusAdapter> onReady;
  @override
  State<_MapHarness> createState() => _MapHarnessState();
}

class _MapHarnessState extends State<_MapHarness> {
  double _bottom = 0;
  double? _scale;
  ShellDestination _tab = ShellDestination.map;
  void tab(ShellDestination value) {
    widget.model.visibility(value == ShellDestination.map);
    setState(() => _tab = value);
  }

  void scale(double value) => setState(() => _scale = value);
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: _scale == null
          ? MediaQuery.textScalerOf(context)
          : TextScaler.linear(_scale!),
    ),
    child: ListenableBuilder(
      listenable: widget.model.navigationFocus,
      builder: (context, _) {
        final focused = widget.model.navigationFocus.value;
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: BottomChromeScope(
            height: focused ? 0 : _bottom,
            child: IndexedStack(
              index: _tab == ShellDestination.map ? 0 : 1,
              children: [
                CampusMapScreen(
                  model: widget.model,
                  surfaceBuilder: (context, top, bottom) => MapboxCampusSurface(
                    model: widget.model,
                    topPadding: top,
                    bottomPadding: bottom,
                    onReady: widget.onReady,
                  ),
                ),
                const Center(child: Text('Shell tab retention check')),
              ],
            ),
          ),
          bottomNavigationBar: focused
              ? null
              : MeasureSize(
                  onChange: (size) {
                    if (mounted && _bottom != size.height) {
                      setState(() => _bottom = size.height);
                    }
                  },
                  child: AppBottomBar(
                    selected: _tab,
                    onSelected: tab,
                    onCreate: () {},
                  ),
                ),
        );
      },
    ),
  );
}

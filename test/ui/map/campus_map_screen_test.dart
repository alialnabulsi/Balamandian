import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/data/repositories/campus_location_repository.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/map/view_models/campus_map_view_model.dart';
import 'package:balamandian/ui/map/widgets/campus_map_screen.dart';
import 'package:balamandian/ui/map/widgets/campus_destination_row.dart';
import 'package:balamandian/ui/map/widgets/campus_route_planner.dart';
import 'package:balamandian/ui/map/widgets/campus_panel.dart';
import 'package:balamandian/ui/map/widgets/campus_search_bar.dart';
import 'package:balamandian/ui/map/widgets/campus_category_filters.dart';
import 'package:balamandian/data/services/campus_dataset_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../campus_test_support.dart';
import '../startup_test_support.dart';

void main() {
  setUpAll(() async {
    await loadStartupFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<CampusMapViewModel> pump(
    WidgetTester tester, {
    Size size = const Size(390, 750),
    double scale = 1,
    bool dark = false,
    GlobalKey? boundary,
    bool production = false,
    FakeCampusMapAdapter? adapter,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    final location = FakeCampusLocationService();
    final model = CampusMapViewModel(
      repository: FakeCampusRepository(
        production
            ? CampusDatasetService().parse(campusDocuments(fixture: false))
            : campusFixture(),
      ),
      location: CampusLocationRepository(location),
    );
    addTearDown(() {
      model.dispose();
      location.dispose();
    });
    await model.load();
    if (adapter != null) await model.attach(adapter, dark: dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? appDarkTheme : appTheme,
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: RepaintBoundary(
            key: boundary,
            child: CampusMapScreen(
              model: model,
              surfaceBuilder: (context, top, bottom) => const ColoredBox(
                key: ValueKey('map-renderer'),
                color: Color(0xffdfe8e5),
                child: Center(child: Text('FAKE MAP · rendering boundary')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  testWidgets(
    'Search, destination selection and route planning use catalog data',
    (tester) async {
      final model = await pump(tester);
      await tester.tap(find.byTooltip('Search campus'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusDestinationRow), findsNWidgets(4));
      await tester.enterText(find.byType(TextField), 'LIB');
      await tester.pumpAndSettle();
      expect(find.byType(CampusDestinationRow), findsOneWidget);
      await tester.tap(find.text('Demo learning center'));
      await tester.pumpAndSettle();
      expect(model.selected!.id, 'demo-library');
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusRoutePlanner), findsOneWidget);
      expect(model.mode, CampusMapMode.planning);
      model.startAtEntrance(model.data!.entrances['demo-west-door']!);
      await tester.runAsync(model.calculate);
      await tester.pumpAndSettle();
      expect(model.plannedRoute, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Production exploration is compact, dismissible and route availability is honest',
    (tester) async {
      final model = await pump(tester, production: true);
      expect(find.byType(CampusCategoryFilters), findsNothing);
      expect(
        tester.getSize(find.byType(CampusSearchBar)).height,
        inInclusiveRange(48, 52),
      );
      final sheet = find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(sheet).height, inInclusiveRange(72, 96));
      await tester.tap(find.byTooltip('Close map panel'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusPanel), findsNothing);
      model.visibility(false);
      model.visibility(true);
      await tester.pumpAndSettle();
      expect(find.byType(CampusPanel), findsNothing);
      await tester.tap(find.byTooltip('Search campus'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusCategoryFilters), findsNothing);
      await tester.tap(find.text('University of Balamand'));
      await tester.pumpAndSettle();
      expect(find.text('Directions'), findsNothing);
      expect(find.text('Walking directions coming soon'), findsOneWidget);
      await tester.tap(find.byTooltip('Close map panel'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusPanel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Sheet drag and expanded scrolling cooperate without moving the map',
    (tester) async {
      final adapter = FakeCampusMapAdapter();
      final model = await pump(tester, adapter: adapter);
      final element = tester.element(
        find.byKey(const ValueKey('map-renderer')),
      );
      final sheet = find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Material),
          )
          .first;
      final collapsed = tester.getSize(sheet).height;
      await tester.dragFrom(
        tester.getTopLeft(find.byType(CampusPanelHeader)) +
            const Offset(40, 32),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, greaterThan(collapsed));
      expect(adapter.focuses, 0);
      await model.select(model.data!.destinations['demo-east']!);
      await tester.pumpAndSettle();
      expect(adapter.focuses, 1);
      model.directions();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand map panel'));
      await tester.pumpAndSettle();
      final draggable = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(draggable.controller!.size, closeTo(draggable.maxChildSize, .001));
      await tester.dragFrom(
        tester.getTopLeft(find.byType(CampusPanelHeader)) +
            const Offset(40, 32),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final scroller = find.descendant(
        of: find.byType(CampusPanel),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroller.first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(adapter.focuses, 1);
      expect(
        tester.element(find.byKey(const ValueKey('map-renderer'))),
        same(element),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Back handles IME then search, and passive insets retain the camera',
    (tester) async {
      final adapter = FakeCampusMapAdapter();
      final model = await pump(tester, adapter: adapter);
      await tester.tap(find.byTooltip('Search campus'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(model.searching, isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(model.mode, CampusMapMode.explore);
      expect(adapter.focuses, 0);
      expect(adapter.fits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Destination framing waits for the keyboard to finish closing', (
    tester,
  ) async {
    final adapter = FakeCampusMapAdapter();
    final model = await pump(tester, adapter: adapter);
    model.beginSearch();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await model.select(model.data!.destinations['demo-east']!);
    await tester.pumpAndSettle();
    expect(adapter.focuses, 0);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(adapter.focuses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Collapsed campus sheet leaves map gestures reachable', (
    tester,
  ) async {
    await pump(tester, production: true);
    final renderer = tester.renderObject(
      find.byKey(const ValueKey('map-renderer')),
    );
    final hits = tester.hitTestOnBinding(const Offset(120, 320));
    expect(hits.path.any((entry) => identical(entry.target, renderer)), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final config in [
    (const Size(320, 640), 2.0),
    (const Size(640, 320), 1.0),
    (const Size(390, 750), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('Map components fit ${config.$1} at ${config.$2}x dark=$dark', (
        tester,
      ) async {
        final boundary = GlobalKey();
        final model = await pump(
          tester,
          size: config.$1,
          scale: config.$2,
          dark: dark,
          boundary: boundary,
        );
        expect(tester.takeException(), isNull);
        await model.select(model.data!.destinations['demo-east']!);
        await tester.pumpAndSettle();
        model.directions();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (config.$1.width == 390) {
          if (const bool.fromEnvironment('CAPTURE_UI')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              final file = File(
                'build/campus-map-verification/planning-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
        }
        model.closeSelection();
        model.beginSearch();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

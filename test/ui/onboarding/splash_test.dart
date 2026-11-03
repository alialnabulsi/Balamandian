import 'dart:ui' as ui;

import 'package:balamandian/routing/startup_destination.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_loading_logo.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_screen.dart';
import 'package:balamandian/ui/onboarding/widgets/startup_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash advances once only after its loading stroke completes', (
    tester,
  ) async {
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StartupNavigation(
          busy: false,
          screen: StartupDestination.splash,
          back: () {},
          navigate: (screen) {
            expect(screen, StartupDestination.campus);
            navigations++;
          },
          child: const SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2099));
    expect(navigations, 0);
    expect(find.text('Rooted in Balamand. Made for you.'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(navigations, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(navigations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Loading stroke starts at top and fills clockwise', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    for (final progress in [.25, .5, 1.0]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SplashLoadingLogo(
                progress: AlwaysStoppedAnimation(progress),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // Pixel coordinates below are logical pixels at a 1x capture scale.
        bool yellow(int x, int y) {
          final offset = (y * image.width + x) * 4;
          return pixels.getUint8(offset) > 245 &&
              (pixels.getUint8(offset + 1) - 207).abs() < 8 &&
              pixels.getUint8(offset + 2) < 65;
        }

        expect(yellow(78, 2), isTrue);
        expect(yellow(154, 78), isTrue);
        expect(
          yellow(78, 154),
          progress >= .5,
          reason: 'progress $progress, image ${image.width}x${image.height}',
        );
        expect(yellow(2, 78), progress == 1);
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import '../../marketplace_test_support.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/routing/startup_destination.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_loading_logo.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_screen.dart';
import 'package:balamandian/ui/onboarding/widgets/startup_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../startup_test_support.dart';

void main() {
  testWidgets('Splash pauses while backgrounded and resumes without a jump', (
    tester,
  ) async {
    mockNativeSplash(tester);
    await tester.pumpWidget(
      MainApp(
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        holdSplash: true,
        authRepository: noSessionRepository(),
        onboardingRepository: testOnboardingRepository(),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    double stroke() => tester
        .widget<SplashLoadingLogo>(find.byType(SplashLoadingLogo))
        .progress
        .value;
    final before = stroke();
    expect(before, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 8));
    expect(stroke(), before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(stroke(), greaterThan(before));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Disposing during native handoff cancels Flutter animation work',
    (tester) async {
      const channel = MethodChannel('balamandian/splash');
      final revealed = Completer<void>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'reveal') await revealed.future;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: noSessionRepository(),
          onboardingRepository: testOnboardingRepository(),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      revealed.complete();
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
  testWidgets(
    'Native visibility gates the complete stroke and one navigation',
    (tester) async {
      var navigations = 0;
      final layout = Completer<List<num>?>();
      final revealed = Completer<void>();
      final calls = <String>[];
      const channel = MethodChannel('balamandian/splash');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'prepare'
            ? await layout.future
            : await revealed.future;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StartupNavigation(
            busy: false,
            screen: StartupDestination.splash,
            back: () {},
            navigate: (screen, {extra}) {
              expect(screen, StartupDestination.campus);
              navigations++;
            },
            child: const SplashScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(seconds: 8));
      expect(navigations, 0);
      expect(
        tester
            .widget<SplashLoadingLogo>(find.byType(SplashLoadingLogo))
            .progress
            .value,
        0,
      );
      layout.complete([220, 200, 288, 288]);
      await tester.pump();
      await tester.pump();
      expect(calls, ['prepare', 'reveal']);
      expect(
        tester.getCenter(find.byType(SplashLoadingLogo)),
        const Offset(364, 344),
      );
      await tester.pump(const Duration(seconds: 8));
      expect(
        tester
            .widget<SplashLoadingLogo>(find.byType(SplashLoadingLogo))
            .progress
            .value,
        0,
      );
      revealed.complete();
      await tester.pump();
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
    },
  );
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

        final middle = image.width ~/ 2;
        expect(yellow(middle, 2), isTrue);
        expect(yellow(image.width - 2, middle), isTrue);
        expect(
          yellow(middle, image.height - 2),
          progress >= .5,
          reason: 'progress $progress, image ${image.width}x${image.height}',
        );
        expect(yellow(2, middle), progress == 1);
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/routing/startup_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);
  for (final variant in ['mobile-light', 'mobile-dark', 'narrow']) {
    for (final screen in StartupDestination.values) {
      testWidgets(
        '$variant ${screen.segment}: renders and captures native output',
        (tester) async {
          debugDisableShadows = false;
          final size = variant == 'narrow'
              ? const Size(360, 800)
              : const Size(412, 915);
          await pumpStartup(
            tester,
            screen: screen.segment,
            dark: variant == 'mobile-dark',
            size: size,
          );
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            RenderRepaintBoundary? repaint;
            void visit(RenderObject object) {
              if (repaint != null) return;
              if (object is RenderRepaintBoundary && object.size == size) {
                repaint = object;
                return;
              }
              object.visitChildren(visit);
            }

            visit(tester.binding.renderViews.single);
            final image = await repaint!.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/ui-verification/$variant/${screen.segment}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
          debugDisableShadows = true;
        },
      );
    }
  }
  for (final screen in StartupDestination.values) {
    testWidgets(
      '${screen.segment}: narrow phone, 2x text, cutouts and keyboard',
      (tester) async {
        await pumpStartup(
          tester,
          screen: screen.segment,
          size: const Size(320, 640),
          textScale: 2,
          keyboard:
              [
                StartupDestination.signIn,
                StartupDestination.signUp,
                StartupDestination.accountSetup,
                StartupDestination.verifyEmail,
              ].contains(screen)
              ? 280
              : 0,
          padding: const FakeViewPadding(top: 32, bottom: 24),
        );
        expect(tester.takeException(), isNull);
        if (screen != StartupDestination.splash) {
          final action = screen.tourIndex >= 0
              ? (screen.tourIndex == 2 ? 'Get started' : 'Continue')
              : screen == StartupDestination.gettingStarted
              ? 'Log in with SIS'
              : screen == StartupDestination.accountSetup
              ? 'Finish setup'
              : screen == StartupDestination.signUp
              ? 'Continue'
              : screen == StartupDestination.verifyEmail
              ? 'Start again'
              : 'Log in';
          final target = find.text(action).last;
          await tester.ensureVisible(target);
          await tester.pump();
          expect(target.hitTestable(), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

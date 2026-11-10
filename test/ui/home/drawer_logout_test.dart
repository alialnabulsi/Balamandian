import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/routing/shell_destination.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/buttons/drawer_logout_button.dart';
import 'package:balamandian/ui/core/ui/navigation/app_account_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../startup_test_support.dart';

void main() {
  setUpAll(() async {
    await loadStartupFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final size in [
      const Size(390, 844),
      const Size(320, 640),
      const Size(640, 320),
    ]) {
      testWidgets(
        'Logout stays safe and accessible with scrolling at $size, dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = size.width == 320
              ? 2
              : 1;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearAllTestValues();
          });
          var taps = 0;
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? appDarkTheme : appTheme,
              home: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.centerLeft,
                    child: AppAccountDrawer(
                      selected: ShellDestination.home,
                      destinations: List.generate(
                        4,
                        (_) => ShellDestination.drawer,
                      ).expand((items) => items).toList(),
                      onSelected: (_) {},
                      onLogout: () => taps++,
                      email: 'member@example.edu',
                      sisId: 'FICTION001',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byType(DrawerLogoutButton);
          final before = tester.getRect(button);
          expect(before.bottom, lessThanOrEqualTo(size.height - 24));
          expect(before.bottom, greaterThan(size.height - 24 - 32));
          expect(before.height, greaterThanOrEqualTo(48));
          await tester.drag(find.byType(ListView), const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(tester.getRect(button), before);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(taps, 1);
          final semantics = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
          expect(tester.takeException(), isNull);
          if (size.width == 390) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/ui-verification/auth-session/drawer-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

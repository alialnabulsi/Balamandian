import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_place_card.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_star_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../marketplace_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import 'marketplace_widget_support.dart';

Future<void> captureMarket(WidgetTester tester, String name, Size size) async {
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
    final file = File('build/ui-verification/marketplace/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadHomeFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      ('mobile', const Size(390, 844), 1.0),
      ('narrow', const Size(320, 640), 1.0),
      ('landscape', const Size(844, 390), 1.0),
      ('large-text', const Size(320, 640), 2.0),
    ]) {
      for (final detail in [false, true]) {
        testWidgets(
          '${dark ? 'dark' : 'light'} ${variant.$1} ${detail ? 'detail' : 'root'} render, overflow, semantics and native screenshot',
          (tester) async {
            debugDisableShadows = false;
            final repo = FakeMarketplaceRepository(populated: true);
            repo.items.add(
              MarketplacePlaceSummary.fromJson(
                placeJson(
                  id: '22222222-2222-4222-8222-444444444444',
                  name: 'Fictional Paper & Ink',
                  slug: 'paper-and-ink',
                ),
              ),
            );
            await pumpMarketplace(
              tester,
              repository: repo,
              dark: dark,
              size: variant.$2,
              textScale: variant.$3,
              location: detail ? '/market/$marketPlaceId' : '/market',
            );
            await tester.runAsync(() async {
              final context = tester.element(find.byType(MaterialApp));
              for (final name in ['coffee', 'food', 'books']) {
                await precacheImage(
                  AssetImage('assets/marketplace/images/$name.jpg'),
                  context,
                );
              }
            });
            await tester.pump();
            expect(tester.takeException(), isNull);
            await captureMarket(
              tester,
              '${dark ? 'dark' : 'light'}-${variant.$1}-${detail ? 'detail' : 'root'}',
              variant.$2,
            );
            if (detail) {
              await Scrollable.ensureVisible(
                tester.element(find.byType(MarketplaceStarInput)),
                alignment: .2,
              );
              await tester.pumpAndSettle();
              for (var rating = 1; rating <= 5; rating++) {
                final control = find
                    .ancestor(
                      of: find.byTooltip('Rate $rating out of 5 stars'),
                      matching: find.byType(IconButton),
                    )
                    .first;
                expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
                expect(
                  tester.getSize(control).height,
                  greaterThanOrEqualTo(48),
                );
              }
              await captureMarket(
                tester,
                '${dark ? 'dark' : 'light'}-${variant.$1}-rating',
                variant.$2,
              );
            } else {
              await Scrollable.ensureVisible(
                tester.element(find.byType(MarketplacePlaceCard).last),
                alignment: .2,
              );
              await tester.pumpAndSettle();
              if (variant.$1 == 'mobile') {
                await captureMarket(
                  tester,
                  '${dark ? 'dark' : 'light'}-mobile-last-place',
                  variant.$2,
                );
              }
            }
            expect(tester.takeException(), isNull);
            final semantics = tester.ensureSemantics();
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            semantics.dispose();
            await tester.pumpWidget(const SizedBox.shrink());
            debugDisableShadows = true;
          },
        );
      }
    }
  }
}

import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/onboarding/widgets/animated_tool_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);
  testWidgets('Notes, Schedule, GPA rotate continuously across the loop seam', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(
          body: Center(child: AnimatedToolCards(width: 380)),
        ),
      ),
    );
    await tester.pump();
    Finder tile(String name, int slot) =>
        find.byKey(ValueKey('tool-$name-$slot'));
    final center = tester.getCenter(tile('Notes', 0));
    expect(
      tester.getRect(tile('Notes', 0)).width,
      greaterThan(tester.getRect(tile('Schedule', -1)).width),
    );
    await tester.pump(const Duration(milliseconds: 2400));
    expect(tester.getCenter(tile('Schedule', -1)).dx, closeTo(center.dx, .01));
    await tester.pump(const Duration(milliseconds: 2400));
    expect(tester.getCenter(tile('GPA', -2)).dx, closeTo(center.dx, .01));
    await tester.pump(const Duration(milliseconds: 2399));
    final beforeSeam = tester.getCenter(tile('Notes', -3));
    await tester.pump(const Duration(milliseconds: 2));
    final afterSeam = tester.getCenter(tile('Notes', 0));
    expect((beforeSeam - afterSeam).distance, lessThan(.05));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tool motion pauses offscreen and stops for reduced motion', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, value, child) =>
              TickerMode(enabled: value, child: child!),
          child: const Center(child: AnimatedToolCards(width: 380)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    visible.value = false;
    await tester.pump();
    final card = find.byKey(const ValueKey('tool-Notes-0'));
    final paused = tester.getCenter(card);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.getCenter(card), paused);
    visible.value = true;
    await tester.pump();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pump();
    final reduced = tester.getCenter(card);
    await tester.pump(const Duration(seconds: 8));
    expect(tester.getCenter(card), reduced);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

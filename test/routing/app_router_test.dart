import 'package:balamandian/app.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Home and theme load, and navigation survives an app rebuild', (
    tester,
  ) async {
    const channel = MethodChannel('balamandian/splash');
    final splashCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      splashCalls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final appKey = GlobalKey();
    await tester.pumpWidget(
      MainApp(key: appKey, initialLocation: '/', themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final home = find.byType(HomeScreen);
    expect(home, findsOneWidget);
    expect(splashCalls, ['reveal']);
    expect(find.text('Community feed coming soon'), findsOneWidget);
    expect(Theme.of(tester.element(home)).colorScheme, appTheme.colorScheme);

    final router = GoRouter.of(tester.element(home));
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.canPop(), isFalse);

    router.go('/?source=route-check');
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MainApp(key: appKey, initialLocation: '/', themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    expect(home, findsOneWidget);
    expect(GoRouter.of(tester.element(home)), same(router));
    expect(
      router.routeInformationProvider.value.uri.query,
      'source=route-check',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

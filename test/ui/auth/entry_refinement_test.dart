import 'package:balamandian/ui/auth/widgets/getting_started_screen.dart';
import 'package:balamandian/ui/core/themes/startup_tokens.dart';
import 'package:balamandian/ui/core/ui/asset_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'Entry uses the ${dark ? 'navy' : 'light'} theme and has no back control',
      (tester) async {
        await pumpStartup(tester, screen: 'getting-started', dark: dark);
        final context = tester.element(find.byType(GettingStartedScreen));
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          dark
              ? StartupTokens.navy
              : Theme.of(context).colorScheme.primaryContainer,
        );
        expect(find.byType(AppIconButton), findsNothing);
        await tester.tap(find.text('Log in with SIS'));
        await advanceTransition(tester);
        final back = tester.widget<AppIconButton>(
          find.ancestor(
            of: find.byTooltip('Back'),
            matching: find.byType(AppIconButton),
          ),
        );
        expect(back.outlined, isFalse);
        await tester.tap(find.byTooltip('Back'));
        await advanceTransition(tester);
        expect(find.text('Log in with SIS'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

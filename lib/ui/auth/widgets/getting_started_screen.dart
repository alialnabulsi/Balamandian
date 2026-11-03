import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/action_button.dart';
import '../../core/ui/asset_icon.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/crest_coin.dart';
import '../../core/ui/decorative_art.dart';
import '../../onboarding/widgets/startup_flow.dart';
import '../view_models/auth_ui_controller.dart';

class GettingStartedScreen extends StatelessWidget {
  const GettingStartedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final nav = StartupNavigation.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = StartupPalette.of(context);
    final canvas = dark ? StartupTokens.navy : scheme.primaryContainer;
    final foreground = dark ? Colors.white : scheme.onSurface;
    final muted = dark ? const Color(0xffa4b0c0) : palette.muted;
    final signupColor = dark ? StartupTokens.entryLink : palette.success;
    final guestColor = dark ? const Color(0xfff1f5fa) : scheme.primary;
    return Scaffold(
      backgroundColor: canvas,
      body: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight, w = box.maxWidth;
          final safe = MediaQuery.paddingOf(context);
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: h * .44,
                child: Image.asset(
                  StartupAssets.image('onboarding-library-evening'),
                  fit: BoxFit.cover,
                  alignment: const Alignment(.1, 0),
                  excludeFromSemantics: true,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        canvas.withValues(alpha: .03),
                        canvas.withValues(alpha: .91),
                        canvas,
                        dark ? canvas : palette.canvas,
                      ],
                      stops: const [.24, .29, .40, .47, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -34,
                bottom: 178,
                child: DecorativeArt.olive(
                  width: 235,
                  height: 144,
                  color: dark ? const Color(0xff0d3555) : scheme.primary,
                  opacity: dark ? .68 : .10,
                  rotation: 23,
                ),
              ),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        26,
                        math.max(14, safe.top),
                        26,
                        math.max(36, safe.bottom + 24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),
                          SizedBox(
                            height: math.max(
                              0,
                              h * (h <= 700 ? .31 : .33) - 62,
                            ),
                          ),
                          Center(
                            child: CrestCoin(
                              size: h <= 700 ? 88 : (w * .28).clamp(96, 120),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'UNIVERSITY OF BALAMAND',
                            textAlign: TextAlign.center,
                            style: StartupTokens.text(
                              9,
                              16,
                              color: dark
                                  ? const Color(0xff9fc4df)
                                  : scheme.primary,
                              weight: FontWeight.w600,
                              spacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            header: true,
                            namesRoute: true,
                            child: Text(
                              'Balamandian',
                              textAlign: TextAlign.center,
                              style: StartupTokens.text(
                                (w * .089).clamp(32, 38),
                                (w * .089).clamp(32, 38) * 1.18,
                                weight: FontWeight.w700,
                                color: foreground,
                                spacing: -.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your campus. Your people.\nYour place.',
                            textAlign: TextAlign.center,
                            style: StartupTokens.text(
                              (w * .048).clamp(17, 20),
                              (w * .048).clamp(17, 20) * 1.35,
                              color: guestColor,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: h <= 700 ? 24 : 32),
                          ActionButton(
                            label: 'Log in with SIS',
                            icon: null,
                            radius: 8,
                            minHeight: 48,
                            bold: true,
                            background: dark
                                ? StartupTokens.yellow
                                : scheme.primary,
                            foreground: dark
                                ? const Color(0xff071f33)
                                : scheme.onPrimary,
                            onPressed: nav.busy
                                ? null
                                : () => nav.navigate(StartupDestination.signIn),
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            children: [
                              Text(
                                'New here?',
                                style: StartupTokens.text(14, 20, color: muted),
                              ),
                              TextButton(
                                onPressed: nav.busy
                                    ? null
                                    : () => nav.navigate(
                                        StartupDestination.signUp,
                                      ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: signupColor,
                                ),
                                child: Text(
                                  'Sign up with SIS',
                                  style:
                                      StartupTokens.text(
                                        14,
                                        20,
                                        weight: FontWeight.w600,
                                        color: signupColor,
                                      ).copyWith(
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: nav.busy
                                ? null
                                : () => AuthUiScope.of(context).requestGuest(),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Continue as guest',
                                  style: StartupTokens.text(
                                    14,
                                    20,
                                    weight: FontWeight.w500,
                                    color: guestColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AssetIcon(
                                  'arrow-right',
                                  size: 20,
                                  color: guestColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
    return Scaffold(
      backgroundColor: StartupTokens.navy,
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
                      colors: const [
                        Colors.transparent,
                        Color(0x08031d32),
                        Color(0xe8031d32),
                        StartupTokens.navy,
                        StartupTokens.navy,
                      ],
                      stops: const [.24, .29, .40, .47, 1],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: -34,
                bottom: 178,
                child: DecorativeArt.olive(
                  width: 235,
                  height: 144,
                  color: Color(0xff0d3555),
                  opacity: .68,
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
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppIconButton(
                              icon: 'arrow-left',
                              label: 'Back to welcome tour',
                              color: const Color(0xff061e32),
                              onPressed: nav.busy ? null : nav.back,
                            ),
                          ),
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
                              color: const Color(0xff9fc4df),
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
                                color: Colors.white,
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
                              color: const Color(0xfff1f5fa),
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
                            background: StartupTokens.yellow,
                            foreground: const Color(0xff071f33),
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
                                style: StartupTokens.text(
                                  14,
                                  20,
                                  color: const Color(0xffa4b0c0),
                                ),
                              ),
                              TextButton(
                                onPressed: nav.busy
                                    ? null
                                    : () => nav.navigate(
                                        StartupDestination.signUp,
                                      ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: StartupTokens.entryLink,
                                ),
                                child: Text(
                                  'Sign up with SIS',
                                  style:
                                      StartupTokens.text(
                                        14,
                                        20,
                                        weight: FontWeight.w600,
                                        color: StartupTokens.entryLink,
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
                                    color: const Color(0xfff1f5fa),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const AssetIcon(
                                  'arrow-right',
                                  size: 20,
                                  color: Color(0xfff1f5fa),
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import 'access_heading.dart';
import '../../onboarding/widgets/startup_flow.dart';

class AccessFrame extends StatelessWidget {
  const AccessFrame({
    super.key,
    required this.title,
    this.description,
    required this.label,
    required this.child,
    this.step,
    this.onBack,
    this.expandChild = true,
  });
  final String title, label;
  final String? description;
  final int? step;
  final Widget child;
  final VoidCallback? onBack;
  final bool expandChild;
  @override
  Widget build(BuildContext context) {
    final nav = StartupNavigation.of(context),
        palette = StartupPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, box) {
          final safe = MediaQuery.paddingOf(context);
          final w = box.maxWidth, h = box.maxHeight;
          // Use the full display height for responsive type even while a keyboard is open.
          final short = MediaQuery.sizeOf(context).height <= 780;
          final gutter = StartupTokens.gutter(w);
          final content = Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              math.max(18, safe.top),
              gutter,
              math.max(24, safe.bottom + 18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppIconButton(
                      icon: 'arrow-left',
                      label: 'Back',
                      onPressed: nav.busy ? null : onBack ?? nav.back,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: StartupTokens.text(
                          12,
                          20,
                          weight: FontWeight.w500,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                if (step != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Semantics(
                      label: 'Account setup: step $step of 2',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xffb98b20),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              color: step == 2
                                  ? const Color(0xffb98b20)
                                  : Theme.of(context).colorScheme.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AccessHeading(
                  title: title,
                  description: description,
                  setup: step == 2,
                  short: short,
                  narrow: w <= 360,
                ),
                if (expandChild) Expanded(child: child) else child,
              ],
            ),
          );
          return AppBrandedBackground(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: expandChild
                  ? ConstrainedBox(
                      constraints: BoxConstraints(minHeight: h),
                      child: IntrinsicHeight(child: content),
                    )
                  : content,
            ),
          );
        },
      ),
    );
  }
}

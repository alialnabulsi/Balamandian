import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/themes/startup_tokens.dart';
import '../view_models/app_entry_view_model.dart';
import 'splash_screen.dart';
import 'startup_frame.dart';

/// Retains the router, branch navigators, forms and dialogs during re-entry.
class AppEntryOverlay extends StatefulWidget {
  const AppEntryOverlay({super.key, required this.model, required this.child});
  final AppEntryViewModel model;
  final Widget child;

  @override
  State<AppEntryOverlay> createState() => _AppEntryOverlayState();
}

class _AppEntryOverlayState extends State<AppEntryOverlay> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: widget.model.backgrounded,
      onResume: widget.model.resumed,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) => ColoredBox(
      color: StartupTokens.blue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: widget.model.reentering,
            child: TickerMode(
              enabled: !widget.model.reentering,
              child: ExcludeFocus(
                excluding: widget.model.reentering,
                child: widget.child,
              ),
            ),
          ),
          if (widget.model.reentering)
            PopScope(
              canPop: false,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: StartupFrame(
                  splash: true,
                  child: SplashScreen(
                    key: ValueKey(widget.model.reentryId),
                    hold: true,
                    nativeHandoff: false,
                    onAnimationCompleted: widget.model.completeReentry,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

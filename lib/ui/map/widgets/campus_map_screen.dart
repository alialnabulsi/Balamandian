import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../mapbox/campus_map_configuration.dart';
import '../mapbox/mapbox_campus_surface.dart';
import '../view_models/campus_map_view_model.dart';
import 'campus_map_frame.dart';
import 'campus_map_loading.dart';

export 'campus_map_frame.dart' show CampusSurfaceBuilder;

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key, required this.model, this.surfaceBuilder});
  final CampusMapViewModel model;
  final CampusSurfaceBuilder? surfaceBuilder;
  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  late final AppLifecycleListener _lifecycle;
  bool? _visible;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          widget.model.foreground(state == AppLifecycleState.resumed),
    );
    unawaited(widget.model.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible != visible) {
      _visible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.model.visibility(_visible!);
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.model.visibility(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      final native =
          CampusMapConfiguration.configured &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      return PopScope(
        canPop: !keyboard && model.mode == CampusMapMode.explore,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (keyboard) {
            FocusManager.instance.primaryFocus?.unfocus();
          } else {
            model.closeContext();
          }
        },
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: model.data == null
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: model.error == null
                          ? const CampusMapLoading(label: 'Loading campus data')
                          : ContentState(
                              title: 'Campus data unavailable',
                              message: model.error!,
                              onRetry: model.load,
                            ),
                    ),
                  ),
                )
              : CampusMapFrame(
                  model: model,
                  surfaceBuilder:
                      widget.surfaceBuilder ??
                      (context, top, bottom) => native
                          ? MapboxCampusSurface(
                              model: model,
                              topPadding: top,
                              bottomPadding: bottom,
                            )
                          : const Center(
                              child: ContentState(
                                compact: true,
                                title: 'Map unavailable in this build',
                                message: 'You can still browse campus places.',
                                icon: Icons.map_outlined,
                              ),
                            ),
                ),
        ),
      );
    },
  );
}

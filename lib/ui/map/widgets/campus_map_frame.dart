import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/campus/navigation_fix.dart';
import '../../core/ui/measure_size.dart';
import '../../core/ui/navigation/bottom_chrome_scope.dart';
import '../view_models/campus_map_view_model.dart';
import 'campus_map_header.dart';
import 'campus_map_controls.dart';
import 'campus_search_results.dart';
import 'campus_context_panel.dart';
import 'campus_map_notice.dart';

typedef CampusSurfaceBuilder = Widget Function(
  BuildContext context,
  double topPadding,
  double bottomPadding,
);

/// Owns measured overlay geometry; layout changes never issue camera commands.
class CampusMapFrame extends StatefulWidget {
  const CampusMapFrame({
    super.key,
    required this.model,
    required this.surfaceBuilder,
  });
  final CampusMapViewModel model;
  final CampusSurfaceBuilder surfaceBuilder;
  @override
  State<CampusMapFrame> createState() => _CampusMapFrameState();
}

class _CampusMapFrameState extends State<CampusMapFrame> {
  double _header = 52, _sheet = 88, _notice = 64, _controls = 212;
  double _controlWidth = 52;
  int? _scheduledCamera;

  void _frameAfterLayout() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
    final revision = widget.model.cameraRequest?.revision;
    if (revision == null ||
        revision == _scheduledCamera ||
        !widget.model.mapAttached) {
      return;
    }
    _scheduledCamera = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.model.frameCamera(revision));
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final search = model.searchSnapshot;
    _frameAfterLayout();
    final media = MediaQuery.of(context);
    final chrome = BottomChromeScope.of(context);
    final keyboard = math.max(0.0, media.viewInsets.bottom - chrome);
    final bottom = math.max(
      keyboard,
      chrome == 0 ? media.viewPadding.bottom : 0.0,
    );
    final top = media.viewPadding.top + 8;
    final hasSheet =
        !model.searching &&
        (model.mode != CampusMapMode.explore || !model.campusSheetDismissed);
    final sheet = hasSheet ? _sheet : 0.0;
    final notice =
        model.mapError != null ||
        (!model.simulated &&
            model.locationAccess != LocationAccess.idle &&
            model.locationAccess != LocationAccess.ready);
    final noticeHeight = notice && !model.searching ? _notice : 0.0;
    return LayoutBuilder(
      builder: (context, box) {
        final panelTop = top + _header + 12;
        final controlsTop = top + _header + 12;
        final clearHeight =
            box.maxHeight -
            bottom -
            sheet -
            40 -
            (noticeHeight > 0 ? noticeHeight + 36 : 0) -
            controlsTop;
        final cameraBottom = math
            .min(
              box.maxHeight - panelTop - 40,
              bottom + sheet + noticeHeight + 48,
            )
            .clamp(0.0, double.infinity);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            model.viewport(
              top: panelTop + 12,
              right: !model.searching && clearHeight >= _controls
                  ? _controlWidth + 32
                  : 24,
              bottom: cameraBottom,
              legalBottom:
                  bottom +
                  sheet +
                  (noticeHeight > 0 ? noticeHeight + 36 : 0) +
                  8,
            );
          }
        });
        return Stack(
          children: [
            Positioned.fill(
              key: const ValueKey('campus-native-surface'),
              child: widget.surfaceBuilder(
                context,
                panelTop + 12,
                math
                    .min(
                      box.maxHeight - panelTop - 40,
                      bottom + sheet + noticeHeight + 48,
                    )
                    .clamp(0.0, double.infinity),
              ),
            ),
            Positioned(
              key: const ValueKey('campus-floating-header'),
              top: top,
              left: 16,
              right: 16,
              child: MeasureSize(
                onChange: (size) {
                  if (mounted && _header != size.height) {
                    setState(() => _header = size.height);
                  }
                },
                child: CampusMapHeader(model: model),
              ),
            ),
            if (!model.searching && clearHeight >= _controls)
              Positioned(
                key: const ValueKey('campus-floating-controls'),
                top: controlsTop,
                right: 16,
                child: MeasureSize(
                  onChange: (size) {
                    if (mounted &&
                        (_controls != size.height ||
                            _controlWidth != size.width)) {
                      setState(() {
                        _controls = size.height;
                        _controlWidth = size.width;
                      });
                    }
                  },
                  child: CampusMapControls(
                    threeDimensional: model.threeDimensional,
                    bearing: model.cameraBearing,
                    onNorth: model.north,
                    onOverview: model.overview,
                    onLocate: model.recenter,
                    onPerspective: model.togglePerspective,
                  ),
                ),
              ),
            if (model.searching)
              Positioned(
                key: const ValueKey('campus-search-results'),
                top: panelTop,
                left: 16,
                right: 16,
                bottom: bottom + 44,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CampusSearchResults(
                    results: search.places,
                    loading: search.loading,
                    error: search.error,
                    onRetry: model.retrySearch,
                    onSelected: (destination) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      unawaited(model.select(destination));
                    },
                  ),
                ),
              ),
            if (hasSheet)
              Positioned(
                key: const ValueKey('campus-context-panel'),
                top: panelTop + 40 + (notice ? noticeHeight + 36 : 0),
                bottom: bottom,
                left: 0,
                right: 0,
                child: CampusContextPanel(
                  model: model,
                  onHeight: (height) {
                    if (mounted && (_sheet - height).abs() > .5) {
                      setState(() => _sheet = height);
                    }
                  },
                ),
              ),
            if (notice && !model.searching)
              Positioned(
                key: const ValueKey('campus-feedback'),
                left: 16,
                right: 16,
                bottom: bottom + sheet + 36,
                child: MeasureSize(
                  onChange: (size) {
                    if (mounted && _notice != size.height) {
                      setState(() => _notice = size.height);
                    }
                  },
                  child: CampusMapNotice(model: model),
                ),
              ),
          ],
        );
      },
    );
  }
}

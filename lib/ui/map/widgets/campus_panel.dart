import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';
import '../../core/ui/buttons/app_icon_button.dart';
import '../../core/ui/measure_size.dart';

/// One scrollable coordinates sheet dragging and expanded content scrolling.
class CampusPanel extends StatefulWidget {
  const CampusPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onClose,
    required this.onHeight,
    this.collapsed = false,
    this.footer,
  });
  final String title, subtitle;
  final Widget child;
  final VoidCallback onClose;
  final ValueChanged<double> onHeight;
  final bool collapsed;
  final Widget? footer;

  @override
  State<CampusPanel> createState() => _CampusPanelState();
}

class _CampusPanelState extends State<CampusPanel> {
  final _controller = DraggableScrollableController();
  final _contentRevision = ValueNotifier<int>(0);
  (double, double, double, double, bool)? _geometry;
  Widget? _sheetWidget;
  double _header = 88, _content = 360;
  double _footer = 0;

  @override
  void didUpdateWidget(covariant CampusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _contentRevision.value++;
  }

  @override
  void dispose() {
    _controller.dispose();
    _contentRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final available = math.max(1.0, box.maxHeight);
      final min = math.min(_header + _footer, available) / available;
      final max = math.max(
        min,
        math.min(_content + _footer, available) / available,
      );
      final middle = (math.min(_content + _footer, available * .56) / available)
          .clamp(min, max);
      final initial = widget.collapsed ? min : middle;
      final geometry = (
        min,
        max,
        middle,
        initial,
        MediaQuery.disableAnimationsOf(context),
      );
      if (_geometry == geometry && _sheetWidget != null) return _sheetWidget!;
      _geometry = geometry;
      // Keep geometry and snap stops stable while the parent measures each
      // frame. Content updates rebuild inside the existing draggable extent.
      return _sheetWidget = DraggableScrollableSheet(
        controller: _controller,
        minChildSize: min,
        maxChildSize: max,
        initialChildSize: initial,
        snap: !MediaQuery.disableAnimationsOf(context),
        snapSizes: middle > min && middle < max ? [middle] : null,
        snapAnimationDuration: AppTokens.transition,
        builder: (context, scroll) => ListenableBuilder(
          listenable: _contentRevision,
          builder: (context, _) => MeasureSize(
            onChange: (size) => widget.onHeight(size.height),
            child: Material(
              elevation: 5,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.surfaceRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, sheetBox) => Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: MeasureSize(
                          onChange: (size) {
                            if (mounted &&
                                (_content - size.height).abs() > .5) {
                              setState(() => _content = size.height);
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MeasureSize(
                                onChange: (size) {
                                  if (mounted &&
                                      (_header - size.height).abs() > .5) {
                                    setState(() => _header = size.height);
                                  }
                                },
                                child: CampusPanelHeader(
                                  title: widget.title,
                                  subtitle: widget.subtitle,
                                  onClose: widget.onClose,
                                  controller: _controller,
                                  minimum: min,
                                  maximum: max,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  24,
                                ),
                                child: widget.child,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.footer case final footer?)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.min(
                            available * .55,
                            sheetBox.maxHeight,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: MeasureSize(
                            onChange: (size) {
                              if (mounted &&
                                  (_footer - size.height).abs() > .5) {
                                setState(
                                  () => _footer = size.height.clamp(
                                    0,
                                    available * .55,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: footer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class CampusPanelHeader extends StatelessWidget {
  const CampusPanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.controller,
    required this.minimum,
    required this.maximum,
  });
  final String title, subtitle;
  final VoidCallback onClose;
  final DraggableScrollableController controller;
  final double minimum, maximum;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final expanded =
                    controller.isAttached &&
                    controller.size >= maximum - .02 &&
                    maximum > minimum;
                return AppIconButton(
                  tooltip: expanded ? 'Collapse map panel' : 'Expand map panel',
                  icon: expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  onPressed: () {
                    if (!controller.isAttached) return;
                    final target = expanded ? minimum : maximum;
                    if (MediaQuery.disableAnimationsOf(context)) {
                      controller.jumpTo(target);
                    } else {
                      controller.animateTo(
                        target,
                        duration: AppTokens.sheet,
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                );
              },
            ),
            AppIconButton(
              tooltip: 'Close map panel',
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
          ],
        ),
      ],
    ),
  );
}

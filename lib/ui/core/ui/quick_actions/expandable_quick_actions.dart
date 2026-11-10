import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/shell_tokens.dart';
import 'app_quick_action.dart';

@immutable
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Three configurable actions: upper-left, upper-right, then lower-left.
/// A native popup route supplies barrier dismissal, focus and Android back.
class ExpandableQuickActions extends StatefulWidget {
  const ExpandableQuickActions({
    super.key,
    required this.actions,
    this.navigationId,
    this.tooltip = 'Open quick actions',
    this.icon = Icons.auto_awesome_outlined,
  }) : assert(actions.length == 3);

  final List<QuickAction> actions;
  final Object? navigationId;
  final String tooltip;
  final IconData icon;

  @override
  State<ExpandableQuickActions> createState() => _ExpandableQuickActionsState();
}

class _ExpandableQuickActionsState extends State<ExpandableQuickActions> {
  final _anchorKey = GlobalKey();
  RawDialogRoute<QuickAction>? _route;
  NavigatorState? _navigator;
  bool _open = false;

  Future<void> _expand() async {
    if (_route != null) return;
    final anchor = _anchorKey.currentContext!.findRenderObject()! as RenderBox;
    final screen = MediaQuery.sizeOf(context);
    final center = anchor.localToGlobal(anchor.size.center(Offset.zero));
    final insets = Offset(screen.width - center.dx, screen.height - center.dy);
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = RawDialogRoute<QuickAction>(
      settings: const RouteSettings(name: 'quick-actions'),
      barrierDismissible: true,
      barrierLabel: 'Close quick actions',
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .12),
      transitionDuration: reduced ? Duration.zero : ShellTokens.menuDuration,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      pageBuilder: (context, animation, secondary) => _QuickActionsFan(
        actions: widget.actions,
        insets: insets,
        animation: animation,
        onClose: () => navigator.pop(),
        onSelect: (action) => navigator.pop(action),
      ),
      // Each fan action animates independently rather than fading the whole page.
      transitionBuilder: (context, animation, secondary, child) => child,
    );
    _navigator = navigator;
    _route = route;
    setState(() => _open = true);
    final selected = await navigator.push(route);
    if (mounted) setState(() => _open = false);
    // Let the fan finish collapsing before changing destinations.
    await route.completed;
    if (_route == route) _route = null;
    if (mounted) selected?.onSelected();
  }

  void _dismissAfterFrame() {
    final route = _route;
    final navigator = _navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null && route.isActive && navigator?.mounted == true) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ExpandableQuickActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationId != widget.navigationId) _dismissAfterFrame();
  }

  @override
  void dispose() {
    _dismissAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: _open,
    child: IgnorePointer(
      ignoring: _open,
      child: Opacity(
        opacity: _open ? 0 : 1,
        child: AppQuickAction(
          key: _anchorKey,
          icon: widget.icon,
          tooltip: widget.tooltip,
          onPressed: _expand,
          diameter: ShellTokens.actionSize,
          primary: true,
        ),
      ),
    ),
  );
}

class _QuickActionsFan extends StatelessWidget {
  const _QuickActionsFan({
    required this.actions,
    required this.insets,
    required this.animation,
    required this.onClose,
    required this.onSelect,
  });

  final List<QuickAction> actions;
  final Offset insets;
  final Animation<double> animation;
  final VoidCallback onClose;
  final ValueChanged<QuickAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Quick actions',
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safe = Rect.fromLTRB(
            padding.left + 12,
            padding.top + 12,
            constraints.maxWidth - padding.right - 12,
            constraints.maxHeight -
                math.max(
                  padding.bottom,
                  MediaQuery.viewInsetsOf(context).bottom,
                ) -
                12,
          );
          final desiredSize = math.max(
            72.0,
            48 + MediaQuery.textScalerOf(context).scale(16),
          );
          final diameter = math.min(
            desiredSize,
            math.min((safe.width - 12) / 2, (safe.height - 12) / 2),
          );
          final step = diameter + 12;
          final half = diameter / 2;
          final origin = Offset(
            (constraints.maxWidth - insets.dx).clamp(
              safe.left + step + half,
              safe.right - half,
            ),
            (constraints.maxHeight - insets.dy).clamp(
              safe.top + step + half,
              safe.bottom - half,
            ),
          );
          final offsets = [
            Offset(-step, -step),
            Offset(0, -step),
            Offset(-step, 0),
          ];
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Stack(
              children: [
                for (var index = 0; index < actions.length; index++)
                  Positioned(
                    left: origin.dx - half,
                    top: origin.dy - half,
                    child: _AnimatedQuickAction(
                      animation: animation,
                      index: index,
                      offset: offsets[index],
                      child: AppQuickAction(
                        tooltip: actions[index].label,
                        label: actions[index].label,
                        icon: actions[index].icon,
                        diameter: diameter,
                        onPressed: () => onSelect(actions[index]),
                      ),
                    ),
                  ),
                Positioned(
                  left: origin.dx - ShellTokens.actionSize / 2,
                  top: origin.dy - ShellTokens.actionSize / 2,
                  child: AppQuickAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Close quick actions',
                    onPressed: onClose,
                    primary: true,
                    autofocus: true,
                    diameter: ShellTokens.actionSize,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedQuickAction extends StatelessWidget {
  const _AnimatedQuickAction({
    required this.animation,
    required this.index,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = Interval(
      index * .08,
      .84 + index * .08,
      curve: Curves.easeOutCubic,
    ).transform(animation.value);
    return Transform.translate(
      offset: offset * progress,
      child: ExcludeSemantics(
        excluding: progress < .95,
        child: IgnorePointer(
          ignoring:
              progress < .95 || animation.status == AnimationStatus.reverse,
          child: Opacity(
            opacity: progress,
            child: Transform.scale(scale: .65 + .35 * progress, child: child),
          ),
        ),
      ),
    );
  }
}

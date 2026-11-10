import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../routing/shell_destination.dart';
import '../../themes/shell_tokens.dart';
import 'app_navigation_item.dart';

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCreate,
    this.destinations = ShellDestination.tabs,
  });

  final ShellDestination selected;
  final List<ShellDestination> destinations;
  final ValueChanged<ShellDestination> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BottomAppBar(
      height: math.max(
        ShellTokens.bottomBarHeight,
        60 + MediaQuery.textScalerOf(context).scale(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var index = 0; index <= destinations.length; index++) ...[
            if (index == destinations.length ~/ 2)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton.filled(
                      tooltip: 'Create',
                      onPressed: onCreate,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(ShellTokens.actionSize),
                        backgroundColor: scheme.tertiary,
                        foregroundColor: scheme.onTertiary,
                        side: BorderSide(color: scheme.surface, width: 3),
                        elevation: 2,
                        shadowColor: scheme.shadow.withValues(alpha: .15),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 30),
                    ),
                  ),
                ),
              ),
            if (index < destinations.length)
              Expanded(
                child: AppNavigationItem(
                  label: destinations[index].label,
                  icon: selected == destinations[index]
                      ? destinations[index].selectedIcon
                      : destinations[index].icon,
                  selected: selected == destinations[index],
                  onPressed: () => onSelected(destinations[index]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

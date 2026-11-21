import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/app_surface.dart';
import '../../core/ui/buttons/app_icon_button.dart';

class CampusMapControls extends StatelessWidget {
  const CampusMapControls({
    super.key,
    required this.threeDimensional,
    required this.onNorth,
    required this.onOverview,
    required this.onLocate,
    required this.onPerspective,
    this.bearing = 0,
  });
  final bool threeDimensional;
  final double bearing;
  final VoidCallback onNorth, onOverview, onLocate, onPerspective;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppSurface(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              tooltip: 'Reset north',
              onPressed: onNorth,
              child: Transform.rotate(
                angle: -bearing * math.pi / 180,
                child: const Icon(Icons.navigation_outlined),
              ),
            ),
            AppIconButton(
              tooltip: threeDimensional ? 'Switch to 2D' : 'Switch to 3D',
              onPressed: onPerspective,
              child: Text(
                threeDimensional ? '2D' : '3D',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      AppSurface(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              tooltip: 'Recenter on my location',
              icon: Icons.my_location,
              onPressed: onLocate,
            ),
            AppIconButton(
              tooltip: 'Campus overview',
              icon: Icons.school_outlined,
              onPressed: onOverview,
            ),
          ],
        ),
      ),
    ],
  );
}

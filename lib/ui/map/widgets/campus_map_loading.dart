import 'package:flutter/material.dart';

import '../../core/ui/app_surface.dart';
import '../../core/ui/loading/skeleton.dart';

class CampusMapLoading extends StatelessWidget {
  const CampusMapLoading({super.key, this.label = 'Loading campus map'});
  final String label;
  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(12),
    child: SkeletonGroup(
      label: label,
      child: const Row(
        children: [
          SkeletonBox(width: 24, height: 24),
          SizedBox(width: 12),
          Expanded(child: SkeletonText()),
        ],
      ),
    ),
  );
}

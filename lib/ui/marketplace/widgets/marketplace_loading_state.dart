import 'package:flutter/material.dart';

import '../../core/ui/loading/delayed_loading.dart';
import '../../core/ui/loading/skeleton.dart';

class MarketplaceLoadingState extends StatelessWidget {
  const MarketplaceLoadingState({super.key});
  @override
  Widget build(BuildContext context) => const DelayedLoading(
    height: 480,
    child: SkeletonGroup(
      label: 'Loading marketplace',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonText(width: 160, height: 20),
            SizedBox(height: 16),
            SkeletonImage(),
            SizedBox(height: 16),
            SkeletonText(width: 200),
            SizedBox(height: 10),
            SkeletonText(width: 120),
            SizedBox(height: 24),
            SkeletonImage(),
          ],
        ),
      ),
    ),
  );
}

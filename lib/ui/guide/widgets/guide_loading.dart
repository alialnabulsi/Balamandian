import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';
import '../../core/ui/loading/skeleton.dart';

class GuideLoading extends StatelessWidget {
  const GuideLoading({super.key});
  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    label: 'Loading University Guide',
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: AppTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 210, height: 24),
          SizedBox(height: 24),
          SkeletonBox(height: 96),
          SizedBox(height: 16),
          SkeletonBox(height: 96),
          SizedBox(height: 16),
          SkeletonBox(height: 96),
        ],
      ),
    ),
  );
}

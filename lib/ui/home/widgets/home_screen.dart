import 'package:flutter/material.dart';

import '../../core/ui/app_feature_placeholder.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBrandedBackground(
      child: AppFeaturePlaceholder(
        title: 'Community feed coming soon',
        description: 'A place for our campus community to connect.',
        icon: Icons.people_outline_rounded,
      ),
    );
  }
}

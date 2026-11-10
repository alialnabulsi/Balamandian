import 'package:flutter/material.dart';

import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/brand.dart';

/// Retry progress after entry has already played the full animated splash.
class SessionLoadingState extends StatelessWidget {
  const SessionLoadingState({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBrandedBackground(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BalamandianBrand(),
              const SizedBox(height: 32),
              CircularProgressIndicator(semanticsLabel: label),
              const SizedBox(height: 16),
              Text(label),
            ],
          ),
        ),
      ),
    ),
  );
}

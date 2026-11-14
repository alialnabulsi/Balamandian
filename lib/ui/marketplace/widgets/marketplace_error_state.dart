import 'package:flutter/material.dart';

import '../../core/ui/form_message.dart';

class MarketplaceErrorState extends StatelessWidget {
  const MarketplaceErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormMessage(message),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry marketplace'),
          ),
        ),
      ],
    ),
  );
}

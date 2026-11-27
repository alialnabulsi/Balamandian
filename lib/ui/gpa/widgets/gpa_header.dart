import 'package:flutter/material.dart';

class GpaHeader extends StatelessWidget {
  const GpaHeader({super.key, required this.onBack, this.onReset});
  final VoidCallback onBack;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Back to Tools',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      Expanded(
        child: Text(
          'GPA Calculator',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      IconButton(
        tooltip: 'Reset calculator',
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

class ReportChoiceButton extends StatelessWidget {
  const ReportChoiceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color color, foreground;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foreground,
      minimumSize: const Size.fromHeight(100),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 32),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: foreground),
          ),
        ),
        const SizedBox(width: 52),
      ],
    ),
  );
}

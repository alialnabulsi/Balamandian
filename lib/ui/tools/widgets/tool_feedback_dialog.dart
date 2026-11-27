import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';

class ToolFeedbackDialog extends StatelessWidget {
  const ToolFeedbackDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.onCalendar,
  });
  final String title, message;
  final IconData icon;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    content: ContentState(
      title: title,
      message: message,
      icon: icon,
      compact: true,
    ),
    actions: [
      if (onCalendar != null)
        TextButton(
          onPressed: onCalendar,
          child: const Text('View official academic calendar'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../view_models/tool_session.dart';

/// Hides private dialog content and closes this dialog plus nested pickers on a session change.
class ToolScopedDialog extends StatefulWidget {
  const ToolScopedDialog({
    super.key,
    required this.session,
    required this.child,
  });
  final ToolSession session;
  final Widget child;
  @override
  State<ToolScopedDialog> createState() => _ToolScopedDialogState();
}

class _ToolScopedDialogState extends State<ToolScopedDialog> {
  late final epoch = widget.session.epoch;
  bool hidden = false;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(sync);
  }

  void sync() {
    if (!mounted || epoch == widget.session.epoch || hidden) return;
    setState(() => hidden = true);
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route == null || !route.isActive) return;
      nav.popUntil((r) => r == route);
      if (route.isActive) nav.pop();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      hidden ? const SizedBox.shrink() : widget.child;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../themes/app_tokens.dart';

/// Delays presentation only: never delays a request or its completed content.
class DelayedLoading extends StatefulWidget {
  const DelayedLoading({super.key, required this.child, this.height = 280});
  final Widget child;
  final double height;
  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  Timer? _timer;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(AppTokens.loadingThreshold, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : SizedBox(height: widget.height);
}

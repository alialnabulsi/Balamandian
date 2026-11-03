import 'package:flutter/material.dart';

import '../themes/startup_tokens.dart';
import 'asset_icon.dart';

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = 'arrow-right',
    this.background,
    this.foreground,
    this.radius = 14,
    this.minHeight = 54,
    this.pending = false,
    this.bold = false,
  });
  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final Color? background, foreground;
  final double radius, minHeight;
  final bool pending, bold;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = widget.foreground ?? scheme.onPrimary;
    final enabled = widget.onPressed != null && !widget.pending;
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? .985 : 1,
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
        ),
        child: Opacity(
          opacity: enabled ? 1 : .75,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? widget.onPressed : null,
              style: FilledButton.styleFrom(
                minimumSize: Size(0, widget.minHeight),
                padding: EdgeInsets.symmetric(
                  vertical: widget.minHeight == 48 ? 12 : 14,
                  horizontal: 18,
                ),
                backgroundColor: widget.background ?? scheme.primary,
                foregroundColor: foreground,
                disabledBackgroundColor: widget.background ?? scheme.primary,
                disabledForegroundColor: foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
                elevation: widget.radius == 8 ? 0 : 4,
                shadowColor: StartupTokens.blue.withValues(alpha: .1),
                textStyle: StartupTokens.text(
                  widget.bold ? 16 : 15,
                  22,
                  weight: widget.bold ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        widget.pending ? 'Please wait…' : widget.label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (widget.pending)
                      Positioned(
                        right: 0,
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                      )
                    else if (widget.icon != null)
                      Positioned(
                        right: 0,
                        child: AssetIcon(widget.icon!, color: foreground),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

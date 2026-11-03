import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.icon,
    required this.label,
    required this.compact,
    required this.tiny,
    this.foreground,
    this.background,
  });
  final String icon, label;
  final bool compact, tiny;
  final Color? foreground, background;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: tiny
            ? 7
            : compact
            ? 9
            : 13,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a14263b),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AssetIcon(
              icon,
              size: 24,
              color: foreground ?? scheme.primary,
            ),
          ),
          SizedBox(height: compact ? 5 : 8),
          Text(
            label,
            style: StartupTokens.text(11, 16, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

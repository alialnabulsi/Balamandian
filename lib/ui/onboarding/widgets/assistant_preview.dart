import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';
import '../../core/ui/brand.dart';

class AssistantPreview extends StatelessWidget {
  const AssistantPreview({
    super.key,
    required this.compact,
    required this.tiny,
  });
  final bool compact, tiny;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        palette = StartupPalette.of(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: tiny
            ? 208
            : compact
            ? 228
            : 250,
      ),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 12 : 16,
        horizontal: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .13
                  : .05,
            ),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Campus Assistant',
            style: StartupTokens.text(
              compact ? 13 : 15,
              compact ? 18 : 22,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Your campus companion',
            style: StartupTokens.text(
              compact ? 10 : 11,
              compact ? 16 : 18,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'Explore campus services',
                  style: StartupTokens.text(
                    compact ? 11 : 12,
                    compact ? 17 : 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversityCrest(size: 25, decorative: true),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Find your next stop, explore campus services, or get ready for class.',
                    style: StartupTokens.text(
                      compact ? 11 : 12,
                      compact ? 17 : 19,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!tiny) ...[
            SizedBox(height: compact ? 12 : 16),
            Divider(height: 1, color: scheme.outline),
            SizedBox(height: compact ? 10 : 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ask your campus\nassistant',
                    style: StartupTokens.text(10, 17, color: scheme.primary),
                  ),
                ),
                AssetIcon('arrow-right', size: 18, color: scheme.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

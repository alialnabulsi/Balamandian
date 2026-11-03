import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';

class AssistantPreview extends StatelessWidget {
  static const financialAidReference =
      'https://www.balamand.edu.lb/FinancialAidApplication/';
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
      constraints: BoxConstraints(minHeight: compact ? 166 : 182),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
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
                  'Where can I apply for financial aid?',
                  style: StartupTokens.text(
                    compact ? 11 : 12,
                    compact ? 17 : 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversityCrest(size: 22, decorative: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You can apply online through the University's",
                        style: StartupTokens.text(
                          compact ? 11 : 12,
                          compact ? 17 : 19,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // A reference in a static assistant illustration, not a chat action.
                      Tooltip(
                        message: financialAidReference,
                        child: Text(
                          'Financial Aid Application.',
                          style: StartupTokens.text(
                            compact ? 11 : 12,
                            compact ? 16 : 18,
                            color: scheme.primary,
                            weight: FontWeight.w600,
                          ).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

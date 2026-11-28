import 'package:flutter/material.dart';

import '../../core/ui/brand.dart';
import 'ai_text_direction.dart';

const aiSuggestedQuestions = [
  'How do I request an official transcript?',
  'Can I renew a book from the library?',
  'وين فيني شوف الـ Academic Calendar؟',
];

class AiWelcome extends StatelessWidget {
  const AiWelcome({
    super.key,
    required this.onSuggestion,
    this.suggestions = aiSuggestedQuestions,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UniversityCrest(size: 50, decorative: true),
            const SizedBox(height: 16),
            Text(
              'What would you like to know?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ask about university services, the academic calendar, or campus resources. Answers can include official University of Balamand sources.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            for (final question in suggestions)
              _SuggestedQuestion(question, onTap: () => onSuggestion(question)),
          ],
        ),
      ),
    );
  }
}

class _SuggestedQuestion extends StatelessWidget {
  const _SuggestedQuestion(this.question, {required this.onTap});

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = aiTextDirection(question);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              textDirection: direction,
              spacing: 10,
              children: [
                Expanded(
                  child: Text(
                    question,
                    textDirection: direction,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Icon(
                  direction == TextDirection.rtl
                      ? Icons.north_west_rounded
                      : Icons.north_east_rounded,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

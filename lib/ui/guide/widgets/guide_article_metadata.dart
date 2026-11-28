import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';

class GuideArticleMetadata extends StatelessWidget {
  const GuideArticleMetadata({super.key, required this.article});
  final GuideArticle article;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          article.summary.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        article.summary.summary,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      Text(
        'Verified ${article.summary.verifiedOn}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      if (article.academicYear case final String year)
        Text('Academic year: $year'),
      if (article.validFrom case final DateTime date)
        Text('Applies from: ${date.toIso8601String()} (inclusive)'),
      if (article.validUntil case final DateTime date)
        Text('Applies until: ${date.toIso8601String()} (exclusive)'),
    ],
  );
}

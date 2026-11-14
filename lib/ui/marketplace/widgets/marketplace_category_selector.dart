import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_category.dart';
import 'marketplace_category_chip.dart';

class MarketplaceCategorySelector extends StatelessWidget {
  const MarketplaceCategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<MarketplaceCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketplaceCategoryChip(
          label: 'All places',
          iconKey: 'all',
          selected: selected == null,
          onPressed: () => onSelected(null),
        ),
        for (final category in categories)
          MarketplaceCategoryChip(
            label: category.name,
            iconKey: category.iconKey,
            selected: selected == category.slug,
            onPressed: () => onSelected(category.slug),
          ),
      ],
    ),
  );
}

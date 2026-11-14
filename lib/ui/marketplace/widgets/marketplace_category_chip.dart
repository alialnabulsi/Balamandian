import 'package:flutter/material.dart';

IconData marketplaceCategoryIcon(String key) => switch (key) {
  'coffee' => Icons.coffee_outlined,
  'restaurant' => Icons.restaurant_outlined,
  'books' => Icons.menu_book_outlined,
  _ => Icons.storefront_outlined,
};

class MarketplaceCategoryChip extends StatelessWidget {
  const MarketplaceCategoryChip({
    super.key,
    required this.label,
    required this.iconKey,
    required this.selected,
    required this.onPressed,
  });
  final String label, iconKey;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: MediaQuery.textScalerOf(context).scale(86).clamp(86, 150),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      marketplaceCategoryIcon(iconKey),
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

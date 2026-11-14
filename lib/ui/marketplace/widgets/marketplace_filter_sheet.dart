import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_category.dart';
import '../../core/ui/buttons/app_icon_button.dart';

class MarketplaceFilterSheet extends StatefulWidget {
  const MarketplaceFilterSheet({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<MarketplaceCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  State<MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<MarketplaceFilterSheet> {
  late String? _selected = widget.selected;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Find your kind of place',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              AppIconButton(
                tooltip: 'Close marketplace filters',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          RadioGroup<String>(
            groupValue: _selected ?? '',
            onChanged: (value) =>
                setState(() => _selected = value == '' ? null : value),
            child: Column(
              children: [
                const RadioListTile<String>(
                  value: '',
                  title: Text('All places'),
                ),
                for (final category in widget.categories)
                  RadioListTile<String>(
                    value: category.slug,
                    title: Text(category.name),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              widget.onSelected(_selected);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Show places'),
          ),
        ],
      ),
    ),
  );
}

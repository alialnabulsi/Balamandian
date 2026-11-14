import 'package:flutter/material.dart';

import '../../core/ui/buttons/app_icon_button.dart';

class MarketplaceSearchField extends StatelessWidget {
  const MarketplaceSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onFilter,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            onChanged: onChanged,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Search places',
              hintText: 'Coffee, food, books...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: value.text.isEmpty
                  ? null
                  : AppIconButton(
                      tooltip: 'Clear marketplace search',
                      icon: Icons.close_rounded,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      AppIconButton(
        tooltip: 'Filter marketplace categories',
        icon: Icons.filter_alt_outlined,
        onPressed: onFilter,
      ),
    ],
  );
}

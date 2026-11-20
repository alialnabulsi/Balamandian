import 'package:flutter/material.dart';

class MemberSearchField extends StatelessWidget {
  const MemberSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: 100,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search name or username',
        labelText: 'Search members',
        counterText: '',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Clear search',
          onPressed: () {
            controller.clear();
            onChanged('');
          },
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    ),
  );
}

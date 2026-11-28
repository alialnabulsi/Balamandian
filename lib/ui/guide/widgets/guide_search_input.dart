import 'package:flutter/material.dart';

class GuideSearchInput extends StatefulWidget {
  const GuideSearchInput({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  State<GuideSearchInput> createState() => _GuideSearchInputState();
}

class _GuideSearchInputState extends State<GuideSearchInput> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    autofocus: true,
    textInputAction: TextInputAction.search,
    maxLength: 500,
    decoration: InputDecoration(
      labelText: 'Search university information',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: IconButton(
        tooltip: 'Clear search',
        onPressed: () {
          _controller.clear();
          widget.onChanged('');
        },
        icon: const Icon(Icons.close_rounded),
      ),
    ),
    onChanged: widget.onChanged,
  );
}

import 'package:flutter/material.dart';

import '../../core/ui/app_surface.dart';
import '../../core/ui/buttons/app_icon_button.dart';

class CampusSearchBar extends StatefulWidget {
  const CampusSearchBar({
    super.key,
    required this.query,
    required this.searching,
    required this.onChanged,
    required this.onFocus,
    required this.onCancel,
  });
  final String query;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onFocus, onCancel;
  @override
  State<CampusSearchBar> createState() => _CampusSearchBarState();
}

class _CampusSearchBarState extends State<CampusSearchBar> {
  late final _text = TextEditingController(text: widget.query);
  final _focus = FocusNode();
  @override
  void didUpdateWidget(covariant CampusSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.query) _text.text = widget.query;
    if (!widget.searching) _focus.unfocus();
    if (widget.searching && !oldWidget.searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.searching) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      children: [
        AppIconButton(
          tooltip: widget.searching ? 'Cancel search' : 'Search campus',
          icon: widget.searching
              ? Icons.arrow_back_rounded
              : Icons.search_rounded,
          onPressed: widget.searching ? widget.onCancel : widget.onFocus,
        ),
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _focus,
            onTap: widget.onFocus,
            onChanged: widget.onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _focus.unfocus(),
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Search campus',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (widget.query.isNotEmpty)
          AppIconButton(
            tooltip: 'Clear search',
            icon: Icons.clear,
            onPressed: () => widget.onChanged(''),
          ),
        if (!widget.searching) const SizedBox(width: 12),
      ],
    ),
  );
}

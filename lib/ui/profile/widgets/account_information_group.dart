import 'package:flutter/material.dart';

class AccountInformationGroup extends StatelessWidget {
  const AccountInformationGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 24),
          children[i],
        ],
      ],
    ),
  );
}

class AccountInformationRow extends StatelessWidget {
  const AccountInformationRow({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final content = SelectableText(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, const SizedBox(height: 4), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 138, child: caption),
            const SizedBox(width: 16),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

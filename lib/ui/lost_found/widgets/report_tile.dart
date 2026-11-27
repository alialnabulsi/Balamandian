import 'package:flutter/material.dart';

import '../../../domain/models/lost_found_models.dart';

class ReportTile extends StatelessWidget {
  const ReportTile({
    super.key,
    required this.report,
    required this.onOpen,
    required this.onWithdraw,
    this.busy = false,
  });
  final LostFoundReport report;
  final VoidCallback onOpen, onWithdraw;
  final bool busy;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      isThreeLine: true,
      leading: Icon(
        report.type == 'found' ? Icons.inventory_2_outlined : Icons.search,
      ),
      title: Text(report.title),
      subtitle: Text(
        '${report.type.toUpperCase()} - ${report.statusLabel}\n${MaterialLocalizations.of(context).formatCompactDate(report.createdAt.toLocal())}',
      ),
      onTap: busy ? null : onOpen,
      trailing: report.active
          ? IconButton(
              tooltip: 'Withdraw report',
              onPressed: busy ? null : onWithdraw,
              icon: const Icon(Icons.undo),
            )
          : null,
    ),
  );
}

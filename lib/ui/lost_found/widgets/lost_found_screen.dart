import 'report_choice_button.dart';
import '../../core/themes/app_tokens.dart';
import '../../tools/widgets/tool_scoped_dialog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/lost_found_repository.dart';
import '../../../data/services/note_file_service.dart';
import '../../tools/view_models/tool_session.dart';
import '../../tools/widgets/tool_access_panel.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/lost_found_view_model.dart';
import 'report_form.dart';
import 'report_tile.dart';
import 'report_details.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
    required this.files,
  });
  final AuthRepository auth;
  final ProfileRepository profiles;
  final LostFoundRepository repository;
  final NoteFileService files;
  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  late final session = ToolSession(
    auth: widget.auth,
    profiles: widget.profiles,
    cancelPending: widget.repository.cancelPending,
  );
  late final model = LostFoundViewModel(session, widget.repository);
  bool mine = false;
  @override
  void dispose() {
    model.dispose();
    session.dispose();
    super.dispose();
  }

  Future<void> create(String type) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportForm(
        type: type,
        repository: widget.repository,
        files: widget.files,
        session: session,
      ),
    );
    if (result == true) {
      setState(() => mine = true);
      await model.load();
    }
  }

  Future<void> details(String id) async {
    final e = session.epoch;
    try {
      final r = await model.read(id);
      if (!mounted || r == null) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ToolScopedDialog(
          session: session,
          child: ReportDetails(
            report: r,
            repository: widget.repository,
            files: widget.files,
          ),
        ),
      );
    } catch (_) {
      if (mounted && e == session.epoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read report. Please refresh and retry.'),
          ),
        );
      }
    }
  }

  Future<void> withdraw(String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Withdraw this report?'),
        content: const Text(
          'It will leave the active OSA queue. Your report history will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (yes == true) await model.withdraw(id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, session]),
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            16,
            AppTokens.gutter,
            120,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 136).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: mine ? 'Back to Lost & Found' : 'Back to Tools',
                      onPressed: () {
                        if (mine) {
                          setState(() => mine = false);
                        } else {
                          context.go('/tools');
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        mine ? 'My reports' : 'Lost & Found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                if (session.access != ToolAccess.eligible)
                  ToolAccessPanel(session: session, title: 'Lost & Found')
                else if (mine) ...[
                  if (model.loading) const LinearProgressIndicator(),
                  if (model.error != null)
                    ContentState(
                      title: 'Reports unavailable',
                      message: model.error!,
                      onRetry: model.load,
                    ),
                  if (!model.loading && model.reports.isEmpty)
                    const ContentState(
                      title: 'No reports yet',
                      message: 'Create a lost or found report, with or without a photograph.',
                    ),
                  for (final r in model.reports)
                    ReportTile(
                      report: r,
                      busy: model.busy,
                      onOpen: () => details(r.id),
                      onWithdraw: () => withdraw(r.id),
                    ),
                  TextButton.icon(
                    onPressed: model.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ] else ...[
                  SizedBox(
                    height: (constraints.maxHeight * .12).clamp(24.0, 100.0),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReportChoiceButton(
                            label: 'Create found report',
                            icon: Icons.inventory_2_outlined,
                            color: colors.primary,
                            foreground: colors.onPrimary,
                            onPressed: () => create('found'),
                          ),
                          const SizedBox(height: 16),
                          ReportChoiceButton(
                            label: 'Create lost report',
                            icon: Icons.search,
                            color: colors.tertiary,
                            foreground: colors.onTertiary,
                            onPressed: () => create('lost'),
                          ),
                          const SizedBox(height: 16),
                          ReportChoiceButton(
                            label: 'My reports',
                            icon: Icons.history,
                            color: colors.secondary,
                            foreground: colors.onSecondary,
                            onPressed: () => setState(() => mine = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

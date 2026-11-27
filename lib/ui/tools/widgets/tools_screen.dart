import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../../routing/startup_destination.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/tools_hub_view_model.dart';
import 'campus_contact_item.dart';
import 'shortcut_grid.dart';
import 'tool_feedback_dialog.dart';
import 'tool_shortcut.dart';
import 'tools_section.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.externalUrls,
  });
  final AuthRepository auth;
  final ProfileRepository profiles;
  final ExternalUrlService externalUrls;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late final _model = ToolsHubViewModel(
    auth: widget.auth,
    profiles: widget.profiles,
    externalUrls: widget.externalUrls,
  );
  bool _feedbackOpen = false;

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _openTool(CampusTool tool) async {
    if (_feedbackOpen) return;
    _feedbackOpen = true;
    try {
      await _showToolFeedback(tool);
    } finally {
      _feedbackOpen = false;
    }
  }

  Future<void> _openLink(Uri uri) async {
    await _model.openLink(uri);
    final error = _model.linkError;
    if (mounted && error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showToolFeedback(CampusTool tool) async {
    final availability = _model.availability(tool);
    if (availability == ToolAvailability.signIn) {
      final signIn = await showDialog<bool>(
        context: context,
        builder: (_) => SignInPrompt(feature: tool.label),
      );
      if (mounted && signIn == true && _model.isGuest) {
        context.go(StartupDestination.signIn.path);
      }
      return;
    }
    if (availability == ToolAvailability.profileError) {
      await _model.retryProfile();
      return;
    }
    if (availability == ToolAvailability.loading) return;
    if (tool == CampusTool.todo && availability == ToolAvailability.available) {
      context.go('/tools/todo');
      return;
    }
    if (tool == CampusTool.gpa && availability == ToolAvailability.available) {
      context.go('/tools/gpa');
      return;
    }
    if (tool == CampusTool.notes &&
        availability == ToolAvailability.available) {
      context.go('/tools/notes');
      return;
    }
    if (tool == CampusTool.lostAndFound &&
        availability == ToolAvailability.available) {
      context.go('/tools/lost-found');
      return;
    }
    if (tool == CampusTool.calendar &&
        availability == ToolAvailability.available) {
      context.go('/tools/calendar');
      return;
    }
    if (tool == CampusTool.scheduler &&
        availability == ToolAvailability.available) {
      context.go('/tools/scheduler');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ToolFeedbackDialog(
        title: 'Account eligibility',
        message: _model.eligibilityMessage(tool),
        icon: tool.icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => PopScope(
      canPop: !_model.isGuest,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_model.isGuest) return;
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
        } else {
          context.go(StartupDestination.gettingStarted.path);
        }
      },
      child: ListView(
        key: const PageStorageKey('tools-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space * 2,
          AppTokens.gutter,
          104,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ToolsSection(
                    title: 'Tools',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_model.rolesLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppTokens.space),
                            child: Text('Checking account eligibility…'),
                          ),
                        if (_model.roleError != null)
                          ContentState(
                            title: 'Account eligibility unavailable',
                            message: _model.roleError!,
                            compact: true,
                            onRetry: () => unawaited(_model.retryProfile()),
                          ),
                        ShortcutGrid(
                          children: [
                            for (final tool in CampusTool.values)
                              ToolShortcut(
                                key: ValueKey(tool),
                                label: tool.label,
                                icon: tool.icon,
                                availabilityLabel: _model.availabilityLabel(
                                  tool,
                                ),
                                onPressed:
                                    _model.availability(tool) ==
                                        ToolAvailability.loading
                                    ? null
                                    : () => unawaited(_openTool(tool)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space * 3),
                  ToolsSection(
                    title: 'University Services',
                    child: ShortcutGrid(
                      children: [
                        for (final service in [
                          ('SIS', Icons.school_outlined, UniversityLinks.sis),
                          (
                            'Moodle',
                            Icons.menu_book_outlined,
                            UniversityLinks.moodle,
                          ),
                          (
                            'iMail',
                            Icons.mail_outline_rounded,
                            UniversityLinks.imail,
                          ),
                        ])
                          ToolShortcut(
                            label: service.$1,
                            icon: service.$2,
                            onPressed: _model.launching
                                ? null
                                : () => unawaited(_openLink(service.$3)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space * 3),
                  const ToolsSection(
                    title: 'Emergency & Campus Contacts',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CampusContactItem(
                          label: 'Campus Security',
                          icon: Icons.shield_outlined,
                        ),
                        CampusContactItem(
                          label: 'Campus Medical Support',
                          icon: Icons.medical_services_outlined,
                        ),
                        CampusContactItem(
                          label: 'Student Affairs',
                          icon: Icons.people_outline_rounded,
                        ),
                        CampusContactItem(
                          label: 'IT Helpdesk',
                          icon: Icons.support_agent_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

extension on CampusTool {
  IconData get icon => switch (this) {
    CampusTool.gpa => Icons.calculate_outlined,
    CampusTool.todo => Icons.checklist_rounded,
    CampusTool.calendar => Icons.calendar_month_outlined,
    CampusTool.scheduler => Icons.schedule_rounded,
    CampusTool.notes => Icons.edit_note_rounded,
    CampusTool.lostAndFound => Icons.travel_explore_rounded,
  };
}

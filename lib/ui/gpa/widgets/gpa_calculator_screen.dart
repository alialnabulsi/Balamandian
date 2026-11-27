import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/gpa_calculator_view_model.dart';
import '../view_models/academic_profile_view_model.dart';
import 'gpa_baseline_section.dart';
import 'gpa_course_card.dart';
import 'gpa_header.dart';
import 'gpa_estimate_banner.dart';
import 'student_access_panel.dart';

class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
    required this.externalUrls,
  });
  final AuthRepository auth;
  final ProfileRepository profiles;
  final AcademicRepository repository;
  final ExternalUrlService externalUrls;
  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  late final _model = GpaCalculatorViewModel(
    auth: widget.auth,
    profiles: widget.profiles,
    repository: widget.repository,
  );
  GoRouter? _router;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routeInformationProvider.removeListener(_routeChanged);
      _router = router;
      router.routeInformationProvider.addListener(_routeChanged);
    }
  }

  void _routeChanged() {
    // Shell branches remain mounted offstage. Dispose alone cannot clear a
    // temporary scenario when switching to another tab or a root route.
    if (_router!.routeInformationProvider.value.uri.path != '/tools/gpa') {
      _model.reset();
    }
  }

  Future<void> _signIn() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const SignInPrompt(feature: 'GPA Calculator'),
    );
    if (mounted &&
        confirm == true &&
        _model.academic.access == StudentAccess.guest) {
      context.go('/welcome/sign-in');
    }
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_routeChanged);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final result = _model.calculation;
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          8,
          AppTokens.gutter,
          112,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GpaHeader(
                    onBack: () => context.go('/tools'),
                    onReset: _model.eligible
                        ? () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            _model.reset();
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_model.eligible)
                    StudentAccessPanel(
                      access: _model.academic.access,
                      onSignIn: () => unawaited(_signIn()),
                      onRetry: () => unawaited(_model.academic.retryProfile()),
                    )
                  else
                    KeyedSubtree(
                      key: ValueKey(_model.generation),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GpaEstimateBanner(prediction: result.semester),
                          const SizedBox(height: 16),
                          for (final (index, course) in _model.courses.indexed)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: GpaCourseCard(
                                key: ValueKey(course.id),
                                course: course,
                                index: index + 1,
                                onChanged: _model.updateCourse,
                                onRemove: () => _model.removeCourse(course.id),
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (result.error case final error?) ...[
                            FormMessage(error),
                            const SizedBox(height: 16),
                          ],
                          AsyncActionButton(
                            label: 'Add course',
                            outlined: true,
                            onPressed: _model.addCourse,
                          ),
                          const SizedBox(height: 24),
                          GpaBaselineSection(model: _model),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Projected cumulative GPA'),
                              ),
                              Text(
                                '${result.cumulative?.equivalent.toStringAsFixed(2) ?? '-'} /4',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

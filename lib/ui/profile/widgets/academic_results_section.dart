import 'package:flutter/material.dart';

import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../gpa/view_models/academic_profile_view_model.dart';
import 'account_information_group.dart';

/// Owner-only result presentation; no calculator controls or academic writes.
class AcademicResultsSection extends StatefulWidget {
  const AcademicResultsSection({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
  });
  final AuthRepository auth;
  final ProfileRepository profiles;
  final AcademicRepository repository;
  @override
  State<AcademicResultsSection> createState() => _AcademicResultsSectionState();
}

class _AcademicResultsSectionState extends State<AcademicResultsSection> {
  late final _model = AcademicProfileViewModel(
    auth: widget.auth,
    profiles: widget.profiles,
    repository: widget.repository,
    autoLoad: true,
  );
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      if (_model.access != StudentAccess.eligible) {
        return const SizedBox.shrink();
      }
      return AccountInformationGroup(
        title: 'Academic results · private',
        icon: Icons.school_outlined,
        children: [
          if (_model.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Reading saved academic profile',
            )
          else if (_model.error case final error?) ...[
            Text(error),
            TextButton(
              onPressed: _model.load,
              child: const Text('Retry academic profile'),
            ),
          ] else if (_model.snapshot != null) ...[
            if (_model.snapshot!.available) ...[
              Text(
                'GPA: ${_model.snapshot!.gpa?.equivalent?.toStringAsFixed(2) ?? '-'} /4',
              ),
              Text(
                'CGPA: ${_model.snapshot!.cgpa?.equivalent?.toStringAsFixed(2) ?? '-'} /4',
              ),
              Text(_model.snapshot!.semesterLabel ?? ''),
              if (_model.snapshot!.calculation == 'numeric_enrollments')
                const Text('Calculated from completed SIS grades'),
            ] else
              Text(_model.snapshot!.importMessage),
          ],
        ],
      );
    },
  );
}

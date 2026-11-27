import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/gpa_calculator_view_model.dart';
import 'gpa_input.dart';

class GpaBaselineSection extends StatelessWidget {
  const GpaBaselineSection({super.key, required this.model});
  final GpaCalculatorViewModel model;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AsyncActionButton(
        label: 'Import GPA & CGPA from SIS',
        outlined: true,
        running: model.academic.loading,
        runningLabel: 'Importing from SIS...',
        onPressed: model.importSis,
      ),
      if (model.academic.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FormMessage(model.academic.error!),
        ),
      if (model.academic.snapshot?.available == true)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                'Current GPA: ${model.academic.snapshot!.gpa?.equivalent?.toStringAsFixed(2) ?? '-'} /4',
              ),
              Text(
                'Current CGPA: ${model.academic.snapshot!.cgpa?.equivalent?.toStringAsFixed(2) ?? '-'} /4',
              ),
            ],
          ),
        ),
      if (model.academic.snapshot?.calculation == 'numeric_enrollments')
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Calculated from completed SIS grades'),
        ),
      const SizedBox(height: 12),
      GpaInput(
        enabled: !model.academic.loading,
        label: 'Completed GPA-counted credits',
        value: model.priorCredits,
        error: model.priorCreditsError,
        onChanged: (s) => model.setBaseline(credits: s),
      ),
      const SizedBox(height: 12),
      GpaInput(
        enabled: !model.academic.loading,
        label: 'Current cumulative average /100',
        value: model.priorAverage,
        error: model.priorAverageError,
        onChanged: (s) => model.setBaseline(average: s),
      ),
    ],
  );
}

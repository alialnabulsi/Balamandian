import 'package:flutter/material.dart';

import '../view_models/notes_session.dart';

/// Removes private modal contents immediately when account eligibility changes.
class NotesScopedDialog extends StatelessWidget {
  const NotesScopedDialog({
    super.key,
    required this.session,
    required this.epoch,
    required this.child,
  });
  final NotesSession session;
  final int epoch;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.epoch != epoch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          }
        });
        return const SizedBox.shrink();
      }
      return child;
    },
  );
}

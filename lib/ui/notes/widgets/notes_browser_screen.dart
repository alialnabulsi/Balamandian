import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/notes_repository.dart';
import '../../../data/services/note_draft_store.dart';
import '../../../domain/models/note_models.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/form_message.dart';
import '../view_models/notes_browser_view_model.dart';
import '../view_models/notes_session.dart';
import 'notes_header.dart';
import 'notes_breadcrumbs.dart';
import 'notes_item_tile.dart';
import 'notes_access_panel.dart';
import 'notes_dialogs.dart';
import 'notes_scoped_dialog.dart';

class NotesBrowserScreen extends StatefulWidget {
  const NotesBrowserScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.drafts,
  });
  final NotesSession session;
  final NotesRepository repository;
  final NoteDraftStore drafts;
  @override
  State<NotesBrowserScreen> createState() => _NotesBrowserScreenState();
}

class _NotesBrowserScreenState extends State<NotesBrowserScreen> {
  late final _model = NotesBrowserViewModel(
    session: widget.session,
    repository: widget.repository,
    drafts: widget.drafts,
  );
  bool _dialog = false;
  Future<void> _signIn() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => const SignInPrompt(feature: 'My Notes'),
    );
    if (mounted && yes == true && widget.session.access == NotesAccess.guest) {
      context.go('/welcome/sign-in');
    }
  }

  Future<void> _create() async {
    final e = widget.session.epoch;
    final note = await _model.create();
    if (mounted && note != null && e == widget.session.epoch) {
      await _open(note.id);
    }
  }

  Future<void> _open(String id) async {
    await context.push('/tools/notes/$id');
    if (mounted) await _model.refresh();
  }

  Future<void> _folder([NoteFolder? folder, String action = 'New']) async {
    if (_dialog) return;
    _dialog = true;
    final epoch = widget.session.epoch;
    try {
      if (action == 'Delete') {
        final yes = await showDialog<bool>(
          context: context,
          builder: (_) => NotesScopedDialog(
            session: widget.session,
            epoch: epoch,
            child: const NotesConfirmDialog(
              title: 'Delete folder?',
              message: 'Contents are preserved. Direct child folders move to its parent. Direct notes move to its parent, or to Playground when deleting a root folder. Nested contents stay inside their child folders.',
            ),
          ),
        );
        if (yes == true && epoch == widget.session.epoch) {
          await _model.deleteFolder(folder!);
        }
      } else if (action == 'Move') {
        final excluded = _model.excludedDestinations(folder!.id);
        final parent = await showDialog<String>(
          context: context,
          builder: (_) => NotesScopedDialog(
            session: widget.session,
            epoch: epoch,
            child: NotesDestinationDialog(
              folders: _model.folders,
              path: _model.path,
              includeRoot: true,
              excluded: excluded,
            ),
          ),
        );
        if (parent != null && epoch == widget.session.epoch) {
          await _model.saveFolder(
            folder.name,
            folder: folder,
            parent: parent.isEmpty ? null : parent,
          );
        }
      } else {
        final name = await showDialog<String>(
          context: context,
          builder: (_) => NotesScopedDialog(
            session: widget.session,
            epoch: epoch,
            child: FolderNameDialog(name: folder?.name ?? ''),
          ),
        );
        if (name != null && epoch == widget.session.epoch) {
          await _model.saveFolder(
            name,
            folder: folder,
            parent: folder?.parentId,
          );
        }
      }
    } finally {
      _dialog = false;
    }
  }

  Future<void> _note(PersonalNote note, String action) async {
    final epoch = widget.session.epoch;
    if (action == 'Move') {
      final id = await showDialog<String>(
        context: context,
        builder: (_) => NotesScopedDialog(
          session: widget.session,
          epoch: epoch,
          child: NotesDestinationDialog(
            folders: _model.folders,
            path: _model.path,
          ),
        ),
      );
      if (id != null && epoch == widget.session.epoch) {
        await _model.moveNote(note, id);
      }
    } else {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => NotesScopedDialog(
          session: widget.session,
          epoch: epoch,
          child: NotesConfirmDialog(
            title: 'Delete note?',
            message:
                '“${note.title}” and its private attachments will be deleted. This cannot be undone.',
          ),
        ),
      );
      if (yes == true && epoch == widget.session.epoch) {
        await _model.deleteNote(note);
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => PopScope(
      canPop: _model.folderId == null && _model.search.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _model.back();
      },
      child: RefreshIndicator(
        onRefresh: _model.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            8,
            AppTokens.gutter,
            112,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NotesHeader(
                      onBack: () => context.go('/tools'),
                      onNote: _model.eligible && !_model.busy
                          ? () => unawaited(_create())
                          : null,
                      onFolder: _model.eligible && !_model.busy
                          ? () => unawaited(_folder())
                          : null,
                      onSearch: _model.setSearch,
                      search: _model.search,
                    ),
                    if (!_model.eligible)
                      NotesAccessPanel(
                        access: widget.session.access,
                        onSignIn: () => unawaited(_signIn()),
                        onRetry: widget.session.retry,
                      )
                    else ...[
                      NotesBreadcrumbs(
                        folders: _model.breadcrumbs,
                        onOpen: _model.enter,
                      ),
                      if (_model.loading || _model.busy)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Loading notes',
                        ),
                      if (_model.error case final error?) ...[
                        FormMessage(error),
                        TextButton(
                          onPressed: _model.refresh,
                          child: const Text('Retry notes'),
                        ),
                      ],
                      if (_model.recovered.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Local recovery drafts (${_model.recovered.length})',
                          ),
                          subtitle: const Text(
                            'Private to this account · not yet server-saved',
                          ),
                          children: [
                            for (final d in _model.recovered)
                              ListTile(
                                title: Text(
                                  d.title.isEmpty ? 'Untitled note' : d.title,
                                ),
                                leading: const Icon(Icons.restore_rounded),
                                onTap: () => unawaited(_open(d.noteId)),
                              ),
                          ],
                        ),
                      if (_model.search.isEmpty)
                        for (final f in _model.children)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: NotesFolderTile(
                              folder: f,
                              enabled: !_model.busy,
                              onOpen: () => _model.enter(f.id),
                              onAction: (a) => unawaited(_folder(f, a)),
                            ),
                          ),
                      if (!_model.loading && _model.notes.isEmpty)
                        ContentState(
                          compact: true,
                          icon: Icons.edit_note_rounded,
                          title: _model.search.isEmpty
                              ? 'Room for a new idea'
                              : 'No matching titles',
                          message: _model.search.isEmpty
                              ? 'Create a note here, or organize your ideas in folders.'
                              : 'Search looks through every folder in your account.',
                        ),
                      for (final n in _model.notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NotesItemTile(
                            note: n,
                            path: _model.search.isNotEmpty
                                ? _model.path(n.folderId)
                                : null,
                            enabled: !_model.busy,
                            onOpen: () => unawaited(_open(n.id)),
                            onAction: (a) => unawaited(_note(n, a)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

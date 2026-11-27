import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/notes_repository.dart';
import '../../../data/services/note_draft_store.dart';
import '../../../data/services/note_file_service.dart';
import '../../../domain/models/note_models.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/form_message.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/note_editor_view_model.dart';
import '../view_models/notes_session.dart';
import '../view_models/notes_exit_guard.dart';
import 'notes_dialogs.dart';
import 'notes_scoped_dialog.dart';
import 'notes_access_panel.dart';
import 'note_formatting_toolbar.dart';
import 'note_text_block.dart';
import 'note_drawing_canvas.dart';
import 'note_drawing_editor.dart';
import 'note_attachment_tile.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.noteId,
    required this.session,
    required this.repository,
    required this.drafts,
    required this.files,
    required this.guard,
  });
  final String noteId;
  final NotesSession session;
  final NotesRepository repository;
  final NoteDraftStore drafts;
  final NoteFileService files;
  final NotesExitGuard guard;
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final _model = NoteEditorViewModel(
    noteId: widget.noteId,
    session: widget.session,
    repository: widget.repository,
    drafts: widget.drafts,
    files: widget.files,
  );
  bool _allowExit = false;
  Future<bool>? _exit;
  late final Future<bool> Function() _guardCallback = _confirmLeave;
  @override
  void initState() {
    super.initState();
    widget.guard.confirm = _guardCallback;
  }

  Future<bool> _confirmLeave() {
    if (_allowExit || !_model.current || (!_model.dirty && !_model.saving)) {
      return Future.value(true);
    }
    return _exit ??= _askLeave().whenComplete(() => _exit = null);
  }

  Future<bool> _askLeave() async {
    final epoch = widget.session.epoch;
    final choice = await showDialog<NotesLeaveChoice>(
      context: context,
      builder: (_) => NotesScopedDialog(
        session: widget.session,
        epoch: epoch,
        child: const NotesLeaveDialog(),
      ),
    );
    if (!mounted || !_model.current) return true;
    final ok = switch (choice) {
      NotesLeaveChoice.save => await _model.save(),
      NotesLeaveChoice.local => await _model.keepDraftAndLeave(),
      _ => false,
    };
    if (ok) _allowExit = true;
    return ok;
  }

  Future<void> _back() async {
    if (await _confirmLeave() && mounted) context.go('/tools/notes');
  }

  Future<void> _saveAndClose() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await _model.save() && mounted && _model.current && !_model.dirty) {
      _allowExit = true;
      context.go('/tools/notes');
    }
  }

  Future<void> _drawing([NoteBlock? block]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final epoch = widget.session.epoch;
    final drawing = _model.beginDrawing(block?.id);
    if (drawing == null) return;
    final strokes = await showModalBottomSheet<List<InkStroke>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: false,
      builder: (_) => NotesScopedDialog(
        session: widget.session,
        epoch: epoch,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .94,
          child: NoteDrawingEditor(
            strokes: drawing.strokes,
            onChanged: _model.stageDrawing,
          ),
        ),
      ),
    );
    if (epoch == widget.session.epoch) _model.endDrawing(keep: strokes != null);
  }

  Future<void> _delete() async {
    final epoch = widget.session.epoch;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => NotesScopedDialog(
        session: widget.session,
        epoch: epoch,
        child: const NotesConfirmDialog(
          title: 'Delete note?',
          message: 'This note, its drawings and private attachments will be deleted permanently.',
        ),
      ),
    );
    if (yes == true &&
        epoch == widget.session.epoch &&
        await _model.delete() &&
        mounted) {
      _allowExit = true;
      context.go('/tools/notes');
    }
  }

  Future<void> _move() async {
    final epoch = widget.session.epoch;
    try {
      final folders = await _model.destinations();
      if (!mounted || epoch != widget.session.epoch) return;
      final id = await showDialog<String>(
        context: context,
        builder: (_) => NotesScopedDialog(
          session: widget.session,
          epoch: epoch,
          child: NotesDestinationDialog(
            folders: folders,
            path: (id) => noteFolderPath(folders, id),
          ),
        ),
      );
      if (id != null && epoch == widget.session.epoch) await _model.move(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destinations could not load. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _rebase() async {
    final epoch = widget.session.epoch;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => NotesScopedDialog(
        session: widget.session,
        epoch: epoch,
        child: const NotesConfirmDialog(
          title: 'Keep local draft over latest revision?',
          message: 'Your local content stays intact. Save will replace the latest server content. Further concurrent edits still cause a conflict.',
          action: 'Prepare draft to save',
        ),
      ),
    );
    if (yes == true && epoch == widget.session.epoch) await _model.rebase();
  }

  Future<void> _openAttachment(NoteBlock b, NoteAttachment? a) async {
    if (a?.image != true) {
      await _model.openAttachment(b);
      return;
    }
    final epoch = widget.session.epoch, bytes = await _model.preview(b);
    if (!mounted || epoch != widget.session.epoch || bytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NotesScopedDialog(
        session: widget.session,
        epoch: epoch,
        child: Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(bytes, semanticLabel: a!.filename),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close image'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => const SignInPrompt(feature: 'My Notes'),
    );
    if (mounted && yes == true && widget.session.access == NotesAccess.guest) {
      context.go('/welcome/sign-in');
    }
  }

  @override
  void dispose() {
    if (identical(widget.guard.confirm, _guardCallback)) {
      widget.guard.confirm = null;
    }
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => PopScope(
      canPop: _allowExit || (!_model.dirty && !_model.saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: AppBrandedBackground(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back to My Notes',
              onPressed: () => unawaited(_back()),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Note editor'),
            actions: [
              IconButton(
                tooltip: 'Save note',
                onPressed: _model.canEdit && !_model.saving
                    ? () => unawaited(_saveAndClose())
                    : null,
                icon: const Icon(Icons.save_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Note actions',
                enabled: _model.canEdit,
                onSelected: (v) => unawaited(v == 'Move' ? _move() : _delete()),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'Move', child: Text('Move note')),
                  const PopupMenuItem(
                    value: 'Delete',
                    child: Text('Delete note'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_model.canEdit)
                  NoteFormattingToolbar(
                    selected: _model.selected,
                    onFormat: _model.format,
                    onUndo: _model.canUndo ? _model.undo : null,
                    onRedo: _model.canRedo ? _model.redo : null,
                    onParagraph: _model.addText,
                    onDrawing: () => unawaited(_drawing()),
                    onAttachment: () => unawaited(_model.pickAttachment()),
                  ),
                Expanded(
                  child: ListView(
                    key: ValueKey(_model.generation),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppTokens.gutter),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.session.access != NotesAccess.eligible)
                                NotesAccessPanel(
                                  access: widget.session.access,
                                  onSignIn: () => unawaited(_signIn()),
                                  onRetry: widget.session.retry,
                                )
                              else if (_model.loading)
                                const LinearProgressIndicator(
                                  semanticsLabel: 'Loading note',
                                )
                              else ...[
                                if (_model.error case final error?) ...[
                                  FormMessage(error),
                                  if (!_model.loaded)
                                    TextButton(
                                      onPressed: _model.load,
                                      child: const Text('Retry note'),
                                    ),
                                ],
                                if (_model.draftError case final error?)
                                  FormMessage(error),
                                if (_model.recovered)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Recovered local draft · not server-saved. Review it before Save.',
                                    ),
                                  ),
                                if (_model.conflict)
                                  TextButton(
                                    onPressed: () => unawaited(_rebase()),
                                    child: const Text(
                                      'Resolve conflict · keep local draft',
                                    ),
                                  ),
                                if (_model.loaded) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _model.saveStatus,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: _model.title,
                                    onChanged: _model.setTitle,
                                    maxLength: 160,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                    decoration: const InputDecoration(
                                      labelText: 'Note title',
                                      hintText: 'Untitled note',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const Text(
                                    'Formatting applies to the selected paragraph. Swipe the toolbar for all controls.',
                                  ),
                                  const SizedBox(height: 12),
                                  if (_model.document.blocks.isEmpty)
                                    ContentState(
                                      compact: true,
                                      title: 'Begin with an idea',
                                      message: 'Add a paragraph, drawing or attachment using the toolbar.',
                                      icon: Icons.edit_note_rounded,
                                    ),
                                  for (final b in _model.document.blocks)
                                    Padding(
                                      key: ValueKey(b.id),
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: b.isText
                                          ? NoteTextBlock(
                                              blankPage:
                                                  _model
                                                          .document
                                                          .blocks
                                                          .length ==
                                                      1 &&
                                                  b.type == 'paragraph',
                                              block: b,
                                              number: _model.numberFor(b.id),
                                              onSelect: () =>
                                                  _model.select(b.id),
                                              onChanged: (t) => _model
                                                  .updateBlock(b.copy(text: t)),
                                              onRemove: () =>
                                                  _model.removeBlock(b.id),
                                            )
                                          : b.type == 'drawing'
                                          ? Column(
                                              children: [
                                                InkWell(
                                                  onTap: () =>
                                                      unawaited(_drawing(b)),
                                                  child: NoteDrawingCanvas(
                                                    strokes: b.strokes,
                                                  ),
                                                ),
                                                Wrap(
                                                  children: [
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          unawaited(
                                                            _drawing(b),
                                                          ),
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                      ),
                                                      label: const Text(
                                                        'Edit drawing',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => _model
                                                          .removeBlock(b.id),
                                                      child: const Text(
                                                        'Remove drawing',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : NoteAttachmentTile(
                                              block: b,
                                              attachment: _model.attachments
                                                  .where(
                                                    (a) =>
                                                        a.id == b.attachmentId,
                                                  )
                                                  .firstOrNull,
                                              preview: _model.preview(b),
                                              onOpen: () => unawaited(
                                                _openAttachment(
                                                  b,
                                                  _model.attachments
                                                      .where(
                                                        (a) =>
                                                            a.id ==
                                                            b.attachmentId,
                                                      )
                                                      .firstOrNull,
                                                ),
                                              ),
                                              onRemove: () =>
                                                  _model.removeBlock(b.id),
                                              onRetry: () =>
                                                  unawaited(_model.upload(b)),
                                              onCancel: _model.cancelUpload,
                                              progress: _model.uploading[b.id],
                                              error: _model.uploadErrors[b.id],
                                            ),
                                    ),
                                  const SizedBox(height: 40),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

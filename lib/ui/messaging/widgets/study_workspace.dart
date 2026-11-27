import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/academic.dart';
import '../../../domain/models/messaging.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/academic_model.dart';
import 'chat_thread.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';
import 'study_item_editor.dart';

enum StudyArea {
  resources(
    'resource',
    'Resources',
    Icons.folder_open_outlined,
    'Add resource',
    'Share PDFs and text files with the room.',
  ),
  notes(
    'note',
    'Notes',
    Icons.notes_rounded,
    'Write note',
    'Keep study notes and explanations in one place.',
  ),
  questions(
    'question',
    'Questions',
    Icons.forum_outlined,
    'Ask question',
    'Ask a question, compare answers and mark a solution.',
  ),
  sessions(
    'session',
    'Sessions',
    Icons.event_outlined,
    'Schedule session',
    'Plan a study session and set a reminder.',
  );

  const StudyArea(this.keyName, this.label, this.icon, this.action, this.empty);
  final String keyName, label, action, empty;
  final IconData icon;
}

class StudyWorkspace extends StatefulWidget {
  const StudyWorkspace({
    super.key,
    required this.id,
    this.initial = StudyArea.resources,
  });
  final String id;
  final StudyArea initial;
  @override
  State<StudyWorkspace> createState() => _StudyWorkspaceState();
}

class _StudyWorkspaceState extends State<StudyWorkspace> {
  late final session = MessagingScope.of(context, listen: false).session;
  late final Future<Conversation> thread;
  String? previous;

  @override
  void initState() {
    super.initState();
    previous = session.focusedThread;
    session.focus(widget.id);
    thread = session.repository.thread(widget.id);
  }

  @override
  void dispose() {
    session.focus(previous, whenClosing: widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: StudyArea.values.length,
    initialIndex: widget.initial.index,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Study space'),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final area in StudyArea.values)
              Tab(icon: Icon(area.icon, size: 19), text: area.label),
          ],
        ),
      ),
      body: FutureBuilder<Conversation>(
        future: thread,
        builder: (context, snapshot) {
          if (snapshot.hasError || snapshot.data?.study == false) {
            return const ContentState(
              title: 'Study space unavailable',
              message: 'Join the room to access its study tools.',
              icon: Icons.lock_outline,
            );
          }
          if (!snapshot.hasData) return const MessagingSkeleton();
          return TabBarView(
            children: [
              for (final area in StudyArea.values)
                StudyAreaPanel(thread: snapshot.data!, area: area),
            ],
          );
        },
      ),
    ),
  );
}

class StudyAreaPanel extends StatefulWidget {
  const StudyAreaPanel({super.key, required this.thread, required this.area});
  final Conversation thread;
  final StudyArea area;
  @override
  State<StudyAreaPanel> createState() => _StudyAreaPanelState();
}

class _StudyAreaPanelState extends State<StudyAreaPanel> {
  late final session = MessagingScope.of(context, listen: false).session;
  late final model = AcademicModel(session.repository);
  late final listing = model.items(widget.thread.id, widget.area.keyName);
  late Conversation thread = widget.thread;
  String? version;
  bool available = true;

  @override
  void initState() {
    super.initState();
    session.addListener(sync);
    unawaited(listing.load());
  }

  @override
  void dispose() {
    session.removeListener(sync);
    listing.dispose();
    super.dispose();
  }

  void sync() {
    final latest = session.snapshot;
    if (session.focusedThread != thread.id || latest == null) return;
    if (!latest.threadAvailable) {
      if (available) setState(() => available = false);
      return;
    }
    if (version == latest.revision) return;
    version = latest.revision;
    final revision = version;
    unawaited(listing.load());
    unawaited(
      session.repository.thread(thread.id).then<void>((value) {
        if (mounted && revision == version) {
          setState(() {
            thread = value;
            available = true;
          });
        }
      }, onError: (Object _) {}),
    );
  }

  Future<void> edit() async {
    final saved = await showStudyEditor(
      context,
      model,
      thread.id,
      widget.area.keyName,
    );
    if (saved && mounted) await listing.load();
  }

  Future<void> view(AcademicItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StudyItemDetail(model: model, thread: thread, item: item),
    );
    if (mounted) await listing.load();
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    if (!available) {
      return const ContentState(
        title: 'Study space unavailable',
        message: 'Membership is required.',
        icon: Icons.lock_outline,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: listing.load,
          child: ListenableBuilder(
            listenable: listing,
            builder: (context, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 30),
              children: [
                StudyAreaHeading(
                  thread: thread,
                  area: area,
                  onCreate: thread.canWrite ? edit : null,
                ),
                const SizedBox(height: 12),
                if (listing.loading && listing.items.isEmpty)
                  const MessagingSkeleton(),
                if (listing.error != null)
                  ContentState(
                    title: 'Could not load ${area.label.toLowerCase()}',
                    message: listing.error.toString(),
                    onRetry: listing.load,
                    compact: true,
                  ),
                if (!listing.loading &&
                    listing.error == null &&
                    listing.items.isEmpty)
                  ContentState(
                    title: 'No ${area.label.toLowerCase()} yet',
                    message: area.empty,
                    icon: area.icon,
                    compact: true,
                  ),
                for (final item in listing.items)
                  StudyItemTile(
                    item: item,
                    area: area,
                    onTap: () => view(item),
                  ),
                if (listing.next != null)
                  TextButton(
                    onPressed: listing.loadingMore
                        ? null
                        : () => listing.load(more: true),
                    child: const Text('Show more'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyAreaHeading extends StatelessWidget {
  const StudyAreaHeading({
    super.key,
    required this.thread,
    required this.area,
    this.onCreate,
  });
  final Conversation thread;
  final StudyArea area;
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [thread.courseCode, thread.courseName].nonNulls.join(' · '),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              thread.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onCreate != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton.icon(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(area.action),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StudyItemTile extends StatelessWidget {
  const StudyItemTile({
    super.key,
    required this.item,
    required this.area,
    required this.onTap,
  });
  final AcademicItem item;
  final StudyArea area;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final info = switch (area) {
      StudyArea.resources =>
        '${item.filename ?? ''} · ${((item.fileSize ?? 0) / 1024).ceil()} KB',
      StudyArea.sessions =>
        item.startsAt == null
            ? ''
            : DateFormat.MMMEd().add_jm().format(item.startsAt!),
      StudyArea.questions =>
        item.resolvedId == null
            ? '${item.answerCount} ${item.answerCount == 1 ? 'answer' : 'answers'}'
            : 'Resolved · ${item.answerCount} ${item.answerCount == 1 ? 'answer' : 'answers'}',
      StudyArea.notes => [
        item.author?.displayName,
        DateFormat.MMMd().format(item.published),
      ].nonNulls.join(' · '),
    };
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 7,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(area.icon, color: colors.primary, size: 21),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(info, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Icon(
            item.pinned ? Icons.push_pin_rounded : Icons.chevron_right_rounded,
            size: 20,
            semanticLabel: item.pinned ? 'Pinned' : null,
          ),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class StudyItemDetail extends StatefulWidget {
  const StudyItemDetail({
    super.key,
    required this.model,
    required this.thread,
    required this.item,
  });
  final AcademicModel model;
  final Conversation thread;
  final AcademicItem item;
  @override
  State<StudyItemDetail> createState() => _StudyItemDetailState();
}

class _StudyItemDetailState extends State<StudyItemDetail> {
  late final answers = widget.model.items(
    widget.thread.id,
    'question',
    question: widget.item.id,
  );
  late final session = MessagingScope.of(context, listen: false).session;
  late bool pinned = widget.item.pinned, reminded = widget.item.reminded;
  late String? resolved = widget.item.resolvedId;
  Uint8List? bytes, pdf;
  bool loading = false, busy = false;

  @override
  void initState() {
    super.initState();
    session.addListener(accessChanged);
    if (widget.item.kind == 'question') unawaited(answers.load());
  }

  @override
  void dispose() {
    session.removeListener(accessChanged);
    answers.dispose();
    super.dispose();
  }

  void accessChanged() {
    if (mounted &&
        ModalRoute.isCurrentOf(context) == true &&
        session.focusedThread == widget.thread.id &&
        session.snapshot?.threadAvailable == false) {
      Navigator.pop(context);
    }
  }

  Future<void> command(
    String action,
    Object? value,
    VoidCallback success,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    await communityCommand(context, () async {
      await widget.model.change(
        widget.thread.id,
        widget.item.id,
        action,
        value,
      );
      if (mounted) success();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> document({required bool share}) async {
    if (loading) return;
    setState(() => loading = true);
    await communityCommand(context, () async {
      final downloaded = await widget.model.download(
        widget.thread.id,
        widget.item.id,
      );
      if (!mounted) return;
      if (share) {
        final file = widget.item.filename!;
        final anchor = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(downloaded, mimeType: widget.item.mime)],
            fileNameOverrides: [file],
            sharePositionOrigin: anchor == null
                ? null
                : anchor.localToGlobal(Offset.zero) & anchor.size,
          ),
        );
      } else {
        Uint8List? preview;
        if (widget.item.mime == 'application/pdf') {
          preview = await const MethodChannel('balamandian/academic_pdf')
              .invokeMethod<Uint8List>('firstPage', downloaded);
        }
        if (mounted) {
          setState(() {
            bytes = downloaded;
            pdf = preview;
          });
        }
      }
    });
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final canManage = item.mine || widget.thread.admin;
    return FractionallySizedBox(
      heightFactor: .88,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (item.author != null)
              Text(item.author!.displayName, style: theme.textTheme.labelLarge),
            if (item.startsAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(DateFormat.MMMEd().add_jm().format(item.startsAt!)),
              ),
            if (item.location?.isNotEmpty == true) Text(item.location!),
            if (item.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(item.body),
              ),
            if (item.filename != null) ...[
              Text(item.filename!, style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => document(share: false),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : () => document(share: true),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download or share'),
                  ),
                ],
              ),
              if (loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Fetching document',
                ),
              if (pdf != null)
                Image.memory(
                  pdf!,
                  semanticLabel: 'First page of ${item.filename}',
                ),
              if (bytes != null && item.mime == 'text/plain')
                SelectableText(
                  utf8.decode(
                    bytes!.take(16000).toList(),
                    allowMalformed: true,
                  ),
                ),
            ],
            if (item.kind == 'session' &&
                item.startsAt?.isAfter(DateTime.now()) == true)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => command(
                          'remind',
                          !reminded,
                          () => setState(() => reminded = !reminded),
                        ),
                  icon: Icon(
                    reminded
                        ? Icons.notifications_active_outlined
                        : Icons.notification_add_outlined,
                  ),
                  label: Text(reminded ? 'Reminder set' : 'Remind me'),
                ),
              ),
            if (item.kind == 'question') ...[
              const Divider(),
              Text(
                resolved == null ? 'Answers' : 'Answers · Resolved',
                style: theme.textTheme.titleMedium,
              ),
              if (widget.thread.canWrite)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      if (await showStudyEditor(
                            context,
                            widget.model,
                            widget.thread.id,
                            'answer',
                            parent: item.id,
                          ) &&
                          mounted) {
                        await answers.load();
                      }
                    },
                    child: const Text('Write an answer'),
                  ),
                ),
              ListenableBuilder(
                listenable: answers,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (answers.loading && answers.items.isEmpty)
                      const LinearProgressIndicator(),
                    if (answers.error != null)
                      TextButton(
                        onPressed: answers.load,
                        child: const Text('Retry answers'),
                      ),
                    for (final answer in answers.items)
                      StudyAnswer(
                        answer: answer,
                        accepted: answer.id == resolved,
                        onAccept: canManage && !busy
                            ? () => command(
                                'resolve',
                                resolved == answer.id ? null : answer.id,
                                () => setState(
                                  () => resolved = resolved == answer.id
                                      ? null
                                      : answer.id,
                                ),
                              )
                            : null,
                      ),
                    if (answers.next != null)
                      TextButton(
                        onPressed: answers.loadingMore
                            ? null
                            : () => answers.load(more: true),
                        child: const Text('More answers'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                if (widget.thread.admin || widget.thread.pinPolicy == 'members')
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => command(
                            'pin',
                            !pinned,
                            () => setState(() => pinned = !pinned),
                          ),
                    icon: const Icon(Icons.push_pin_outlined),
                    label: Text(pinned ? 'Unpin' : 'Pin'),
                  ),
                TextButton.icon(
                  onPressed: () => openChatReport(
                    context,
                    widget.thread.id,
                    item.kind == 'resource'
                        ? 'academic_resource'
                        : 'academic_item',
                    subject: item.id,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report'),
                ),
                if (canManage)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await communityConfirm(
                                  context,
                                  'Remove this item?',
                                  'The item will no longer be available in the room.',
                                ) &&
                                mounted) {
                              await command(
                                'delete',
                                null,
                                () => Navigator.pop(context),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StudyAnswer extends StatelessWidget {
  const StudyAnswer({
    super.key,
    required this.answer,
    required this.accepted,
    this.onAccept,
  });
  final AcademicItem answer;
  final bool accepted;
  final VoidCallback? onAccept;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(answer.author?.displayName ?? 'Member'),
    subtitle: Text(answer.body),
    trailing: onAccept == null
        ? (accepted
              ? const Icon(Icons.check_circle, semanticLabel: 'Accepted answer')
              : null)
        : IconButton(
            tooltip: accepted ? 'Reopen question' : 'Accept answer',
            onPressed: onAccept,
            icon: Icon(
              accepted ? Icons.check_circle : Icons.check_circle_outline,
            ),
          ),
  );
}

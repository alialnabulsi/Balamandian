import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../../domain/models/messaging.dart';
import '../../../domain/models/profile_models.dart';
import '../../community/view_models/community_composer_model.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../profile/view_models/member_list_view_model.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';

class MessagingRecipient extends StatefulWidget {
  const MessagingRecipient({
    super.key,
    this.group = false,
    this.invitation,
    this.post,
    this.forward,
  });
  final bool group;
  final String? invitation, post, forward;
  @override
  State<MessagingRecipient> createState() => _MessagingRecipientState();
}

class _MessagingRecipientState extends State<MessagingRecipient> {
  late final MessagingScope scope;
  late final MemberListViewModel members;
  final search = TextEditingController(),
      title = TextEditingController(),
      description = TextEditingController(),
      note = TextEditingController();
  final selected = <String, PublicUserIdentity>{};
  final groupId = CommunityRepository.newId();
  List<Conversation> recent = [];
  String? next;
  Timer? debounce;
  Uint8List? groupPhoto;
  String? photoType;
  CommunityImage? uploaded;
  bool busy = false, loadingRecent = false;
  double? progress;
  int generation = 0;
  String? operationId, destinationId;
  bool get selectMultiple => widget.group || widget.invitation != null;
  bool get sendingContent => widget.post != null || widget.forward != null;

  @override
  void initState() {
    super.initState();
    scope = MessagingScope.of(context, listen: false);
    members = MemberListViewModel(
      repository: scope.profiles,
      kind: MemberListKind.discover,
    );
    unawaited(members.load(refresh: true));
    if (sendingContent) unawaited(_recent());
  }

  Future<void> _recent({bool more = false}) async {
    if (more && (loadingRecent || next == null)) return;
    final current = ++generation;
    setState(() => loadingRecent = true);
    try {
      final page = await scope.session.repository.conversations(
        search: search.text.trim(),
        cursor: more ? next : null,
      );
      if (mounted && current == generation) {
        setState(() {
          recent = [
            if (more) ...recent,
            ...page.items.where((row) => row.canWrite && !row.pending),
          ];
          next = page.next;
        });
      }
    } catch (e) {
      if (mounted && current == generation) {
        communityFeedback(context, e.toString());
      }
    } finally {
      if (mounted && current == generation) {
        setState(() => loadingRecent = false);
      }
    }
  }

  Future<void> _photo() async {
    await communityCommand(context, () async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      if (await file.length() > 8000000) {
        throw const CommunityFailure('Choose a photo smaller than 8 MB.');
      }
      final bytes = await file.readAsBytes();
      final type = CommunityComposerModel.imageType(bytes);
      if (type == null) {
        throw const CommunityFailure('Choose a JPEG, PNG or WebP photo.');
      }
      if (mounted) {
        setState(() {
          groupPhoto = bytes;
          photoType = type;
          uploaded = null;
        });
      }
    });
  }

  Future<void> choose({String? member, String? thread}) async {
    if (busy) return;
    setState(() => busy = true);
    final repo = scope.session.repository;
    try {
      final id = thread ?? await repo.direct(member!);
      if (!mounted) return;
      if (!sendingContent) {
        context.pushReplacement('/messages/$id');
        return;
      }
      if (destinationId != id) operationId = null;
      destinationId = id;
      final operation = operationId ??= CommunityRepository.newId();
      await repo.object(
        'conversations/$id/messages/$operation',
        method: 'PUT',
        data: {
          'text': note.text.trim(),
          'referenceId': widget.post,
          if (widget.post != null) 'referenceKind': 'post',
          'forwardId': widget.forward,
        },
      );
      if (!mounted) return;
      communityFeedback(context, 'Sent');
      context.pop();
    } catch (e) {
      if (mounted) communityFeedback(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish() async {
    if (busy) return;
    if (widget.group && title.text.trim().length < 2) {
      communityFeedback(context, 'Give the group a name.');
      return;
    }
    setState(() => busy = true);
    await communityCommand(context, () async {
      final repo = scope.session.repository;
      if (widget.invitation case final id?) {
        await repo.object(
          'groups/$id/invitations',
          method: 'PUT',
          data: {'members': selected.keys.toList()},
        );
        if (mounted) context.pop();
        return;
      }
      if (groupPhoto != null) {
        uploaded ??= await repo.media.upload(groupPhoto!, photoType!, (value) {
          if (mounted) setState(() => progress = value);
        });
      }
      await repo.object(
        'groups/$groupId',
        method: 'PUT',
        data: {
          'title': title.text.trim(),
          'description': description.text.trim(),
          'image': uploaded?.id,
          'members': selected.keys.toList(),
        },
      );
      if (mounted) context.pushReplacement('/messages/$groupId');
    });
    if (mounted) {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    members.dispose();
    search.dispose();
    title.dispose();
    description.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.group
              ? 'New private group'
              : widget.invitation != null
              ? 'Invite members'
              : widget.post != null
              ? 'Send post'
              : widget.forward != null
              ? 'Forward message'
              : 'New conversation',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: members,
              builder: (context, _) => ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                children: [
                  if (widget.group)
                    GroupIdentityFields(
                      title: title,
                      description: description,
                      photo: groupPhoto,
                      onPhoto: busy ? null : _photo,
                    ),
                  if (!selectMultiple && !sendingContent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push('/messages/new-group'),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Create private group'),
                      ),
                    ),
                  if (widget.post != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: note,
                        enabled: !busy,
                        maxLength: 4000,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => operationId = null,
                        decoration: const InputDecoration(
                          labelText: 'Add a message',
                          counterText: '',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                  MessagingSearch(
                    controller: search,
                    label: sendingContent
                        ? 'Find a chat or member'
                        : 'Search members',
                    onChanged: (value) {
                      members.searchChanged(value);
                      if (sendingContent) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 320),
                          () => unawaited(_recent()),
                        );
                      }
                    },
                  ),
                  if (selectMultiple && selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final person in selected.values)
                            InputChip(
                              label: Text(person.displayName),
                              onDeleted: busy
                                  ? null
                                  : () => setState(
                                      () => selected.remove(person.id),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  if (busy || loadingRecent)
                    LinearProgressIndicator(value: progress),
                  if (sendingContent && recent.isNotEmpty) ...[
                    const RecipientSection(title: 'Conversations'),
                    for (final thread in recent)
                      ConversationRow(
                        thread: thread,
                        onTap: busy ? null : () => choose(thread: thread.id),
                      ),
                    if (next != null)
                      TextButton(
                        onPressed: () => _recent(more: true),
                        child: const Text('More conversations'),
                      ),
                  ],
                  if (sendingContent || selectMultiple)
                    const RecipientSection(title: 'Members'),
                  if (members.loading && members.items.isEmpty)
                    const MessagingSkeleton(),
                  if (members.error != null)
                    ContentState(
                      title: 'Members unavailable',
                      message: members.error ?? 'Search for another member.',
                      onRetry: () => members.load(refresh: true),
                      compact: true,
                    ),
                  if (!members.loading &&
                      members.error == null &&
                      members.items.isEmpty)
                    const ContentState(
                      title: 'No matching members',
                      message: 'Try a different name or username.',
                      icon: Icons.person_search_outlined,
                      compact: true,
                    ),
                  for (final row in members.items)
                    RecipientRow(
                      member: row.identity,
                      selectable: selectMultiple,
                      selected: selected.containsKey(row.identity.id),
                      onTap: busy
                          ? null
                          : () {
                              if (!selectMultiple) {
                                unawaited(choose(member: row.identity.id));
                                return;
                              }
                              setState(() {
                                if (selected.containsKey(row.identity.id)) {
                                  selected.remove(row.identity.id);
                                } else if (selected.length < 49) {
                                  selected[row.identity.id] = row.identity;
                                }
                              });
                            },
                    ),
                  if (members.hasMore)
                    TextButton(
                      onPressed: members.loading ? null : members.load,
                      child: const Text('More members'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: selectMultiple
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 5, 16, 10),
              child: FilledButton(
                onPressed: busy || (!widget.group && selected.isEmpty)
                    ? null
                    : finish,
                child: Text(widget.group ? 'Create group' : 'Send invitations'),
              ),
            )
          : null,
    );
  }
}

class RecipientSection extends StatelessWidget {
  const RecipientSection({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 13, 4, 6),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class RecipientRow extends StatelessWidget {
  const RecipientRow({
    super.key,
    required this.member,
    required this.onTap,
    required this.selectable,
    required this.selected,
  });
  final PublicUserIdentity member;
  final VoidCallback? onTap;
  final bool selectable, selected;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: MemberAvatar(
      identity: member,
      loadAvatar: MessagingScope.of(context, listen: false).profiles.avatar,
      size: 42,
    ),
    title: Text(member.displayName),
    subtitle: Text('@${member.username}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
    trailing: selectable
        ? Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: Theme.of(context).colorScheme.primary,
          )
        : const Icon(Icons.chevron_right_rounded),
    selected: selected,
    onTap: onTap,
  );
}

class GroupIdentityFields extends StatelessWidget {
  const GroupIdentityFields({
    super.key,
    required this.title,
    required this.description,
    required this.photo,
    required this.onPhoto,
  });
  final TextEditingController title, description;
  final Uint8List? photo;
  final VoidCallback? onPhoto;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextButton.icon(
          onPressed: onPhoto,
          icon: photo == null
              ? const Icon(Icons.add_photo_alternate_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photo!,
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                    cacheWidth: 100,
                  ),
                ),
          label: Text(photo == null ? 'Add group image' : 'Change group image'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: title,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceContainerLow,
            labelText: 'Group name',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: description,
          maxLength: 420,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

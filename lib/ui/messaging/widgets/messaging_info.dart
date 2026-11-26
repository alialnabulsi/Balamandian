import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/community.dart';
import '../../../domain/models/messaging.dart';
import '../../community/view_models/community_composer_model.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/feedback/content_state.dart';
import 'chat_thread.dart';
import 'messaging_inbox.dart';
import 'messaging_recipient.dart';
import 'messaging_scope.dart';

class ConversationInfo extends StatefulWidget {
  const ConversationInfo({super.key, required this.id});
  final String id;
  @override
  State<ConversationInfo> createState() => _ConversationInfoState();
}

class _ConversationInfoState extends State<ConversationInfo> {
  late final scope = MessagingScope.of(context, listen: false);
  Conversation? thread;
  List<ChatMember> members = [];
  CommunityJson? relationship;
  Object? error;
  bool loading = true, busy = false;
  String? _version;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final repo = scope.session.repository;
      final value = await repo.thread(widget.id);
      final people = value.group && !value.invited
          ? await repo.members(widget.id)
          : <ChatMember>[];
      if (!mounted || generation != _generation) return;
      setState(() {
        thread = value;
        members = people;
        error = null;
      });
      if (value.peer?.id case final peer?) {
        final relation = await repo.media.object('relationships/$peer');
        if (mounted && generation == _generation) {
          setState(() => relationship = relation);
        }
      }
    } catch (e) {
      if (mounted && generation == _generation) setState(() => error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => loading = false);
    }
  }

  Future<void> _change(
    String path,
    CommunityJson data, {
    String method = 'PUT',
    bool exit = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    await communityCommand(context, () async {
      await scope.session.repository.object(path, method: method, data: data);
      if (!mounted) return;
      if (exit) {
        context.go('/messages');
        return;
      }
      await _load();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _member(Conversation value, ChatMember member) async {
    final user = member.identity;
    final selection = await communityMenu<String>(
      context,
      child: CommunityMenuBody(
        title: user.displayName,
        children: [
          const CommunityMenuOption(
            'View profile',
            Icons.person_outline,
            'profile',
          ),
          if (value.owner &&
              member.state == 'active' &&
              member.role != 'owner') ...[
            CommunityMenuOption(
              member.role == 'admin'
                  ? 'Remove administrator role'
                  : 'Make administrator',
              Icons.admin_panel_settings_outlined,
              member.role == 'admin' ? 'member' : 'admin',
            ),
            const CommunityMenuOption(
              'Transfer ownership',
              Icons.swap_horiz_rounded,
              'transfer',
            ),
          ],
          if (value.admin &&
              member.role != 'owner' &&
              (value.owner || member.role != 'admin') &&
              user.id != scope.session.repository.userId)
            CommunityMenuOption(
              member.state == 'invited'
                  ? 'Cancel invitation'
                  : 'Remove from group',
              Icons.person_remove_outlined,
              'remove',
            ),
        ],
      ),
    );
    if (selection == null || !mounted) return;
    if (selection == 'profile') {
      context.push('/members/${user.id}');
      return;
    }
    if ((selection == 'remove' || selection == 'transfer') &&
        !await communityConfirm(
          context,
          selection == 'remove'
              ? 'Remove ${user.displayName}?'
              : 'Transfer ownership to ${user.displayName}?',
          selection == 'remove' ? 'Their group access will end.' : 'The new owner will manage administrator roles and group closure.',
        )) {
      return;
    }
    if (mounted) {
      await _change('groups/${value.id}/members/${user.id}', {
        'action': selection,
      });
    }
  }

  Future<void> _block(String peer) async {
    final unblock = relationship?['blocked'] == true;
    if (!await communityConfirm(
          context,
          unblock ? 'Unblock this member?' : 'Block this member?',
          unblock ? 'Direct conversations can be opened again.' : 'The direct conversation and its attachments will become unavailable.',
        ) ||
        !mounted) {
      return;
    }
    await communityCommand(context, () async {
      await scope.session.repository.media.mutate(
        'relationships/$peer/block',
        method: unblock ? 'DELETE' : 'PUT',
      );
      scope.session.repository.media.invalidate();
      if (mounted) context.go('/messages');
    });
  }

  Future<void> _find(Conversation value, {String? filter}) async {
    final uri = Uri(
      path: '/messages/${value.id}/search',
      queryParameters: {'filter': ?filter},
    );
    final seq = await context.push<int>(uri.toString());
    if (mounted && seq != null) {
      context.push('/messages/${value.id}?anchor=$seq');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = MessagingScope.of(context).session;
    final snapshot = session.focusedThread == widget.id
        ? session.snapshot
        : null;
    if (snapshot?.threadVersion != null &&
        snapshot!.threadVersion != _version) {
      _version = snapshot.threadVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
    final available = snapshot?.threadAvailable != false;
    final value = available ? thread : null;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          value?.group == true
              ? 'Group information'
              : 'Conversation information',
        ),
      ),
      body: SafeArea(
        child: value == null
            ? loading
                  ? const MessagingSkeleton()
                  : ContentState(
                      title: 'Conversation unavailable',
                      message: available
                          ? error?.toString() ??
                                'Open the conversation from Messages.'
                          : 'Membership or privacy has changed.',
                      onRetry: _load,
                    )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  ConversationIdentity(thread: value),
                  if (error != null)
                    MessagingStatus(
                      text: error.toString(),
                      icon: Icons.error_outline,
                    ),
                  if (busy) const LinearProgressIndicator(),
                  if (value.invited)
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Report invitation'),
                      onTap: () =>
                          openChatReport(context, value.id, 'group_invitation'),
                    )
                  else ...[
                    const RecipientSection(
                      title: 'Shared in this conversation',
                    ),
                    for (final (label, icon, filter) in [
                      ('Search messages', Icons.search_rounded, null),
                      ('Photos', Icons.photo_library_outlined, 'images'),
                      (
                        'Shared posts and stories',
                        Icons.bookmarks_outlined,
                        'shares',
                      ),
                      ('Links', Icons.link_rounded, 'links'),
                      if (value.group)
                        ('Pinned messages', Icons.push_pin_outlined, 'pinned'),
                    ])
                      ListTile(
                        leading: Icon(icon),
                        title: Text(label),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _find(value, filter: filter),
                      ),
                    const RecipientSection(title: 'Your preferences'),
                    SwitchListTile(
                      title: const Text('Mute activity notifications'),
                      subtitle: const Text(
                        'Unread messages still appear in your inbox.',
                      ),
                      value: value.muted,
                      onChanged: busy
                          ? null
                          : (on) => _change('conversations/${value.id}', {
                              'muted': on,
                            }, method: 'PATCH'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.push_pin_outlined),
                      title: Text(
                        value.pinned
                            ? 'Unpin conversation'
                            : 'Pin conversation',
                      ),
                      onTap: busy
                          ? null
                          : () => _change('conversations/${value.id}', {
                              'pinned': !value.pinned,
                            }, method: 'PATCH'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text(
                        value.archived
                            ? 'Move to inbox'
                            : 'Archive conversation',
                      ),
                      onTap: busy
                          ? null
                          : () => _change(
                              'conversations/${value.id}',
                              {'archived': !value.archived},
                              method: 'PATCH',
                              exit: true,
                            ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.mark_chat_unread_outlined),
                      title: const Text('Mark as unread'),
                      onTap: busy
                          ? null
                          : () => _change(
                              'conversations/${value.id}',
                              {'markedUnread': true},
                              method: 'PATCH',
                              exit: true,
                            ),
                    ),
                    if (value.group) ...[
                      const RecipientSection(title: 'Membership'),
                      if (value.admin || value.invitePolicy == 'members')
                        ListTile(
                          leading: const Icon(Icons.group_add_outlined),
                          title: const Text('Invite members'),
                          onTap: () async {
                            await context.push<void>(
                              '/messages/${value.id}/invite',
                            );
                            if (mounted) await _load();
                          },
                        ),
                      if (value.admin || value.editPolicy == 'members')
                        ListTile(
                          leading: const Icon(Icons.tune_rounded),
                          title: Text(
                            value.admin
                                ? 'Group permissions and identity'
                                : 'Edit group identity',
                          ),
                          onTap: () async {
                            await context.push<void>(
                              '/messages/${value.id}/permissions',
                            );
                            if (mounted) await _load();
                          },
                        ),
                      for (final member in members)
                        ListTile(
                          leading: MemberAvatar(
                            identity: member.identity,
                            loadAvatar: scope.profiles.avatar,
                            size: 38,
                          ),
                          title: Text(member.identity.displayName),
                          subtitle: Text(
                            member.state == 'invited'
                                ? 'Invited'
                                : switch (member.role) {
                                    'owner' => 'Owner',
                                    'admin' => 'Administrator',
                                    _ => 'Member',
                                  },
                          ),
                          trailing: const Icon(Icons.more_horiz),
                          onTap: () => _member(value, member),
                        ),
                      const RecipientSection(title: 'Safety'),
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Report group'),
                        onTap: () => openChatReport(context, value.id, 'group'),
                      ),
                      ListTile(
                        leading: Icon(
                          value.owner
                              ? Icons.lock_outline
                              : Icons.logout_rounded,
                        ),
                        title: Text(
                          value.owner ? 'Close group' : 'Leave group',
                        ),
                        onTap: busy
                            ? null
                            : () async {
                                if (await communityConfirm(
                                      context,
                                      value.owner
                                          ? 'Close this group?'
                                          : 'Leave this group?',
                                      value.owner
                                          ? 'The group and its history will no longer be accessible.'
                                          : 'You’ll lose access to this group’s history and media.',
                                    ) &&
                                    mounted) {
                                  await _change(
                                    'groups/${value.id}/members/${scope.session.repository.userId}',
                                    {'action': value.owner ? 'close' : 'leave'},
                                    exit: true,
                                  );
                                }
                              },
                      ),
                    ] else if (value.peer case final peer?) ...[
                      const RecipientSection(title: 'Privacy and safety'),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('View profile'),
                        onTap: () => context.push('/members/${peer.id}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.block_outlined),
                        title: Text(
                          relationship?['blocked'] == true
                              ? 'Unblock member'
                              : 'Block member',
                        ),
                        onTap: () => _block(peer.id),
                      ),
                      if (value.pending && !value.initiated)
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: const Text('Report message request'),
                          onTap: () => openChatReport(
                            context,
                            value.id,
                            'message_request',
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Message privacy applies to new conversations. Blocking also closes access to existing direct chats.',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class ConversationIdentity extends StatelessWidget {
  const ConversationIdentity({super.key, required this.thread});
  final Conversation thread;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
      child: Column(
        children: [
          ConversationAvatar(thread: thread, size: 76),
          const SizedBox(height: 12),
          Text(
            thread.name,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            thread.group
                ? '${thread.memberCount} members · Private group'
                : '@${thread.peer?.username ?? ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (thread.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(thread.description, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class GroupPermissions extends StatefulWidget {
  const GroupPermissions({super.key, required this.id});
  final String id;
  @override
  State<GroupPermissions> createState() => _GroupPermissionsState();
}

class _GroupPermissionsState extends State<GroupPermissions> {
  late final repo = MessagingScope.of(
    context,
    listen: false,
  ).session.repository;
  late Future<Conversation> request;
  final title = TextEditingController(), description = TextEditingController();
  final Map<String, String> selections = {};
  Uint8List? image;
  String? mime;
  CommunityImage? uploaded;
  bool busy = false, remove = false;
  double? progress;
  @override
  void initState() {
    super.initState();
    request = _initialize();
  }

  Future<Conversation> _initialize() async {
    final value = await repo.thread(widget.id);
    if (mounted) {
      title.text = value.title;
      description.text = value.description;
      selections.addAll({
        'sendPolicy': value.sendPolicy,
        'invitePolicy': value.invitePolicy,
        'editPolicy': value.editPolicy,
        'pinPolicy': value.pinPolicy,
      });
    }
    return value;
  }

  Future<void> _pick() async {
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
      final detected = CommunityComposerModel.imageType(bytes);
      if (detected == null) {
        throw const CommunityFailure('Choose a valid photo.');
      }
      if (mounted) {
        setState(() {
          image = bytes;
          mime = detected;
          uploaded = null;
          remove = false;
        });
      }
    });
  }

  Future<void> _save(Conversation value) async {
    if (title.text.trim().length < 2) {
      communityFeedback(context, 'Give the group a name.');
      return;
    }
    setState(() => busy = true);
    await communityCommand(context, () async {
      if (image != null) {
        uploaded ??= await repo.media.upload(image!, mime!, (v) {
          if (mounted) setState(() => progress = v);
        });
      }
      await repo.object(
        'groups/${widget.id}',
        method: 'PATCH',
        data: {
          'title': title.text.trim(),
          'description': description.text.trim(),
          if (value.admin) ...selections,
          if (remove || uploaded != null) 'image': remove ? null : uploaded!.id,
        },
      );
      if (mounted) context.pop();
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
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Group permissions')),
    body: SafeArea(
      child: FutureBuilder(
        future: request,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null) {
            return snapshot.hasError
                ? ContentState(
                    title: 'Could not load permissions',
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() => request = _initialize()),
                  )
                : const MessagingSkeleton();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GroupIdentityFields(
                title: title,
                description: description,
                photo: image,
                onPhoto: busy ? null : _pick,
              ),
              if ((value.image != null || image != null) && !remove)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          image = null;
                          uploaded = null;
                          remove = true;
                        }),
                  child: const Text('Remove group image'),
                ),
              if (value.admin) ...[
                const RecipientSection(title: 'Who can take these actions'),
                for (final (label, key) in [
                  ('Send messages', 'sendPolicy'),
                  ('Invite members', 'invitePolicy'),
                  ('Edit group identity', 'editPolicy'),
                  ('Pin messages', 'pinPolicy'),
                ])
                  MessagingChoice(
                    title: label,
                    value: selections[key]!,
                    options: const {
                      'members': 'All members',
                      'admins': 'Administrators',
                    },
                    onSelected: busy
                        ? null
                        : (selection) =>
                              setState(() => selections[key] = selection),
                  ),
              ],
              if (busy) LinearProgressIndicator(value: progress),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: busy ? null : () => _save(value),
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class MessagingChoice extends StatelessWidget {
  const MessagingChoice({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    this.onSelected,
  });
  final String title, value;
  final Map<String, String> options;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(options[value] ?? value),
    trailing: const Icon(Icons.expand_more_rounded),
    onTap: onSelected == null
        ? null
        : () async {
            final choice = await communityMenu<String>(
              context,
              child: CommunityMenuBody(
                title: title,
                children: [
                  for (final option in options.entries)
                    CommunityMenuOption(
                      option.value,
                      option.key == value
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      option.key,
                    ),
                ],
              ),
            );
            if (context.mounted && choice != null) onSelected!(choice);
          },
  );
}

class MessagingPrivacy extends StatefulWidget {
  const MessagingPrivacy({super.key});
  @override
  State<MessagingPrivacy> createState() => _MessagingPrivacyState();
}

class _MessagingPrivacyState extends State<MessagingPrivacy> {
  late final repo = MessagingScope.of(
    context,
    listen: false,
  ).session.repository;
  late Future<CommunityJson> request;
  bool busy = false;
  static const audiences = {
    'everyone': 'Eligible Balamandian members',
    'followers': 'My followers',
    'following': 'People I follow',
    'mutual': 'Mutual followers',
    'nobody': 'Nobody',
  };
  @override
  void initState() {
    super.initState();
    request = repo.object('settings');
  }

  Future<void> _set(String key, Object value) async {
    setState(() => busy = true);
    await communityCommand(context, () async {
      await repo.object('settings', method: 'PATCH', data: {key: value});
      if (mounted) setState(() => request = repo.object('settings'));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Messaging privacy')),
    body: SafeArea(
      child: FutureBuilder(
        future: request,
        builder: (context, snapshot) {
          final values = snapshot.data;
          if (values == null) {
            return snapshot.hasError
                ? ContentState(
                    title: 'Settings unavailable',
                    message: snapshot.error.toString(),
                    onRetry: () =>
                        setState(() => request = repo.object('settings')),
                  )
                : const MessagingSkeleton();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const RecipientSection(title: 'Who can contact you'),
              MessagingChoice(
                title: 'New direct messages',
                value: values['messages'] as String,
                options: audiences,
                onSelected: busy ? null : (value) => _set('messages', value),
              ),
              MessagingChoice(
                title: 'Private group invitations',
                value: values['invitations'] as String,
                options: audiences,
                onSelected: busy ? null : (value) => _set('invitations', value),
              ),
              const RecipientSection(title: 'What others can see'),
              SwitchListTile(
                title: const Text('Online and typing indicators'),
                subtitle: const Text('Show status in eligible conversations.'),
                value: values['presence'] == true,
                onChanged: busy ? null : (on) => _set('presence', on),
              ),
              SwitchListTile(
                title: const Text('Direct read receipts'),
                subtitle: const Text(
                  'Group conversations keep member read indicators.',
                ),
                value: values['receipts'] == true,
                onChanged: busy ? null : (on) => _set('receipts', on),
              ),
              const RecipientSection(title: 'Alerts'),
              SwitchListTile(
                title: const Text('Messaging in Activity'),
                subtitle: const Text(
                  'Requests, mentions and shared content can appear in Activity.',
                ),
                value: values['notifications'] == true,
                onChanged: busy ? null : (on) => _set('notifications', on),
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Blocked accounts'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/community/blocked'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

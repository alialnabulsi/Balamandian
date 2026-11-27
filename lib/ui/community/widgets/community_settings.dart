import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../../domain/models/profile_models.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/form_message.dart';
import '../view_models/community_settings_model.dart';
import 'community_actions.dart';
import 'community_author.dart';
import '../../messaging/widgets/messaging_scope.dart';

class CommunitySettings extends StatefulWidget {
  const CommunitySettings({
    super.key,
    required this.repository,
    this.inShell = false,
  });
  final CommunityRepository repository;
  final bool inShell;
  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}

class _CommunitySettingsState extends State<CommunitySettings> {
  late final _model = CommunitySettingsModel(widget.repository);
  @override
  void initState() {
    super.initState();
    unawaited(_model.load());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              final data = _model.data;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (widget.inShell)
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  if (_model.busy) const LinearProgressIndicator(),
                  if (_model.error != null)
                    ContentState(
                      title: 'Settings could not be updated',
                      message: _model.error.toString(),
                      onRetry: _model.load,
                      compact: true,
                    ),
                  if (data != null) ...[
                    const CommunitySettingsHeading(
                      'Privacy',
                      Icons.lock_outline,
                    ),
                    SwitchListTile(
                      title: const Text('Private account'),
                      subtitle: const Text(
                        'Approve new followers. Existing followers keep access.',
                      ),
                      value: data['privateAccount'] == true,
                      onChanged: _model.busy
                          ? null
                          : (v) => _model.change('privateAccount', v),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: const Text('Follow requests'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/community/requests'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.block_outlined),
                      title: const Text('Blocked accounts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/community/blocked'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.volume_off_outlined),
                      title: const Text('Muted accounts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/community/muted'),
                    ),
                    if (MessagingScope.maybeOf(context, listen: false) != null)
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded),
                        title: const Text('Messaging privacy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/messages/privacy'),
                      ),
                    const CommunitySettingsHeading(
                      'Posts and stories',
                      Icons.auto_awesome_outlined,
                    ),
                    ListTile(
                      title: const Text('Story audience'),
                      subtitle: Text(
                        data['storyAudience'] == 'followers'
                            ? 'Approved followers'
                            : 'Eligible Balamandian members',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _model.busy
                          ? null
                          : () async {
                              final result = await communityMenu<String>(
                                context,
                                child: const CommunityMenuBody(
                                  title: 'Story audience',
                                  children: [
                                    CommunityMenuOption(
                                      'Approved followers',
                                      Icons.people_outline,
                                      'followers',
                                    ),
                                    CommunityMenuOption(
                                      'Balamandian members',
                                      Icons.school_outlined,
                                      'members',
                                      subtitle: 'Private accounts always require an approved follow.',
                                    ),
                                  ],
                                ),
                              );
                              if (result != null && mounted) {
                                await _model.change('storyAudience', result);
                              }
                            },
                    ),
                    SwitchListTile(
                      title: const Text('Allow story likes'),
                      value: data['storyLikes'] == true,
                      onChanged: _model.busy
                          ? null
                          : (v) => _model.change('storyLikes', v),
                    ),
                    SwitchListTile(
                      title: const Text('Allow comments on posts'),
                      value: data['postComments'] == true,
                      onChanged: _model.busy
                          ? null
                          : (v) => _model.change('postComments', v),
                    ),
                    const CommunitySettingsHeading(
                      'Activity notifications',
                      Icons.notifications_outlined,
                    ),
                    SwitchListTile(
                      title: const Text('Likes, comments and mentions'),
                      value: data['notifyInteractions'] == true,
                      onChanged: _model.busy
                          ? null
                          : (v) => _model.change('notifyInteractions', v),
                    ),
                    SwitchListTile(
                      title: const Text('Follows and requests'),
                      value: data['notifyRelationships'] == true,
                      onChanged: _model.busy
                          ? null
                          : (v) => _model.change('notifyRelationships', v),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    final surface = Theme.of(context).colorScheme.surface;
    return widget.inShell
        ? ColoredBox(color: surface, child: body)
        : Scaffold(
            backgroundColor: surface,
            appBar: AppBar(title: const Text('Settings')),
            body: body,
          );
  }
}

class CommunitySettingsHeading extends StatelessWidget {
  const CommunitySettingsHeading(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityRelationships extends StatefulWidget {
  const CommunityRelationships({
    super.key,
    required this.repository,
    required this.kind,
    required this.loadAvatar,
  });
  final CommunityRepository repository;
  final String kind;
  final CommunityAvatarLoader loadAvatar;
  @override
  State<CommunityRelationships> createState() => _CommunityRelationshipsState();
}

class _CommunityRelationshipsState extends State<CommunityRelationships> {
  String? _next;
  List<CommunityJson> _items = [];
  Object? _error;
  bool _loading = false;
  final Set<String> _pending = {};
  @override
  void initState() {
    super.initState();
    unawaited(_load(refresh: true));
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.page(
        widget.kind,
        (value) => value,
        cursor: refresh ? null : _next,
      );
      if (mounted) {
        setState(() {
          _items = [if (!refresh) ..._items, ...page.items];
          _next = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(String id, {bool accept = false}) async {
    if (!_pending.add(id)) return;
    setState(() {});
    await communityCommand(context, () async {
      if (widget.kind == 'requests') {
        await widget.repository.mutate(
          'requests/$id',
          data: {'accept': accept},
        );
      } else {
        await widget.repository.mutate(
          'relationships/$id/block',
          method: 'DELETE',
        );
      }
      widget.repository.invalidate();
      if (mounted) {
        setState(() => _items = _items.where((v) => v['id'] != id).toList());
      }
    });
    _pending.remove(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      'requests' => 'Follow requests',
      'blocked' => 'Blocked accounts',
      _ => 'Muted accounts',
    };
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _items.length + 1,
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return Column(
                  children: [
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null) FormMessage(_error.toString()),
                    if (_error != null || _next != null)
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => _load(refresh: _items.isEmpty),
                        child: Text(_error != null ? 'Retry' : 'Load more'),
                      ),
                    if (_items.isEmpty && !_loading && _error == null)
                      ContentState(
                        title: 'No $title'.toLowerCase().replaceFirst(
                          'no',
                          'No',
                        ),
                        message:
                            'You can manage privacy and relationships here.',
                        compact: true,
                      ),
                  ],
                );
              }
              final row = _items[index];
              final member = PublicUserIdentity.fromJson(row['member']);
              final pending = _pending.contains(member.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.kind == 'blocked')
                      ListTile(
                        title: Text(member.displayName),
                        subtitle: Text('@${member.username}'),
                      )
                    else
                      CommunityAuthor(
                        author: member,
                        loadAvatar: widget.loadAvatar,
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.kind == 'requests') ...[
                          FilledButton(
                            onPressed: pending
                                ? null
                                : () => _change(member.id, accept: true),
                            child: const Text('Approve'),
                          ),
                          OutlinedButton(
                            onPressed: pending
                                ? null
                                : () => _change(member.id),
                            child: const Text('Decline'),
                          ),
                        ] else if (widget.kind == 'blocked')
                          OutlinedButton(
                            onPressed: pending
                                ? null
                                : () => _change(member.id),
                            child: const Text('Unblock'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () async {
                              await communityMenu<void>(
                                context,
                                child: CommunityMuteSheet(
                                  repository: widget.repository,
                                  memberId: member.id,
                                  name: member.displayName,
                                ),
                              );
                              if (mounted) await _load(refresh: true);
                            },
                            child: const Text('Edit mute'),
                          ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

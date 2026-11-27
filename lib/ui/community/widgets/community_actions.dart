import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/form_message.dart';
import '../../messaging/widgets/messaging_scope.dart';

void communityFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> communityCommand(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) communityFeedback(context, success);
  } catch (e) {
    if (context.mounted) {
      communityFeedback(
        context,
        e is CommunityFailure
            ? e.message
            : 'Could not finish that action. Try again.',
      );
    }
  }
}

Future<T?> communityMenu<T>(
  BuildContext context, {
  required Widget child,
  bool scrollableSheet = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  showDragHandle: !scrollableSheet,
  enableDrag: !scrollableSheet,
  isScrollControlled: true,
  builder: (_) => child,
);

class CommunityCreateMenu extends StatelessWidget {
  const CommunityCreateMenu({super.key});
  @override
  Widget build(BuildContext context) => const CommunityMenuBody(
    title: 'Create',
    children: [
      CommunityMenuOption(
        'Create post',
        Icons.collections_outlined,
        'post',
        subtitle: 'Up to six photos',
      ),
      CommunityMenuOption(
        'Create story',
        Icons.auto_awesome_outlined,
        'story',
        subtitle: 'A photo for 24 hours',
      ),
    ],
  );
}

class CommunityMenuBody extends StatelessWidget {
  const CommunityMenuBody({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class CommunityMenuOption extends StatelessWidget {
  const CommunityMenuOption(
    this.label,
    this.icon,
    this.value, {
    super.key,
    this.subtitle,
  });
  final String label, value;
  final IconData icon;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    leading: subtitle == null
        ? Icon(icon)
        : CircleAvatar(
            foregroundColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, size: 21),
          ),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: subtitle == null
        ? null
        : const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: () => Navigator.pop(context, value),
  );
}

Future<void> openCommunityCreate(BuildContext context) async {
  final value = await communityMenu<String>(
    context,
    child: const CommunityCreateMenu(),
  );
  if (context.mounted && value != null) {
    await context.push<void>('/community/create/$value');
  }
}

Future<void> shareCommunityPost(
  BuildContext context,
  CommunityEntry post,
) async {
  const origin = String.fromEnvironment('COMMUNITY_LINK_ORIGIN');
  final configured = Uri.tryParse(origin);
  final link =
      configured != null &&
          configured.scheme == 'https' &&
          configured.host.isNotEmpty &&
          configured.userInfo.isEmpty &&
          !configured.hasQuery &&
          !configured.hasFragment &&
          (configured.path.isEmpty || configured.path == '/')
      ? configured.replace(path: '/posts/${post.id}')
      : Uri(scheme: 'balamandian', host: 'post', path: '/posts/${post.id}');
  final render = context.findRenderObject();
  final shareOrigin = render is RenderBox
      ? (render.localToGlobal(Offset.zero) & render.size)
      : null;
  final choice = await communityMenu<String>(
    context,
    child: CommunityMenuBody(
      title: 'Share post',
      children: [
        if (MessagingScope.maybeOf(context, listen: false) != null)
          const CommunityMenuOption(
            'Send in Balamandian',
            Icons.send_outlined,
            'message',
          ),
        const CommunityMenuOption(
          'Share with another app',
          Icons.ios_share_rounded,
          'share',
        ),
        const CommunityMenuOption('Copy link', Icons.link_rounded, 'copy'),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'message') {
    await context.push<void>('/messages/share/${post.id}');
    return;
  }
  await communityCommand(context, () async {
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: link.toString()));
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: 'See this post on Balamandian\n$link',
          sharePositionOrigin: shareOrigin,
        ),
      );
    }
  }, success: choice == 'copy' ? 'Link copied' : null);
}

Future<void> communityPostMenu(
  BuildContext context,
  CommunityRepository repository,
  CommunityEntry post,
) async {
  final action = await communityMenu<String>(
    context,
    child: CommunityMenuBody(
      title: 'Post options',
      children: [
        if (post.isOwn) ...[
          const CommunityMenuOption('Edit post', Icons.edit_outlined, 'edit'),
          CommunityMenuOption(
            post.archived ? 'Restore post' : 'Archive post',
            Icons.archive_outlined,
            'archive',
          ),
          const CommunityMenuOption(
            'Delete post',
            Icons.delete_outline,
            'delete',
          ),
        ] else ...[
          const CommunityMenuOption(
            'Hide from feed',
            Icons.visibility_off_outlined,
            'hide',
          ),
          const CommunityMenuOption(
            'Mute author',
            Icons.volume_off_outlined,
            'mute',
          ),
          const CommunityMenuOption(
            'Report post',
            Icons.flag_outlined,
            'report',
          ),
        ],
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  if (action == 'edit') {
    await context.push<void>('/community/edit/${post.id}');
    return;
  }
  if (action == 'report') {
    await communityMenu<void>(
      context,
      child: CommunityReportSheet(
        repository: repository,
        kind: 'post',
        id: post.id,
      ),
    );
    return;
  }
  if (action == 'mute') {
    await communityMenu<void>(
      context,
      child: CommunityMuteSheet(
        repository: repository,
        memberId: post.author.id,
        name: post.author.displayName,
      ),
    );
    return;
  }
  if (action == 'delete' &&
      !await communityConfirm(
        context,
        'Delete this post?',
        'This removes the post from feeds, saved posts and your profile.',
      )) {
    return;
  }
  if (!context.mounted) return;
  await communityCommand(
    context,
    () async {
      final path = 'entries/${post.id}';
      await repository.mutate(
        action == 'delete' ? path : '$path/$action',
        method: action == 'delete' || (action == 'archive' && post.archived)
            ? 'DELETE'
            : 'PUT',
      );
      repository.invalidate();
    },
    success: switch (action) {
      'hide' => 'Post hidden',
      'delete' => 'Post deleted',
      _ => post.archived ? 'Post restored' : 'Post archived',
    },
  );
}

Future<bool> communityConfirm(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

class CommunityMuteSheet extends StatefulWidget {
  const CommunityMuteSheet({
    super.key,
    required this.repository,
    required this.memberId,
    required this.name,
  });
  final CommunityRepository repository;
  final String memberId, name;
  @override
  State<CommunityMuteSheet> createState() => _CommunityMuteSheetState();
}

class _CommunityMuteSheetState extends State<CommunityMuteSheet> {
  late Future<CommunityJson> _state = widget.repository.object(
    'relationships/${widget.memberId}',
  );
  bool? _posts, _stories;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => CommunityMenuBody(
    title: 'Mute ${widget.name}',
    children: [
      FutureBuilder(
        future: _state,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(
                () => _state = widget.repository.object(
                  'relationships/${widget.memberId}',
                ),
              ),
              child: const Text('Retry loading controls'),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final posts = _posts ?? snapshot.data!['mutePosts'] == true,
              stories = _stories ?? snapshot.data!['muteStories'] == true;
          return Column(
            children: [
              SwitchListTile(
                title: const Text('Posts'),
                value: posts,
                onChanged: _busy ? null : (v) => setState(() => _posts = v),
              ),
              SwitchListTile(
                title: const Text('Stories'),
                value: stories,
                onChanged: _busy ? null : (v) => setState(() => _stories = v),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.repository.mutate(
                            'relationships/${widget.memberId}/mute',
                            data: {'posts': posts, 'stories': stories},
                          );
                          widget.repository.invalidate();
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => _busy = false);
                            communityFeedback(context, e.toString());
                          }
                        }
                      },
                child: Text(_busy ? 'Saving…' : 'Save mute settings'),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class CommunityReportSheet extends StatefulWidget {
  const CommunityReportSheet({
    super.key,
    required this.repository,
    required this.kind,
    required this.id,
  });
  final CommunityRepository repository;
  final String kind, id;
  @override
  State<CommunityReportSheet> createState() => _CommunityReportSheetState();
}

class _CommunityReportSheetState extends State<CommunityReportSheet> {
  final _explanation = TextEditingController();
  String _category = 'harassment';
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: CommunityMenuBody(
      title: _sent ? 'Report received' : 'Report ${widget.kind}',
      children: [
        if (_sent)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Thank you. Your report is confidential.'),
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: _busy ? null : (v) => setState(() => _category = v!),
            items: [
              for (final value in {
                'harassment': 'Harassment',
                'spam': 'Spam',
                'unsafe': 'Unsafe content',
                'privacy': 'Privacy concern',
                'other': 'Other',
              }.entries)
                DropdownMenuItem(value: value.key, child: Text(value.value)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _explanation,
            maxLength: 500,
            maxLines: 3,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
          if (_error != null) FormMessage(_error!),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.repository.mutate(
                        'reports',
                        method: 'POST',
                        data: {
                          'kind': widget.kind,
                          'id': widget.id,
                          'category': _category,
                          'explanation': _explanation.text,
                        },
                      );
                      if (mounted) setState(() => _sent = true);
                    } catch (e) {
                      if (mounted) setState(() => _error = e.toString());
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Sending…' : 'Send report'),
          ),
        ],
      ],
    ),
  );
}

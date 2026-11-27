import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/community.dart';
import '../../../domain/models/messaging.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../view_models/calling_session.dart';
import 'messaging_scope.dart';

class CallingHost extends InheritedNotifier<CallingSession> {
  CallingHost({super.key, required CallingSession calls, required Widget child})
    : super(
        notifier: calls,
        child: Overlay.wrap(
          child: _CallLayer(calls: calls, child: child),
        ),
      );

  static CallingSession? of(BuildContext context, {bool listen = true}) =>
      (listen
              ? context.dependOnInheritedWidgetOfExactType<CallingHost>()
              : context.getInheritedWidgetOfExactType<CallingHost>())
          ?.notifier;
}

class _CallLayer extends StatelessWidget {
  const _CallLayer({required this.calls, required this.child});
  final CallingSession calls;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: calls,
    builder: (context, _) {
      final full = calls.showing && !calls.minimized;
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(excluding: full, child: child),
          if (full)
            VoiceCallScreen(
              key: ValueKey(calls.call?.id ?? 'pending'),
              calls: calls,
            ),
          if (calls.showing && calls.minimized)
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: SafeArea(
                bottom: false,
                child: VoiceStatusBar(calls: calls),
              ),
            ),
          if (!calls.showing && calls.notice != null)
            Positioned(
              bottom: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Theme.of(context).colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    title: Text(
                      calls.notice!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Dismiss call status',
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      onPressed: calls.dismissNotice,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class VoiceStatusBar extends StatelessWidget {
  const VoiceStatusBar({super.key, required this.calls});
  final CallingSession calls;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        dense: true,
        leading: Icon(
          calls.call?.incoming == true
              ? Icons.call_received_rounded
              : Icons.phone_in_talk_outlined,
          color: colors.onPrimaryContainer,
        ),
        title: Text(
          calls.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          calls.call?.incoming == true
              ? 'Incoming voice call'
              : 'Return to voice call',
          style: TextStyle(color: colors.onPrimaryContainer),
        ),
        trailing: Icon(
          Icons.open_in_full_rounded,
          color: colors.onPrimaryContainer,
        ),
        onTap: () => calls.setMinimized(false),
      ),
    );
  }
}

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key, required this.calls});
  final CallingSession calls;
  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  List<MediaDeviceInfo>? outputs;
  List<ChatMember>? options;
  final selection = <String>{};
  String? error;
  bool working = false;
  CallingSession get calls => widget.calls;

  Future<void> _command(Future<void> Function() operation) async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is CommunityFailure
              ? e.toString()
              : 'That call action could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _chooseOutputs() async {
    if (outputs != null) {
      setState(() => outputs = null);
      return;
    }
    await _command(() async {
      final devices = await calls.audioOutputs;
      if (mounted) {
        setState(() {
          outputs = devices;
          options = null;
        });
      }
    });
  }

  Future<void> _chooseMembers() async {
    if (options != null) {
      setState(() => options = null);
      return;
    }
    final call = calls.call;
    if (call == null) return;
    await _command(() async {
      final people = await calls.repository.members(call.thread);
      final excluded = {calls.user, ...calls.peers.map((peer) => peer.id)};
      if (mounted) {
        setState(() {
          options = people
              .where(
                (m) => m.state == 'active' && !excluded.contains(m.identity.id),
              )
              .toList();
          outputs = null;
          selection.clear();
        });
      }
    });
  }

  String _duration(DateTime start) {
    final seconds = DateTime.now().difference(start).inSeconds.clamp(0, 99999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final call = calls.call;
    final incoming = call?.incoming == true;
    final since = call?.connectedAt ?? calls.localConnectedAt;
    final status = switch ((
      incoming,
      calls.connected,
      calls.reconnecting,
      calls.peers.any((p) => p.state == 'joined'),
      call?.kind,
    )) {
      (true, _, _, _, _) => 'Incoming voice call',
      (_, _, true, _, _) => 'Reconnecting…',
      (_, true, _, _, _) => since == null ? 'In call' : _duration(since),
      (_, _, _, true, _) => 'Connecting audio…',
      (_, _, _, _, null) => 'Starting call…',
      (_, _, _, _, 'direct') => 'Ringing…',
      _ => 'Waiting for people to join',
    };
    final photos = MessagingScope.of(context, listen: false).profiles.avatar;
    final other = call?.callerId == calls.user
        ? calls.peers.firstOrNull?.identity
        : call?.caller;
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer, colors.surface, colors.surface],
            stops: const [0, .52, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 32).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Minimize voice call',
                            onPressed: () => calls.setMinimized(true),
                            icon: const Icon(
                              Icons.expand_more_rounded,
                              size: 29,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (call?.kind == 'direct' && other != null)
                          MemberAvatar(
                            identity: other,
                            loadAvatar: photos,
                            size: 94,
                          )
                        else
                          CircleAvatar(
                            radius: 47,
                            backgroundColor: colors.surface,
                            foregroundColor: colors.primary,
                            child: Icon(
                              call?.kind == 'study'
                                  ? Icons.menu_book_outlined
                                  : Icons.graphic_eq_rounded,
                              size: 40,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          calls.title,
                          textAlign: TextAlign.center,
                          style: type.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          status,
                          style: type.titleMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (call?.kind != 'direct' &&
                            calls.peers.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final peer in calls.peers)
                                Semantics(
                                  label:
                                      '${peer.identity?.displayName ?? 'Member'}, ${calls.speaking(peer.id)
                                          ? 'speaking'
                                          : calls.linked(peer.id)
                                          ? 'connected'
                                          : peer.state}',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: calls.speaking(peer.id)
                                                ? colors.primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: MemberAvatar(
                                            identity: peer.identity,
                                            loadAvatar: photos,
                                            size: 41,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          peer.identity?.displayName ??
                                              'Member',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: type.labelSmall,
                                        ),
                                      ),
                                      if (peer.state == 'invited')
                                        Text('Invited', style: type.labelSmall),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (calls.problem ?? error case final problem?)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              problem,
                              style: TextStyle(color: colors.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (incoming)
                          Wrap(
                            spacing: 30,
                            alignment: WrapAlignment.center,
                            children: [
                              VoiceControl(
                                label: 'Decline',
                                icon: Icons.call_end,
                                onTap: calls.busy
                                    ? null
                                    : () => unawaited(calls.respond('decline')),
                                destructive: true,
                              ),
                              VoiceControl(
                                label: 'Accept',
                                icon: Icons.call_rounded,
                                onTap: calls.busy
                                    ? null
                                    : () => unawaited(calls.respond('join')),
                                prominent: true,
                              ),
                            ],
                          )
                        else if (call?.joined == true)
                          Wrap(
                            spacing: 18,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              if (!calls.prepared)
                                VoiceControl(
                                  label: 'Resume audio',
                                  icon: Icons.mic_none,
                                  onTap: calls.busy
                                      ? null
                                      : () =>
                                            unawaited(calls.respond('restart')),
                                  prominent: true,
                                ),
                              if (calls.prepared)
                                VoiceControl(
                                  label: calls.muted ? 'Unmute' : 'Mute',
                                  icon: calls.muted
                                      ? Icons.mic_off_outlined
                                      : Icons.mic_none,
                                  onTap: () => calls.setMuted(!calls.muted),
                                  selected: calls.muted,
                                ),
                              if (calls.prepared)
                                VoiceControl(
                                  label: 'Audio output',
                                  icon: Icons.volume_up_outlined,
                                  onTap: _chooseOutputs,
                                  selected: outputs != null,
                                ),
                              if (call!.kind != 'direct')
                                VoiceControl(
                                  label: 'Invite',
                                  icon: Icons.person_add_alt_1_outlined,
                                  onTap: _chooseMembers,
                                  selected: options != null,
                                ),
                              VoiceControl(
                                label: calls.connected ? 'Leave' : 'Cancel',
                                icon: Icons.call_end,
                                onTap: calls.busy
                                    ? null
                                    : () => unawaited(calls.respond('leave')),
                                destructive: true,
                              ),
                            ],
                          )
                        else
                          const CircularProgressIndicator(),
                        if (outputs case final devices?) ...[
                          const SizedBox(height: 12),
                          if (devices.isEmpty)
                            const Text('Using the Android audio output'),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final device in devices)
                                OutlinedButton(
                                  onPressed: working
                                      ? null
                                      : () => _command(() async {
                                          await calls.output(device.deviceId);
                                          if (mounted) {
                                            setState(() => outputs = null);
                                          }
                                        }),
                                  child: Text(
                                    device.label.isEmpty
                                        ? device.deviceId
                                        : device.label,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (options case final members?) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Invite conversation members',
                            style: type.titleMedium,
                          ),
                          if (members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'No other members are available to invite.',
                              ),
                            ),
                          for (final member in members)
                            CheckboxListTile(
                              title: Text(member.identity.displayName),
                              value: selection.contains(member.identity.id),
                              onChanged: (enabled) => setState(() {
                                if (enabled == true && selection.length < 3) {
                                  selection.add(member.identity.id);
                                }
                                if (enabled == false) {
                                  selection.remove(member.identity.id);
                                }
                              }),
                            ),
                          if (members.isNotEmpty)
                            FilledButton(
                              onPressed: selection.isEmpty || working
                                  ? null
                                  : () => _command(() async {
                                      await calls.invite(selection.toList());
                                      if (mounted) {
                                        setState(() => options = null);
                                      }
                                    }),
                              child: const Text('Send invitations'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceControl extends StatelessWidget {
  const VoiceControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.prominent = false,
    this.selected = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive, prominent, selected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          tooltip: label,
          isSelected: selected,
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(55),
            backgroundColor: destructive
                ? colors.error
                : prominent
                ? colors.primary
                : colors.surfaceContainerHighest,
            foregroundColor: destructive
                ? colors.onError
                : prominent
                ? colors.onPrimary
                : colors.onSurfaceVariant,
          ),
          icon: Icon(icon),
        ),
        const SizedBox(height: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class VoiceHistory extends StatefulWidget {
  const VoiceHistory({super.key, required this.calls, required this.thread});
  final CallingSession calls;
  final Conversation thread;
  @override
  State<VoiceHistory> createState() => _VoiceHistoryState();
}

class _VoiceHistoryState extends State<VoiceHistory> {
  final items = <CommunityJson>[];
  String? next, error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final result = await widget.calls.repository.object(
        'calls/history/${widget.thread.id}',
        query: {'before': ?next},
      );
      if (mounted) {
        setState(() {
          items.addAll((result['items'] as List).cast<CommunityJson>());
          next = result['next'] as String?;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Call history could not load.';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      children: [
        Text(
          'Voice call history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (items.isEmpty && !busy && error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('No calls in this conversation yet.'),
          ),
        for (final row in items)
          ListTile(
            leading: Icon(
              row['callerId'] == widget.calls.user
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
            ),
            title: Text(switch (row['state']) {
              'missed' => 'Missed voice call',
              'declined' => 'Declined voice call',
              _ =>
                row['callerId'] == widget.calls.user
                    ? 'Outgoing voice call'
                    : 'Incoming voice call',
            }),
            subtitle: Text(
              '${DateFormat.MMMd().add_jm().format(DateTime.parse(row['createdAt'] as String).toLocal())} · ${row['endReason'] ?? 'In progress'}${(row['duration'] as int) > 0 ? ' · ${row['duration']}s' : ''}',
            ),
            trailing: IconButton(
              tooltip: 'Call back',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        if (next != null)
          TextButton(
            onPressed: () => unawaited(load()),
            child: const Text('More calls'),
          ),
      ],
    ),
  );
}

class ConversationCallActions extends StatelessWidget {
  const ConversationCallActions({
    super.key,
    required this.calls,
    required this.thread,
  });
  final CallingSession calls;
  final Conversation thread;
  Future<void> _call(BuildContext context) => communityCommand(
    context,
    () => calls.start(thread.id, thread.name, activeId: thread.activeCallId),
  );
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Voice call history',
        icon: const Icon(Icons.history_rounded),
        onPressed: () async {
          final callback = await showModalBottomSheet<bool>(
            context: context,
            showDragHandle: true,
            builder: (_) => VoiceHistory(calls: calls, thread: thread),
          );
          if (callback == true && context.mounted) await _call(context);
        },
      ),
      IconButton(
        tooltip: thread.activeCallId == null
            ? 'Start voice call'
            : 'Join ongoing voice call',
        icon: Icon(
          thread.activeCallId == null
              ? Icons.call_outlined
              : Icons.phone_in_talk_rounded,
        ),
        onPressed: calls.busy ? null : () => _call(context),
      ),
    ],
  );
}

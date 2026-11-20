import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';
import '../../core/ui/form_message.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../view_models/member_list_view_model.dart';
import 'member_list_item.dart';
import 'member_search_field.dart';
import 'profile_load_state.dart';

class MemberListPanel extends StatefulWidget {
  const MemberListPanel({
    super.key,
    required this.repository,
    required this.kind,
    this.userId,
    this.active = true,
  });
  final ProfileRepository repository;
  final MemberListKind kind;
  final String? userId;
  final bool active;
  @override
  State<MemberListPanel> createState() => _MemberListPanelState();
}

class _MemberListPanelState extends State<MemberListPanel>
    with AutomaticKeepAliveClientMixin {
  late final _model = MemberListViewModel(
    repository: widget.repository,
    kind: widget.kind,
    userId: widget.userId,
  );
  final _search = TextEditingController();
  bool _started = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    if (!_started && widget.active) {
      _started = true;
      unawaited(_model.load(refresh: true));
    }
  }

  @override
  void didUpdateWidget(MemberListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start();
  }

  @override
  void dispose() {
    _search.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await context.push<void>('/members/$id');
    if (mounted) await _model.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(
      enabled: widget.active,
      child: Column(
        children: [
          MemberSearchField(
            controller: _search,
            onChanged: _model.searchChanged,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _model,
              builder: (context, _) => Column(
                children: [
                  if ((_model.loading || _model.searching) &&
                      _model.items.isNotEmpty)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      semanticsLabel: 'Updating members',
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _model.load(refresh: true),
                      child: ListView.builder(
                        key: PageStorageKey('members-${widget.kind.name}'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _model.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index < _model.items.length) {
                            final member = _model.items[index];
                            return MemberListItem(
                              key: ValueKey(member.identity.id),
                              member: member,
                              loadAvatar: _model.avatar,
                              onOpen: () => _open(member.identity.id),
                              onFollow: () => _model.toggle(member),
                              pending: _model.pending.contains(
                                member.identity.id,
                              ),
                            );
                          }
                          if (_model.items.isEmpty) {
                            final noQuery = _search.text.trim().isEmpty;
                            return ProfileLoadState(
                              members: true,
                              loading:
                                  _model.loading ||
                                  _model.searching ||
                                  (!_model.hasLoaded && _model.error == null),
                              error: _model.error,
                              onRetry: () => _model.load(refresh: true),
                              emptyTitle: !noQuery
                                  ? 'No matching members'
                                  : switch (widget.kind) {
                                      MemberListKind.followers =>
                                        'No followers yet',
                                      MemberListKind.following =>
                                        'No following yet',
                                      MemberListKind.discover =>
                                        'No members yet',
                                    },
                              emptyMessage: !noQuery
                                  ? 'Try a different name or username.'
                                  : 'Find university members in Discover and start connecting.',
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (_model.error != null) ...[
                                  FormMessage(_model.error!),
                                  TextButton(
                                    onPressed: () => _model.load(
                                      refresh: !_model.paginationFailed,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                                if (_model.hasMore)
                                  AsyncActionButton(
                                    label: 'Load more',
                                    runningLabel: 'Loading…',
                                    running: _model.loadingMore,
                                    outlined: true,
                                    onPressed: _model.loading
                                        ? null
                                        : () => _model.load(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';
import '../../core/ui/form_message.dart';
import '../view_models/member_list_view_model.dart';
import 'member_list_item.dart';
import 'member_search_field.dart';
import 'profile_load_state.dart';
import 'profile_tokens.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({
    super.key,
    required this.repository,
    required this.kind,
    this.userId,
  });
  final ProfileRepository repository;
  final MemberListKind kind;
  final String? userId;
  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  late final _model = MemberListViewModel(
    repository: widget.repository,
    kind: widget.kind,
    userId: widget.userId,
  );
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(_model.load(refresh: true));
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.kind) {
        MemberListKind.discover => 'Discover members',
        MemberListKind.followers => 'Followers',
        MemberListKind.following => 'Following',
      }),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ProfileTokens.maxWidth),
        child: Column(
          children: [
            MemberSearchField(
              controller: _search,
              onChanged: _model.searchChanged,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _model,
                builder: (context, _) => RefreshIndicator(
                  onRefresh: () => _model.load(refresh: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (_model.items.isEmpty)
                        ProfileLoadState(
                          loading: _model.loading,
                          error: _model.error,
                          onRetry: () => _model.load(refresh: true),
                          emptyTitle: _search.text.trim().isEmpty
                              ? 'No members yet'
                              : 'No matching members',
                          emptyMessage: _search.text.trim().isEmpty
                              ? 'Find university members in Discover and start connecting.'
                              : 'Try a different name or username.',
                        ),
                      for (final member in _model.items)
                        MemberListItem(
                          member: member,
                          loadAvatar: _model.avatar,
                          onOpen: () => _open(member.identity.id),
                          onFollow: () => _model.toggle(member),
                          pending: _model.pending.contains(member.identity.id),
                        ),
                      if (_model.items.isNotEmpty && _model.error != null)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              FormMessage(_model.error!),
                              TextButton(
                                onPressed: () => _model.load(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      if (_model.items.isNotEmpty && _model.hasMore)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: OutlinedButton(
                            onPressed: _model.loading
                                ? null
                                : () => _model.load(),
                            child: Text(
                              _model.loading ? 'Loading…' : 'Load more',
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

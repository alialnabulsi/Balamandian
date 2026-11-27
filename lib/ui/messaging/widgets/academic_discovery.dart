import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/academic.dart';
import '../../community/widgets/community_actions.dart';
import '../../community/widgets/community_media.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/academic_model.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';

class AcademicDiscovery extends StatelessWidget {
  const AcademicDiscovery({super.key, this.studyFirst = false});
  final bool studyFirst;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: studyFirst ? 1 : 0,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Official channels'),
            Tab(text: 'Study rooms'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          AcademicDirectory(kind: 'channel'),
          AcademicDirectory(kind: 'study'),
        ],
      ),
    ),
  );
}

class AcademicDirectory extends StatefulWidget {
  const AcademicDirectory({super.key, required this.kind});
  final String kind;
  @override
  State<AcademicDirectory> createState() => _AcademicDirectoryState();
}

class _AcademicDirectoryState extends State<AcademicDirectory>
    with AutomaticKeepAliveClientMixin {
  late final model = AcademicModel(
    MessagingScope.of(context, listen: false).session.repository,
  );
  late final listing = model.spaces(widget.kind);
  final search = TextEditingController();
  Future<bool>? student;
  String? busy;
  bool get study => widget.kind == 'study';
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(listing.load());
    if (study) student = model.canCreate();
  }

  @override
  void dispose() {
    search.dispose();
    listing.dispose();
    super.dispose();
  }

  Future<void> openSpace(AcademicSpace space) async {
    if (busy != null) return;
    if (!space.joined) {
      final accepted = await communityConfirm(
        context,
        'Join ${space.title}?',
        'Membership lets you read past announcements and take part according to the space permissions.',
        confirm: 'Join',
      );
      if (!mounted || !accepted) return;
      setState(() => busy = space.id);
      var joined = false;
      await communityCommand(context, () async {
        await model.join(space.id);
        joined = true;
      });
      if (!mounted) return;
      setState(() => busy = null);
      if (!joined) return;
    }
    await context.push<void>(
      '/messages/${space.id}${space.official ? '?section=announcement' : ''}',
    );
    if (mounted) await listing.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RefreshIndicator(
          onRefresh: listing.load,
          child: ListenableBuilder(
            listenable: listing,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AcademicDirectoryHeading(study: study),
                const SizedBox(height: 14),
                MessagingSearch(
                  controller: search,
                  label: study
                      ? 'Search by course, department or room'
                      : 'Search departments or channels',
                  onChanged: listing.search,
                ),
                if (study)
                  FutureBuilder<bool>(
                    future: student,
                    builder: (context, snapshot) => snapshot.data == true
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: FilledButton.tonalIcon(
                                onPressed: () async {
                                  await context.push<void>(
                                    '/messages/study/new',
                                  );
                                  if (mounted) await listing.load();
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create study room'),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                const SizedBox(height: 14),
                if (listing.loading && listing.items.isEmpty)
                  const MessagingSkeleton(),
                if (listing.error != null)
                  ContentState(
                    title: 'Could not load spaces',
                    message: listing.error.toString(),
                    onRetry: listing.load,
                    compact: true,
                  ),
                if (!listing.loading &&
                    listing.error == null &&
                    listing.items.isEmpty)
                  ContentState(
                    title: listing.query.isEmpty
                        ? 'No ${study ? 'study rooms' : 'official channels'} yet'
                        : 'No matching spaces',
                    message: listing.query.isEmpty
                        ? (study
                              ? 'Course rooms will appear here when they open.'
                              : 'University department channels will appear here when they open.')
                        : 'Try a different name or code.',
                    compact: true,
                  ),
                for (final space in listing.items)
                  AcademicSpaceTile(
                    space: space,
                    working: busy == space.id,
                    onOpen: () => openSpace(space),
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

class AcademicDirectoryHeading extends StatelessWidget {
  const AcademicDirectoryHeading({super.key, required this.study});
  final bool study;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                study ? Icons.auto_stories_outlined : Icons.campaign_outlined,
                color: palette.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    study ? 'Find a study room' : 'Hear from your university',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: palette.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    study
                        ? 'Join a course community to share resources and study together.'
                        : 'Follow announcements and discussions from verified departments.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AcademicSpaceTile extends StatelessWidget {
  const AcademicSpaceTile({
    super.key,
    required this.space,
    required this.working,
    required this.onOpen,
  });
  final AcademicSpace space;
  final bool working;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final repo = MessagingScope.of(context, listen: false).session.repository;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox.square(
                      dimension: 48,
                      child: space.image != null
                          ? CommunityMedia(
                              repository: repo.media,
                              image: space.image!,
                            )
                          : ColoredBox(
                              color: colors.primaryContainer,
                              child: Icon(
                                space.official
                                    ? Icons.account_balance_outlined
                                    : Icons.menu_book_rounded,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                space.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (space.official)
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: colors.primary,
                                  size: 19,
                                  semanticLabel: 'Verified department',
                                ),
                              ),
                          ],
                        ),
                        if (space.affiliation.isNotEmpty)
                          Text(
                            space.affiliation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (space.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    space.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${space.memberCount} ${space.memberCount == 1 ? 'member' : 'members'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: working || !space.canJoin ? null : onOpen,
                    child: Text(
                      working
                          ? 'Joining…'
                          : space.joined
                          ? 'Open'
                          : space.canJoin
                          ? 'Join'
                          : 'Membership unavailable',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../../domain/models/profile_models.dart';
import '../../../routing/shell_destination.dart';
import '../../core/ui/avatars/member_avatar.dart';
import 'community_actions.dart';
import 'community_author.dart';
import 'community_composer.dart';
import 'community_media.dart';
import '../../messaging/widgets/messaging_scope.dart';
import '../../messaging/widgets/messaging_navigation.dart';

class CommunityProfileStories extends StatefulWidget {
  const CommunityProfileStories({
    super.key,
    required this.repository,
    required this.author,
    required this.loadAvatar,
  });
  final CommunityRepository repository;
  final PublicUserIdentity author;
  final CommunityAvatarLoader loadAvatar;
  @override
  State<CommunityProfileStories> createState() =>
      _CommunityProfileStoriesState();
}

class _CommunityProfileStoriesState extends State<CommunityProfileStories> {
  late Future<List<CommunityEntry>> _stories;
  @override
  void initState() {
    super.initState();
    _load();
    widget.repository.addListener(_reload);
  }

  void _load() =>
      _stories = widget.repository.stories(author: widget.author.id);
  void _reload() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CommunityEntry>>(
    key: ValueKey(_stories),
    future: _stories,
    builder: (context, snapshot) {
      final active =
          snapshot.data
              ?.where(
                (entry) => entry.expiresAt?.isAfter(DateTime.now()) == true,
              )
              .toList() ??
          [];
      if (active.isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: Icon(
            active.any((entry) => !entry.seen)
                ? Icons.auto_awesome
                : Icons.play_circle_outline,
          ),
          label: Text(
            active.length == 1
                ? 'View story'
                : 'View stories (${active.length})',
          ),
          onPressed: () async {
            await Navigator.of(context, rootNavigator: true).push<void>(
              MaterialPageRoute(
                builder: (_) => CommunityStoryViewer(
                  repository: widget.repository,
                  entries: active,
                  loadAvatar: widget.loadAvatar,
                ),
              ),
            );
            _reload();
          },
        ),
      );
    },
  );
}

class CommunityStories extends StatelessWidget {
  const CommunityStories({
    super.key,
    required this.entries,
    required this.repository,
    required this.loadAvatar,
    this.identity,
    this.error,
    this.retry,
  });
  final List<CommunityEntry> entries;
  final CommunityRepository repository;
  final CommunityAvatarLoader loadAvatar;
  final PublicUserIdentity? identity;
  final Object? error;
  final VoidCallback? retry;

  Future<void> _open(
    BuildContext context,
    List<CommunityEntry> stories, {
    bool own = false,
  }) async {
    if (own) {
      if (stories.isEmpty) {
        await context.push<void>('/community/create/story');
        return;
      }
      final action = await communityMenu<String>(
        context,
        child: const CommunityMenuBody(
          title: 'Your story',
          children: [
            CommunityMenuOption(
              'View story',
              Icons.play_circle_outline,
              'view',
            ),
            CommunityMenuOption(
              'Add story',
              Icons.add_photo_alternate_outlined,
              'add',
            ),
          ],
        ),
      );
      if (!context.mounted || action == null) return;
      if (action == 'add') {
        await context.push<void>('/community/create/story');
        return;
      }
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => CommunityStoryViewer(
          repository: repository,
          entries: stories,
          loadAvatar: loadAvatar,
        ),
      ),
    );
    if (context.mounted) repository.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<CommunityEntry>>{};
    for (final entry in entries) {
      if (entry.expiresAt?.isAfter(DateTime.now()) == true) {
        grouped.putIfAbsent(entry.author.id, () => []).add(entry);
      }
    }
    final own = grouped.remove(repository.userId) ?? [];
    final groups = grouped.values.toList()
      ..sort((a, b) {
        final seen = a.every((v) => v.seen) == b.every((v) => v.seen)
            ? 0
            : a.every((v) => v.seen)
            ? 1
            : -1;
        return seen != 0
            ? seen
            : b.first.createdAt.compareTo(a.first.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Campus moments',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (error != null)
              IconButton(
                tooltip: 'Retry stories',
                onPressed: retry,
                icon: const Icon(Icons.refresh),
              ),
            const CommunityQuickActions(),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final stories = index == 0 ? own : groups[index - 1];
              return StoryTile(
                repository: repository,
                entry: stories.firstOrNull,
                own: index == 0,
                identity: identity,
                loadAvatar: loadAvatar,
                unseen: index != 0 && stories.any((v) => !v.seen),
                onTap: () => _open(context, stories, own: index == 0),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CommunityQuickActions extends StatelessWidget {
  const CommunityQuickActions({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<ShellDestination>(
    tooltip: 'Open quick actions',
    icon: Icon(
      Icons.auto_awesome_outlined,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    onSelected: (destination) => context.go(destination.path),
    itemBuilder: (context) => [
      for (final destination in [
        ShellDestination.guide,
        ShellDestination.ai,
        ShellDestination.tools,
      ])
        PopupMenuItem(
          value: destination,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(destination.icon, size: 20),
            title: Text(destination.label),
          ),
        ),
    ],
  );
}

class StoryTile extends StatelessWidget {
  const StoryTile({
    super.key,
    required this.repository,
    required this.entry,
    required this.own,
    required this.identity,
    required this.loadAvatar,
    required this.unseen,
    required this.onTap,
  });
  final CommunityRepository repository;
  final CommunityEntry? entry;
  final PublicUserIdentity? identity;
  final CommunityAvatarLoader loadAvatar;
  final bool own, unseen;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = own ? 'Your story' : entry!.author.displayName;
    return Semantics(
      button: true,
      label: own && entry == null
          ? 'Add your story'
          : '$name${own
                ? ''
                : unseen
                ? ', unseen'
                : ', viewed'}',
      child: SizedBox(
        width: 94,
        child: Material(
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(18),
            ),
            side: entry == null
                ? BorderSide(color: colors.outlineVariant)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (entry case final story?)
                CommunityMedia(
                  repository: repository,
                  image: story.media.first,
                  label: 'Story preview',
                ),
              if (entry != null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Color(0xc9001021),
                      ],
                      stops: [0, .52, 1],
                    ),
                  ),
                ),
              Positioned(
                left: 9,
                top: 9,
                child: MemberAvatar(
                  identity: entry?.author ?? identity,
                  loadAvatar: loadAvatar,
                  size: 25,
                ),
              ),
              if (own)
                Align(
                  alignment: const Alignment(0, .03),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: entry == null
                        ? colors.primary
                        : Colors.black54,
                    foregroundColor: entry == null
                        ? colors.onPrimary
                        : Colors.white,
                    child: Icon(
                      entry == null ? Icons.add : Icons.play_arrow,
                      size: 16,
                    ),
                  ),
                ),
              if (unseen)
                Positioned(
                  top: 10,
                  right: 9,
                  child: Icon(Icons.circle, size: 7, color: colors.tertiary),
                ),
              Positioned(
                left: 9,
                right: 8,
                bottom: 10,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: entry == null ? colors.onSurface : Colors.white,
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityStoryViewer extends StatefulWidget {
  const CommunityStoryViewer({
    super.key,
    required this.repository,
    required this.entries,
    required this.loadAvatar,
  });
  final CommunityRepository repository;
  final List<CommunityEntry> entries;
  final CommunityAvatarLoader loadAvatar;
  @override
  State<CommunityStoryViewer> createState() => _CommunityStoryViewerState();
}

class _CommunityStoryViewerState extends State<CommunityStoryViewer>
    with SingleTickerProviderStateMixin {
  late final _progress =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _step(1);
        });
  late final _stories = [...widget.entries.reversed];
  late int _index = _first();
  late Future<CommunityEntry> _request;
  CommunityEntry? _current;
  late final AppLifecycleListener _life;
  bool _ready = false, _paused = false, _inactive = false, _busy = false;
  bool _wasPausedBeforeHold = false;
  int _generation = 0;
  bool get _canPlay =>
      !_paused && !_inactive && !MediaQuery.disableAnimationsOf(context);
  Timer? _expiry;
  int _first() {
    final index = _stories.indexWhere((v) => !v.seen);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _load();
    widget.repository.addListener(_refresh);
    _life = AppLifecycleListener(
      onStateChange: (s) {
        _inactive = s != AppLifecycleState.resumed;
        if (_inactive) {
          _progress.stop();
        } else {
          _refresh();
        }
      },
    );
  }

  void _load() {
    final generation = ++_generation;
    _expiry?.cancel();
    _progress.reset();
    _ready = false;
    _current = null;
    final id = _stories[_index].id;
    _request = widget.repository.entry(id).then((entry) {
      if (mounted && _generation == generation) {
        _current = entry;
        final expires =
            entry.expiresAt?.difference(DateTime.now()) ?? Duration.zero;
        _expiry = Timer(expires.isNegative ? Duration.zero : expires, () {
          if (mounted) _step(1);
        });
      }
      return entry;
    });
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  void _step(int delta) {
    if (!mounted) return;
    if (_index + delta < 0) {
      _progress.reset();
      if (_ready && _canPlay) _progress.forward();
      return;
    }
    if (_index + delta >= _stories.length) {
      _progress.stop();
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _index += delta;
      _load();
    });
  }

  void _imageReady(String id) {
    if (!mounted || _ready || _current?.id != id) return;
    setState(() => _ready = true);
    unawaited(
      widget.repository.mutate('entries/$id/seen').catchError((Object _) {}),
    );
    if (_canPlay) _progress.forward();
  }

  void _pause(bool value) {
    setState(() => _paused = value);
    if (value) {
      _progress.stop();
    } else if (_ready && _canPlay) {
      _progress.forward();
    }
  }

  void _hold(bool holding) {
    if (holding) _wasPausedBeforeHold = _paused;
    _pause(holding || _wasPausedBeforeHold);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    _life.dispose();
    _expiry?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: FutureBuilder<CommunityEntry>(
        key: ValueKey(_request),
        future: _request,
        builder: (context, snapshot) {
          final story = _current;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (snapshot.hasData && story != null)
                CommunityStoryFrame(
                  story: story,
                  repository: widget.repository,
                  onHold: _hold,
                  onStep: _step,
                  onReady: () => _imageReady(story.id),
                ),
              if (snapshot.hasError)
                Center(
                  child: TextButton(
                    onPressed: _refresh,
                    child: const Text(
                      'Story unavailable · Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: StoryViewerHeader(
                  progress: _progress,
                  index: _index,
                  total: _stories.length,
                  story: story,
                  loadAvatar: widget.loadAvatar,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        color: Colors.white,
                        tooltip: 'Previous story',
                        onPressed: () => _step(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        color: Colors.white,
                        tooltip: _paused ? 'Resume story' : 'Pause story',
                        onPressed: _ready ? () => _pause(!_paused) : null,
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                      ),
                      if (story != null && story.isOwn) ...[
                        IconButton(
                          color: Colors.white,
                          tooltip: 'Story viewers',
                          onPressed: () => _viewers(story),
                          icon: const Icon(Icons.people_outline),
                        ),
                        IconButton(
                          color: Colors.white,
                          tooltip: 'Delete story',
                          onPressed: () => _delete(story),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ] else if (story != null) ...[
                        IconButton(
                          color: Colors.white,
                          tooltip: story.liked ? 'Unlike story' : 'Like story',
                          onPressed: _busy || (!story.canLike && !story.liked)
                              ? null
                              : () => _like(story),
                          icon: Icon(
                            story.liked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: story.liked ? Colors.pinkAccent : null,
                          ),
                        ),
                        IconButton(
                          color: Colors.white,
                          tooltip: 'Report story',
                          onPressed: () => _report(story),
                          icon: const Icon(Icons.flag_outlined),
                        ),
                        if (MessagingScope.maybeOf(context, listen: false) !=
                            null)
                          IconButton(
                            color: Colors.white,
                            tooltip: 'Reply to story',
                            icon: const Icon(Icons.reply_rounded),
                            onPressed: () async {
                              final wasPaused = _paused;
                              _pause(true);
                              await openDirectChat(
                                context,
                                story.author.id,
                                story: story.id,
                              );
                              if (mounted) _pause(wasPaused);
                            },
                          ),
                      ],
                      IconButton(
                        color: Colors.white,
                        tooltip: 'Next story',
                        onPressed: () => _step(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _like(CommunityEntry story) async {
    setState(() {
      _busy = true;
      _current = story.withInteraction(liked: !story.liked);
    });
    try {
      await widget.repository.mutate(
        'entries/${story.id}/like',
        method: story.liked ? 'DELETE' : 'PUT',
      );
    } catch (e) {
      if (mounted && _current?.id == story.id) {
        setState(() => _current = story);
        communityFeedback(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewers(CommunityEntry story) async {
    final wasPaused = _paused;
    _pause(true);
    await communityMenu<void>(
      context,
      child: StoryViewers(
        repository: widget.repository,
        story: story,
        loadAvatar: widget.loadAvatar,
      ),
    );
    if (mounted) _pause(wasPaused);
  }

  Future<void> _delete(CommunityEntry story) async {
    _pause(true);
    if (await communityConfirm(
          context,
          'Delete this story?',
          'This removes the story immediately.',
        ) &&
        mounted) {
      await communityCommand(context, () async {
        await widget.repository.mutate('entries/${story.id}', method: 'DELETE');
        if (mounted) Navigator.pop(context);
      });
    } else if (mounted) {
      _pause(false);
    }
  }

  Future<void> _report(CommunityEntry story) async {
    final wasPaused = _paused;
    _pause(true);
    await communityMenu<void>(
      context,
      child: CommunityReportSheet(
        repository: widget.repository,
        kind: 'story',
        id: story.id,
      ),
    );
    if (mounted) _pause(wasPaused);
  }
}

class CommunityStoryFrame extends StatelessWidget {
  const CommunityStoryFrame({
    super.key,
    required this.story,
    required this.repository,
    required this.onHold,
    required this.onStep,
    required this.onReady,
  });

  final CommunityEntry story;
  final CommunityRepository repository;
  final ValueChanged<bool> onHold;
  final ValueChanged<int> onStep;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 69, 8, 58),
    child: LayoutBuilder(
      builder: (context, box) => Center(
        child: SizedBox(
          width: math.min(box.maxWidth, box.maxHeight * 9 / 16),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: GestureDetector(
                onLongPressStart: (_) => onHold(true),
                onLongPressEnd: (_) => onHold(false),
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity != 0) onStep(velocity < 0 ? 1 : -1);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CommunityMedia(
                      key: ValueKey(story.id),
                      repository: repository,
                      image: story.media.first,
                      full: true,
                      label: 'Story by ${story.author.displayName}',
                      onReady: onReady,
                    ),
                    if (story.caption.isNotEmpty)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: StoryOverlay(text: story.caption),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class StoryViewerHeader extends StatelessWidget {
  const StoryViewerHeader({
    super.key,
    required this.progress,
    required this.index,
    required this.total,
    required this.story,
    required this.loadAvatar,
  });
  final Animation<double> progress;
  final int index, total;
  final CommunityEntry? story;
  final CommunityAvatarLoader loadAvatar;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.transparent],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedBuilder(
                      animation: progress,
                      builder: (context, _) => LinearProgressIndicator(
                        minHeight: 3,
                        value: i < index
                            ? 1
                            : i == index
                            ? progress.value
                            : 0,
                        color: Colors.white,
                        backgroundColor: Colors.white38,
                        semanticsLabel: i == index
                            ? 'Story ${i + 1} of $total'
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              if (story != null) ...[
                MemberAvatar(
                  identity: story!.author,
                  loadAvatar: loadAvatar,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    story!.author.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              IconButton(
                color: Colors.white,
                tooltip: 'Close story',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class StoryViewers extends StatefulWidget {
  const StoryViewers({
    super.key,
    required this.repository,
    required this.story,
    required this.loadAvatar,
  });
  final CommunityRepository repository;
  final CommunityEntry story;
  final CommunityAvatarLoader loadAvatar;
  @override
  State<StoryViewers> createState() => _StoryViewersState();
}

class _StoryViewersState extends State<StoryViewers> {
  List<CommunityJson> _items = [];
  String? _next;
  bool _busy = false, _failed = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final page = await widget.repository.page(
        'stories/${widget.story.id}/viewers',
        (value) => value,
        cursor: _next,
      );
      if (mounted) {
        setState(() {
          _items = [..._items, ...page.items];
          _next = page.next;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CommunityMenuBody(
    title: 'Story viewers',
    children: [
      for (final row in _items)
        CommunityAuthor(
          author: PublicUserIdentity.fromJson(row['member']),
          loadAvatar: widget.loadAvatar,
          subtitle: row['liked'] == true ? 'Liked your story' : null,
        ),
      if (_busy) const LinearProgressIndicator(),
      if (_failed || _next != null)
        TextButton(
          onPressed: _busy ? null : _load,
          child: Text(_failed ? 'Retry' : 'Load more'),
        ),
      if (!_busy && !_failed && _items.isEmpty)
        const ListTile(title: Text('No viewers yet')),
    ],
  );
}

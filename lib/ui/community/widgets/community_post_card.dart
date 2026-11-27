import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/themes/app_tokens.dart';
import 'community_author.dart';
import 'community_media.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.repository,
    required this.loadAvatar,
    required this.like,
    required this.save,
    required this.comment,
    required this.menu,
    required this.share,
    this.onExpose,
    this.detail = false,
    this.initialPhoto = 0,
    this.likeBusy = false,
    this.saveBusy = false,
  });
  final CommunityEntry post;
  final CommunityRepository repository;
  final CommunityAvatarLoader loadAvatar;
  final VoidCallback like, save, comment, menu, share;
  final VoidCallback? onExpose;
  final bool detail, likeBusy, saveBusy;
  final int initialPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CommunityExposure(
      onExpose: onExpose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CommunityAuthor(
                  author: post.author,
                  loadAvatar: loadAvatar,
                  size: 35,
                  subtitle:
                      '@${post.author.username}  ·  ${DateFormat.MMMd().format(post.createdAt.toLocal())}',
                ),
              ),
              IconButton(
                tooltip: 'Post options',
                onPressed: menu,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (post.media.isNotEmpty)
            CommunityGallery(
              post: post,
              repository: repository,
              detail: detail,
              initialPhoto: initialPhoto,
              like: !post.liked && !post.archived && !likeBusy ? like : null,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CommunityPostAction(
                      label: post.liked ? 'Unlike post' : 'Like post',
                      icon: post.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post.liked ? scheme.error : null,
                      onPressed: likeBusy || post.archived ? null : like,
                      count: post.likeCount,
                    ),
                    CommunityPostAction(
                      label: 'Comments',
                      onPressed: comment,
                      icon: Icons.chat_bubble_outline_rounded,
                      count: post.commentCount,
                    ),
                    IconButton(
                      tooltip: 'Share post',
                      onPressed: post.archived ? null : share,
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: post.saved ? 'Remove from saved' : 'Save post',
                isSelected: post.saved,
                onPressed: saveBusy || post.archived ? null : save,
                icon: const Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(
                  Icons.bookmark_rounded,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          if (post.caption.isNotEmpty)
            CommunityCaption(text: post.caption, expanded: detail),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}

class CommunityPostAction extends StatelessWidget {
  const CommunityPostAction({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    this.color,
    this.size = 23,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final int count;
  final Color? color;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: count == 0 ? label : '$label, $count',
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      color: color,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(
              NumberFormat.compact().format(count),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ],
      ),
    ),
  );
}

class CommunityCaption extends StatefulWidget {
  const CommunityCaption({
    super.key,
    required this.text,
    required this.expanded,
  });

  final String text;
  final bool expanded;

  @override
  State<CommunityCaption> createState() => _CommunityCaptionState();
}

class _CommunityCaptionState extends State<CommunityCaption> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final measurer = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 3,
          )..layout(maxWidth: constraints.maxWidth);
          final canExpand = !widget.expanded && measurer.didExceedMaxLines;
          measurer.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: style,
                maxLines: canExpand && !_showAll ? 3 : null,
                overflow: canExpand && !_showAll ? TextOverflow.ellipsis : null,
              ),
              if (canExpand)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Show less' : 'Read more'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CommunityGallery extends StatefulWidget {
  const CommunityGallery({
    super.key,
    required this.post,
    required this.repository,
    required this.detail,
    this.initialPhoto = 0,
    this.like,
  });
  final CommunityEntry post;
  final CommunityRepository repository;
  final bool detail;
  final int initialPhoto;
  final VoidCallback? like;
  @override
  State<CommunityGallery> createState() => _CommunityGalleryState();
}

class _CommunityGalleryState extends State<CommunityGallery> {
  late int _index = widget.initialPhoto.clamp(0, widget.post.media.length - 1);
  late final _pages = PageController(initialPage: _index);
  bool _showLike = false;
  Timer? _feedback;

  void _doubleTap() {
    widget.like?.call();
    if (widget.like == null || MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _showLike = true);
    _feedback?.cancel();
    _pages.dispose();
    _feedback = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _showLike = false);
    });
  }

  @override
  void dispose() {
    _feedback?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommunityGallery old) {
    super.didUpdateWidget(old);
    if (_index >= widget.post.media.length) _index = 0;
  }

  void _open(BuildContext context, CommunityImage image) {
    if (!widget.detail) {
      context.push(
        Uri(
          path: '/posts/${widget.post.id}',
          queryParameters: {if (_index > 0) 'photo': '$_index'},
        ).toString(),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: CommunityMedia(
                  repository: widget.repository,
                  image: image,
                  full: true,
                  fit: BoxFit.contain,
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  color: Colors.white,
                  tooltip: 'Close photo',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = widget.post.media;
    final first = media.first;
    final ratio = (first.width / first.height).clamp(.8, 1.85);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              allowImplicitScrolling: true,
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _open(context, media[i]),
                onDoubleTap: widget.like == null ? null : _doubleTap,
                child: ColoredBox(
                  color: scheme.surfaceContainerLow,
                  child: CommunityMedia(
                    repository: widget.repository,
                    image: media[i],
                    full: widget.detail,
                    fit:
                        widget.detail ||
                            ((media[i].width / media[i].height) - ratio).abs() >
                                .45
                        ? BoxFit.contain
                        : BoxFit.cover,
                    label: 'Post image ${i + 1} of ${media.length}',
                  ),
                ),
              ),
            ),
            if (media.length > 1)
              Positioned(
                right: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .64),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${_index + 1}/${media.length}',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (_showLike)
              const IgnorePointer(
                child: ExcludeSemantics(
                  child: Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 56,
                      shadows: [Shadow(blurRadius: 20)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityExposure extends StatefulWidget {
  const CommunityExposure({super.key, required this.child, this.onExpose});
  final Widget child;
  final VoidCallback? onExpose;
  @override
  State<CommunityExposure> createState() => _CommunityExposureState();
}

class _CommunityExposureState extends State<CommunityExposure> {
  Timer? _timer;
  int _visibleTicks = 0;
  bool _sent = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch();
  }

  @override
  void didUpdateWidget(CommunityExposure old) {
    super.didUpdateWidget(old);
    if (old.onExpose == null && widget.onExpose != null) _watch();
  }

  void _watch() {
    _timer?.cancel();
    if (_sent ||
        widget.onExpose == null ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || ModalRoute.isCurrentOf(context) == false) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final offset = box.localToGlobal(Offset.zero);
      final screen = MediaQuery.sizeOf(context).height;
      final fraction =
          ((offset.dy + box.size.height).clamp(0, screen) -
              offset.dy.clamp(0, screen)) /
          box.size.height;
      _visibleTicks = fraction >= .55 ? _visibleTicks + 1 : 0;
      if (_visibleTicks >= 2) {
        _sent = true;
        _timer?.cancel();
        widget.onExpose?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

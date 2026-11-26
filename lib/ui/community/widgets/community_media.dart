import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/loading/skeleton.dart';

class CommunityMedia extends StatefulWidget {
  const CommunityMedia({
    super.key,
    required this.repository,
    required this.image,
    this.full = false,
    this.fit = BoxFit.cover,
    this.label = 'Community photo',
    this.onReady,
  });
  final CommunityRepository repository;
  final CommunityImage image;
  final bool full;
  final BoxFit fit;
  final String label;
  final VoidCallback? onReady;
  @override
  State<CommunityMedia> createState() => _CommunityMediaState();
}

class _CommunityMediaState extends State<CommunityMedia> {
  late Future<Uint8List> _bytes;
  int _request = 0;
  int? _decoded;
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(CommunityMedia old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) {
      old.repository.removeListener(_reload);
      widget.repository.addListener(_reload);
    }
    if (old.image.id != widget.image.id ||
        old.full != widget.full ||
        old.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    _request++;
    _bytes = widget.repository.image(widget.image.id, full: widget.full);
  }

  void _imageDecoded() {
    if (widget.onReady == null || _decoded == _request) return;
    final request = _decoded = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _request == request) widget.onReady?.call();
    });
  }

  void _reload() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    key: ValueKey(_request),
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        return LayoutBuilder(
          builder: (context, box) {
            final width = widget.fit == BoxFit.cover
                ? math.max(
                    box.maxWidth,
                    box.maxHeight * widget.image.width / widget.image.height,
                  )
                : box.maxWidth;
            final physical = (width * MediaQuery.devicePixelRatioOf(context))
                .clamp(1, widget.full ? 1600 : 480)
                .round();
            return Image.memory(
              snapshot.data!,
              fit: widget.fit,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: physical,
              semanticLabel: widget.label,
              frameBuilder: (context, child, frame, synchronous) {
                if (frame != null || synchronous) _imageDecoded();
                return child;
              },
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        );
      }
      if (snapshot.hasError) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Center(
            child: IconButton(
              tooltip: 'Retry photo',
              onPressed: _reload,
              icon: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      }
      return const SkeletonBox(height: double.infinity, radius: 0);
    },
  );
}

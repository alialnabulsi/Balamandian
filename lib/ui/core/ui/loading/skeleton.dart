import 'package:flutter/material.dart';

/// One gradient and ticker per composition, following Flutter's shimmer recipe.
/// Descendants are decorative, with a single loading announcement.
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child, this.label = 'Loading'});
  final Widget child;
  final String label;
  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-3 + _controller.value * 6, -.3),
              end: Alignment(-1 + _controller.value * 6, .3),
              colors: [
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerLow,
                scheme.surfaceContainerHighest,
              ],
            ).createShader(rect),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, this.width, this.height = 14});
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: height);
}

class SkeletonAvatar extends StatelessWidget {
  const SkeletonAvatar({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: size, height: size, radius: size / 2);
}

class SkeletonImage extends StatelessWidget {
  const SkeletonImage({super.key, this.aspectRatio = 1.8});
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: const SkeletonBox(height: double.infinity, radius: 20),
  );
}

class SkeletonMemberRow extends StatelessWidget {
  const SkeletonMemberRow({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        SkeletonAvatar(),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonText(width: 120),
              SizedBox(height: 8),
              SkeletonText(width: 90, height: 10),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 92, height: 42, radius: 14),
      ],
    ),
  );
}

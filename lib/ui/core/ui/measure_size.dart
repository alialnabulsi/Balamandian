import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports laid-out dimensions without changing the child's constraints.
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, required super.child});
  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _MeasureSize).onChange = onChange;
  }
}

class _MeasureSize extends RenderProxyBox {
  _MeasureSize(this.onChange);
  ValueChanged<Size> onChange;
  Size? _previous;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _previous) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onChange(measured);
    });
  }
}

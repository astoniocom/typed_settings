import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// The current value of a setting at the end of a tile, in the primary
/// color.
///
/// Takes at most half the width it is offered, so a long value leaves the
/// tile's title its room, and ends in an ellipsis when it does not fit.
/// Inside a `Row` it needs a `Flexible` to be offered a bounded width.
class ValueChip extends StatelessWidget {
  /// Creates a chip that shows [value].
  const ValueChip({
    required this.value,
    super.key,
  });

  /// The text the chip shows.
  final String value;

  @override
  Widget build(BuildContext context) {
    return _HalfWidth(
      child: Text(
        value,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Lays out [child] in at most half the width it is offered.
///
/// A render object rather than a `LayoutBuilder`, so a tile still answers
/// intrinsic size queries (`AlertDialog`, `IntrinsicHeight`).
class _HalfWidth extends SingleChildRenderObjectWidget {
  const _HalfWidth({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHalfWidth();
}

class _RenderHalfWidth extends RenderProxyBox {
  static BoxConstraints _halve(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return constraints;
    return constraints.copyWith(maxWidth: math.max(constraints.minWidth, constraints.maxWidth / 2));
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(_halve(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(child!.getDryLayout(_halve(constraints)));

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child!.getDryBaseline(_halve(constraints), baseline);
}

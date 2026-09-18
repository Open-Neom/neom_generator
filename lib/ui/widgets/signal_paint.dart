import 'package:flutter/material.dart';

import 'visual_animation.dart';

/// Paint-only signal refresh. Audio updates never rebuild this widget tree.
///
/// Capture reactive configuration (including [active]) outside [builder], e.g.
/// in an Obx. The builder runs only when widget configuration changes, while
/// the supplied repaint clock is suspended with route/app visibility.
class SignalPaint extends StatelessWidget {
  const SignalPaint({
    super.key,
    required this.active,
    required this.builder,
    this.size = Size.zero,
    this.isComplex = false,
    this.child,
  });

  final bool active;
  final CustomPainter Function(Listenable repaint) builder;
  final Size size;
  final bool isComplex;
  final Widget? child;

  @override
  Widget build(BuildContext context) => VisualAnimation(
    active: active,
    child: child,
    builder: (context, clock, child) => RepaintBoundary(
      child: CustomPaint(
        painter: builder(clock),
        size: size,
        isComplex: isComplex,
        willChange: active,
        child: child,
      ),
    ),
  );
}

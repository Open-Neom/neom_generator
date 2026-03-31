import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../engine/neom_frequency_painter_engine.dart';

/// A "living circuit" painter that traces sine waves along the borders
/// of registered child widgets, connecting them with flowing current.
///
/// The wave travels through each widget's perimeter and jumps between
/// them via connecting traces, creating the illusion of electrical
/// current flowing through a circuit board.
///
/// Audio-reactive parameters modulate the visual:
/// - Frequency → wave density (cycles per perimeter unit)
/// - Amplitude → wave displacement from edge
/// - Beat/binaural → interference pattern between L/R traces
/// - Pan/spatial → directional glow bias (left vs right brightness)
/// - Breath → pulsing intensity
/// - Neuro state → color temperature
class CircuitWavePainter extends CustomPainter {
  final List<Rect> childBounds;
  final NeomFrequencyPainterEngine engine;
  final double time;
  final Color primaryColor;
  final Color secondaryColor;

  CircuitWavePainter({
    required this.childBounds,
    required this.engine,
    required this.time,
    this.primaryColor = const Color(0xFF00BCD4),
    this.secondaryColor = const Color(0xFFAB47BC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (childBounds.isEmpty) return;

    // Audio-reactive parameters
    final freq = engine.visualPhase * 15 + 4; // wave density
    final amp = 6.0 + engine.glowIntensity * 8.0; // 6-14px displacement
    final beat = engine.binauralPhase;
    final breath = engine.breathPulse;
    final panBias = engine.waveHeight; // 0-1, spatial position

    // Build complete circuit path through all child perimeters + connections
    final segments = _buildCircuitSegments(size);
    if (segments.isEmpty) return;

    // Total path length for continuous phase
    double totalLen = 0;
    for (final seg in segments) {
      totalLen += seg.length;
    }
    if (totalLen <= 0) return;

    // Draw the two traces (L and R channels)
    _drawTrace(canvas, segments, totalLen, freq, amp, beat, breath, panBias,
        primaryColor, time * 3, 1.0);
    _drawTrace(canvas, segments, totalLen, freq, amp * 0.7, beat, breath, panBias,
        secondaryColor, time * 3 + beat, 0.6);

    // Draw node dots at connection points between widgets
    _drawNodes(canvas, segments);
  }

  /// Build circuit segments: each child's perimeter + connections between them.
  List<_CircuitSegment> _buildCircuitSegments(Size canvasSize) {
    final segments = <_CircuitSegment>[];

    for (int i = 0; i < childBounds.length; i++) {
      final rect = childBounds[i];

      // Add the perimeter of this child
      segments.add(_CircuitSegment(
        type: _SegmentType.perimeter,
        rect: rect,
        length: 2 * (rect.width + rect.height),
      ));

      // Add connection trace to next child (if any)
      // Uses L-shaped orthogonal path (like a PCB trace) instead of diagonal
      if (i < childBounds.length - 1) {
        final next = childBounds[i + 1];
        final fromPt = Offset(rect.center.dx, rect.bottom);
        final midPt = Offset(rect.center.dx, next.top);
        final toPt = Offset(next.center.dx, next.top);

        // Vertical segment (down from current)
        final vLen = (midPt - fromPt).distance;
        if (vLen > 1) {
          segments.add(_CircuitSegment(
            type: _SegmentType.connection,
            from: fromPt,
            to: midPt,
            length: vLen,
          ));
        }

        // Horizontal segment (across to next, if needed)
        final hLen = (toPt - midPt).distance;
        if (hLen > 1) {
          segments.add(_CircuitSegment(
            type: _SegmentType.connection,
            from: midPt,
            to: toPt,
            length: hLen,
          ));
        }
      }
    }

    return segments;
  }

  void _drawTrace(
    Canvas canvas,
    List<_CircuitSegment> segments,
    double totalLen,
    double freq,
    double amp,
    double beat,
    double breath,
    double panBias,
    Color color,
    double timeOffset,
    double opacity,
  ) {
    final path = Path();
    double accumulated = 0;
    bool first = true;

    const sampleStep = 3.0; // pixels between samples

    for (final seg in segments) {
      final steps = (seg.length / sampleStep).ceil();

      for (int s = 0; s <= steps; s++) {
        final localT = s / steps; // 0..1 within this segment
        final globalT = (accumulated + localT * seg.length) / totalLen;

        // Position on the circuit path
        final pos = seg.positionAt(localT);
        // Normal direction (perpendicular)
        final normal = seg.normalAt(localT);

        // Wave displacement
        final phase = globalT * freq * 2 * pi + timeOffset;
        final breathMod = 0.7 + breath * 0.3;
        final displacement = sin(phase) * amp * breathMod;

        // Apply spatial bias: slightly different amplitude on left vs right
        final spatialMod = pos.dx < (childBounds.isNotEmpty ? childBounds.first.center.dx : 0)
            ? 1.0 + panBias * 0.3
            : 1.0 - panBias * 0.3;

        final point = Offset(
          pos.dx + normal.dx * displacement * spatialMod,
          pos.dy + normal.dy * displacement * spatialMod,
        );

        if (first) {
          path.moveTo(point.dx, point.dy);
          first = false;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      accumulated += seg.length;
    }

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withAlpha((20 * opacity).round())
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Main trace
    final paint = Paint()
      ..color = color.withAlpha((150 * opacity).round())
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  void _drawNodes(Canvas canvas, List<_CircuitSegment> segments) {
    for (final seg in segments) {
      if (seg.type == _SegmentType.connection) {
        // Draw small dots at connection endpoints
        final dotPaint = Paint()
          ..color = primaryColor.withAlpha(80);
        canvas.drawCircle(seg.from!, 2.5, dotPaint);
        canvas.drawCircle(seg.to!, 2.5, dotPaint);

        // Glow on nodes
        final glowPaint = Paint()
          ..color = primaryColor.withAlpha(20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(seg.from!, 5, glowPaint);
        canvas.drawCircle(seg.to!, 5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircuitWavePainter old) => true;
}

enum _SegmentType { perimeter, connection }

class _CircuitSegment {
  final _SegmentType type;
  final Rect? rect; // for perimeter segments
  final Offset? from, to; // for connection segments
  final double length;

  _CircuitSegment({
    required this.type,
    this.rect,
    this.from,
    this.to,
    required this.length,
  });

  /// Get position at t (0..1) along this segment.
  Offset positionAt(double t) {
    if (type == _SegmentType.connection) {
      return Offset.lerp(from!, to!, t)!;
    }

    // Perimeter: clockwise from top-left
    final r = rect!;
    final w = r.width;
    final h = r.height;
    final perim = 2 * (w + h);
    final d = t * perim;

    if (d <= w) {
      return Offset(r.left + d, r.top);
    } else if (d <= w + h) {
      return Offset(r.right, r.top + (d - w));
    } else if (d <= 2 * w + h) {
      return Offset(r.right - (d - w - h), r.bottom);
    } else {
      return Offset(r.left, r.bottom - (d - 2 * w - h));
    }
  }

  /// Normal vector at t (outward for perimeters, perpendicular for connections).
  Offset normalAt(double t) {
    if (type == _SegmentType.connection) {
      final dir = (to! - from!);
      final normalized = dir / dir.distance;
      // Perpendicular (rotate 90°)
      return Offset(-normalized.dy, normalized.dx);
    }

    final r = rect!;
    final w = r.width;
    final h = r.height;
    final perim = 2 * (w + h);
    final d = t * perim;

    if (d <= w) return const Offset(0, -1);
    if (d <= w + h) return const Offset(1, 0);
    if (d <= 2 * w + h) return const Offset(0, 1);
    return const Offset(-1, 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a widget tree and paints a circuit wave around registered children.
///
/// Children register themselves by wrapping with [CircuitNode] which uses
/// a [GlobalKey] to report its bounds after layout.
///
/// Usage:
/// ```dart
/// CircuitWaveOverlay(
///   engine: painterEngine,
///   isActive: controller.isPlaying.value,
///   child: Column(
///     children: [
///       CircuitNode(child: _buildOscilloscope()),
///       CircuitNode(child: _buildFreqDisplay()),
///       CircuitNode(child: _buildSliders()),
///     ],
///   ),
/// )
/// ```
class CircuitWaveOverlay extends StatefulWidget {
  final NeomFrequencyPainterEngine engine;
  final bool isActive;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Widget child;

  const CircuitWaveOverlay({
    super.key,
    required this.engine,
    required this.isActive,
    this.primaryColor,
    this.secondaryColor,
    required this.child,
  });

  @override
  State<CircuitWaveOverlay> createState() => CircuitWaveOverlayState();

  /// Access the overlay state to register nodes.
  static CircuitWaveOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<CircuitWaveOverlayState>();
  }
}

class CircuitWaveOverlayState extends State<CircuitWaveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final List<GlobalKey> _nodeKeys = [];
  List<Rect> _nodeBounds = [];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Collect bounds after first frame
    _anim.addListener(_updateBounds);
  }

  int _frameCount = 0;

  void _updateBounds() {
    // Only recalculate every 30 frames to save CPU
    _frameCount++;
    if (_frameCount % 30 != 0) return;

    final bounds = <Rect>[];
    final myBox = context.findRenderObject() as RenderBox?;
    if (myBox == null) return;

    for (final key in _nodeKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;

      final topLeft = box.localToGlobal(Offset.zero, ancestor: myBox);
      bounds.add(topLeft & box.size);
    }

    if (bounds.length != _nodeBounds.length || bounds.isNotEmpty) {
      _nodeBounds = bounds;
    }
  }

  /// Register a child node's key.
  void registerNode(GlobalKey key) {
    if (!_nodeKeys.contains(key)) {
      _nodeKeys.add(key);
    }
  }

  /// Unregister a child node.
  void unregisterNode(GlobalKey key) {
    _nodeKeys.remove(key);
  }

  @override
  void dispose() {
    _anim.removeListener(_updateBounds);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => CustomPaint(
        foregroundPainter: _nodeBounds.length >= 2
            ? CircuitWavePainter(
                childBounds: _nodeBounds,
                engine: widget.engine,
                time: _anim.value * 2 * pi,
                primaryColor: widget.primaryColor ?? const Color(0xFF00BCD4),
                secondaryColor: widget.secondaryColor ?? const Color(0xFFAB47BC),
              )
            : null,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Marks a widget as a node in the circuit.
/// Must be a descendant of [CircuitWaveOverlay].
class CircuitNode extends StatefulWidget {
  final Widget child;

  CircuitNode({super.key, required this.child});

  final GlobalKey _nodeKey = GlobalKey();

  @override
  State<CircuitNode> createState() => _CircuitNodeState();
}

class _CircuitNodeState extends State<CircuitNode> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CircuitWaveOverlay.of(context)?.registerNode(widget._nodeKey);
    });
  }

  @override
  void dispose() {
    CircuitWaveOverlay.of(context)?.unregisterNode(widget._nodeKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget._nodeKey,
      child: widget.child,
    );
  }
}

import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';
import '../widgets/visual_animation.dart';

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
  final List<Rect> _childBounds;
  final ValueNotifier<List<Rect>>? bounds;

  /// Visible paint regions for nodes inside independently scrolling columns.
  final ValueNotifier<List<Rect>>? clips;
  List<Rect> get childBounds => bounds?.value ?? _childBounds;
  final NeomFrequencyPainterEngine engine;
  final double _time;
  final VisualAnimationClock? clock;
  double get time => clock == null ? _time : clock!.value * 2 * pi;
  final Color primaryColor;
  final Color secondaryColor;

  CircuitWavePainter({
    List<Rect> childBounds = const [],
    this.bounds,
    this.clips,
    required this.engine,
    double time = 0,
    this.clock,
    this.primaryColor = const Color(0xFF00BCD4),
    this.secondaryColor = const Color(0xFFAB47BC),
  }) : _childBounds = List.unmodifiable(childBounds),
       _time = time,
       super(repaint: Listenable.merge([clock, bounds, clips]));

  List<Rect>? _cachedBounds;
  List<Rect>? _cachedClips;
  Size? _cachedSize;
  List<_CircuitSegment> _segments = [];
  double _totalLength = 0;
  Path _paintRegion = Path();

  // Keep transparent controls clear, including the glow behind the traces.
  static const _borderBand = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (childBounds.isEmpty || size.isEmpty || !size.isFinite) return;

    // Audio-reactive parameters
    // Density follows pitch, not the continuously wrapping audio phase.
    final freq = 4.0 + engine.waveStretch * 2.0;
    final amp = 3.0 + engine.glowIntensity * 2.0;
    final beat = engine.binauralPhase;
    final breath = engine.breathPulse;
    final panBias = engine.waveHeight; // 0-1, spatial position

    // Build complete circuit path through all child perimeters + connections
    if (_cachedSize != size ||
        !listEquals(_cachedBounds, childBounds) ||
        !listEquals(_cachedClips, clips?.value)) {
      _cachedSize = size;
      _cachedBounds = List.of(childBounds);
      _cachedClips = clips == null ? null : List.of(clips!.value);
      _segments = _buildCircuitSegments(size);
      _totalLength = _segments.fold(
        0,
        (total, segment) => total + segment.length,
      );
      _paintRegion = Path()..addRect(Offset.zero & size);
      for (final rect in childBounds) {
        if (!rect.isFinite || rect.isEmpty) continue;
        final interior = rect.deflate(_borderBand);
        if (!interior.isEmpty) {
          _paintRegion = Path.combine(
            PathOperation.difference,
            _paintRegion,
            Path()..addRect(interior),
          );
        }
      }
    }
    final segments = _segments;
    if (segments.isEmpty) return;

    // Total path length for continuous phase
    final totalLen = _totalLength;
    if (totalLen <= 0) return;
    canvas.save();
    canvas.clipPath(_paintRegion);

    // Draw the two traces (L and R channels)
    _drawTrace(
      canvas,
      segments,
      totalLen,
      freq,
      amp,
      breath,
      panBias,
      primaryColor,
      time * 3,
      1.0,
    );
    _drawTrace(
      canvas,
      segments,
      totalLen,
      freq,
      amp * 0.7,
      breath,
      panBias,
      secondaryColor,
      time * 3 + beat,
      0.6,
    );

    // Draw node dots at connection points between widgets
    _drawNodes(canvas, segments);
    canvas.restore();
  }

  /// Build circuit segments: each child's perimeter + connections between them.
  List<_CircuitSegment> _buildCircuitSegments(Size canvasSize) {
    final segments = <_CircuitSegment>[];

    final viewport = Offset.zero & canvasSize;
    final nodes = <({Rect rect, Rect clip})>[];
    final seen = <Rect>{};
    for (var i = 0; i < childBounds.length; i++) {
      final rect = childBounds[i];
      if (!rect.isFinite || rect.isEmpty || !seen.add(rect)) continue;
      final nodeClip = clips != null && i < clips!.value.length
          ? viewport.intersect(clips!.value[i])
          : viewport;
      if (!nodeClip.isFinite || nodeClip.isEmpty || !rect.overlaps(nodeClip)) {
        continue;
      }
      nodes.add((rect: rect, clip: nodeClip));
      segments.add(_CircuitSegment.perimeter(rect, nodeClip));
    }

    for (var i = 0; i + 1 < nodes.length; i++) {
      final node = nodes[i];
      final next = nodes[i + 1];
      // Registration order is not a route: different columns may have an
      // entire unregistered panel between them. Only bridge a short shared
      // gutter, and never bridge independent scroll viewports.
      if (node.clip != next.clip) continue;
      final connection = _gapConnection(node.rect, next.rect, node.clip);
      if (connection == null) continue;
      final corridor = Rect.fromPoints(
        connection.points.first,
        connection.points.last,
      ).inflate(1);
      final obstructed = childBounds.any(
        (rect) =>
            rect.isFinite &&
            rect != node.rect &&
            rect != next.rect &&
            rect.deflate(1).overlaps(corridor),
      );
      if (!obstructed) segments.add(connection);
    }

    return segments;
  }

  _CircuitSegment? _gapConnection(Rect first, Rect second, Rect clip) {
    const maxGap = 24.0;
    final left = max(first.left, second.left);
    final right = min(first.right, second.right);
    if (right > left) {
      final upper = first.top < second.top ? first : second;
      final lower = upper == first ? second : first;
      final gap = lower.top - upper.bottom;
      if (gap > 1 && gap <= maxGap) {
        final x = (left + right) / 2;
        return _CircuitSegment.connection(
          Offset(x, upper.bottom),
          Offset(x, lower.top),
          clip,
        );
      }
    }
    final top = max(first.top, second.top);
    final bottom = min(first.bottom, second.bottom);
    if (bottom > top) {
      final leading = first.left < second.left ? first : second;
      final trailing = leading == first ? second : first;
      final gap = trailing.left - leading.right;
      if (gap > 1 && gap <= maxGap) {
        final y = (top + bottom) / 2;
        return _CircuitSegment.connection(
          Offset(leading.right, y),
          Offset(trailing.left, y),
          clip,
        );
      }
    }
    return null;
  }

  void _drawTrace(
    Canvas canvas,
    List<_CircuitSegment> segments,
    double totalLen,
    double freq,
    double amp,
    double breath,
    double panBias,
    Color color,
    double timeOffset,
    double opacity,
  ) {
    double accumulated = 0;

    // Web canvas is slower — use coarser sampling to avoid jank
    const sampleStep = 8.0;
    // At least eight samples per cycle keeps audio phase from aliasing into
    // a dense zigzag when the phase/frequency is high.
    final cycles = freq.clamp(1.0, max(1.0, totalLen / (sampleStep * 8)));

    for (final seg in segments) {
      // Each perimeter/bridge owns its contour. Joining the end of one
      // perimeter to a bridge's start draws a diagonal through the control.
      final path = Path();
      double edgeStart = accumulated;
      for (var edge = 0; edge + 1 < seg.points.length; edge++) {
        final from = seg.points[edge];
        final to = seg.points[edge + 1];
        final delta = to - from;
        final length = delta.distance;
        final normal = Offset(-delta.dy, delta.dx) / length;
        final steps = max(1, (length / sampleStep).ceil());
        for (var s = 0; s <= steps; s++) {
          final localT = s / steps;
          final pos = Offset.lerp(from, to, localT)!;
          final phase =
              (edgeStart + localT * length) / totalLen * cycles * 2 * pi +
              timeOffset;
          // Pin every corner and bridge endpoint to the actual edge. This
          // closes the loop even at fractional wave densities.
          final taper = min(1.0, min(localT, 1 - localT) * length / 12);
          final spatialMod = pos.dx < childBounds.first.center.dx
              ? 1.0 + panBias * 0.3
              : 1.0 - panBias * 0.3;
          final wave = seg.isPerimeter
              ? (sin(phase) + 1) * 0.5
              : sin(phase) * 0.35;
          final displacement =
              wave * amp * (0.7 + breath * 0.3) * spatialMod * taper;
          final point = pos + normal * displacement;
          if (edge == 0 && s == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        edgeStart += length;
      }
      if (seg.isPerimeter) path.close();
      accumulated += seg.length;
      canvas.save();
      canvas.clipRect(seg.clip);
      // Glow layer — skip blur on web (expensive canvas operation)
      if (!kIsWeb) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withAlpha((20 * opacity).round())
            ..strokeWidth = 6
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withAlpha((kIsWeb ? 180 : 150) * opacity ~/ 1)
          ..strokeWidth = kIsWeb ? 2.0 : 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  void _drawNodes(Canvas canvas, List<_CircuitSegment> segments) {
    final dotPaint = Paint()..color = primaryColor.withAlpha(80);
    final glowPaint = kIsWeb
        ? null
        : (Paint()
            ..color = primaryColor.withAlpha(20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    final drawn = <Offset>{};
    for (final seg in segments) {
      if (!seg.isPerimeter) {
        canvas.save();
        canvas.clipRect(seg.clip);
        for (final point in [seg.points.first, seg.points.last]) {
          if (!drawn.add(point)) continue;
          canvas.drawCircle(point, 2.5, dotPaint);

          if (glowPaint != null) canvas.drawCircle(point, 5, glowPaint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircuitWavePainter old) =>
      clock == null ||
      engine != old.engine ||
      clock != old.clock ||
      _time != old._time ||
      bounds != old.bounds ||
      clips != old.clips ||
      !listEquals(_childBounds, old._childBounds) ||
      primaryColor != old.primaryColor ||
      secondaryColor != old.secondaryColor;
}

class _CircuitSegment {
  final bool isPerimeter;
  final List<Offset> points;
  final Rect clip;
  final double length;

  _CircuitSegment.perimeter(Rect rect, this.clip)
    : isPerimeter = true,
      points = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
        rect.topLeft,
      ],
      length = 2 * (rect.width + rect.height);

  _CircuitSegment.connection(Offset from, Offset to, this.clip)
    : isPerimeter = false,
      points = [from, to],
      length = (to - from).distance;
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

class CircuitWaveOverlayState extends State<CircuitWaveOverlay> {
  final List<GlobalKey> _nodeKeys = [];
  final _nodeBounds = ValueNotifier<List<Rect>>(const []);
  final _nodeClips = ValueNotifier<List<Rect>>(const []);
  VisualAnimationClock? _clock;
  Duration _lastMeasurement = Duration.zero;
  bool _boundsScheduled = false;
  bool _disposed = false;

  void _bindClock(VisualAnimationClock clock) {
    if (_clock == clock) return;
    _clock?.removeListener(_onVisualFrame);
    _clock = clock..addListener(_onVisualFrame);
  }

  void _onVisualFrame() {
    // Geometry is layout work, not frame work. Scroll/resize also request a
    // post-layout measurement; this catches independently animated children.
    if (_clock!.elapsed - _lastMeasurement <
        const Duration(milliseconds: 250)) {
      return;
    }
    _lastMeasurement = _clock!.elapsed;
    _scheduleBounds();
  }

  void _scheduleBounds() {
    if (_disposed || !mounted || _boundsScheduled || !widget.isActive) return;
    _boundsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundsScheduled = false;
      if (!_disposed && mounted && widget.isActive) _updateBounds();
    });
  }

  void _updateBounds() {
    final bounds = <Rect>[];
    final clips = <Rect>[];
    final myBox = context.findRenderObject() as RenderBox?;
    if (myBox == null || !myBox.hasSize || !myBox.attached) return;

    for (final key in _nodeKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached || box.size.isEmpty) {
        continue;
      }

      final rect = MatrixUtils.transformRect(
        box.getTransformTo(myBox),
        Offset.zero & box.size,
      );
      if (!rect.isFinite) continue;
      var visible = Offset.zero & myBox.size;
      // The overlay sits outside the scrolling columns. Carry each child's
      // ancestor clips into its paint coordinates so offscreen borders cannot
      // appear over the fixed panels beneath those columns.
      RenderObject descendant = box;
      while (descendant != myBox && descendant.parent != null) {
        final parent = descendant.parent!;
        final clip = parent.describeApproximatePaintClip(descendant);
        if (clip != null) {
          visible = visible.intersect(
            MatrixUtils.transformRect(parent.getTransformTo(myBox), clip),
          );
        }
        descendant = parent;
      }
      bounds.add(rect);
      clips.add(visible);
    }

    if (!listEquals(clips, _nodeClips.value)) {
      _nodeClips.value = List.unmodifiable(clips);
    }
    if (!listEquals(bounds, _nodeBounds.value)) {
      _nodeBounds.value = List.unmodifiable(bounds);
    }
  }

  /// Register a child node's key.
  void registerNode(GlobalKey key) {
    if (!_nodeKeys.contains(key)) {
      _nodeKeys.add(key);
      _scheduleBounds();
    }
  }

  /// Unregister a child node.
  void unregisterNode(GlobalKey key) {
    _nodeKeys.remove(key);
    _scheduleBounds();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.removeListener(_onVisualFrame);
    _nodeBounds.dispose();
    _nodeClips.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBounds();
    return VisualAnimation(
      active: widget.isActive,
      duration: const Duration(seconds: 12),
      builder: (_, clock, child) {
        _bindClock(clock);
        return NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _scheduleBounds();
            return false;
          },
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: widget.isActive
                          ? CircuitWavePainter(
                              bounds: _nodeBounds,
                              clips: _nodeClips,
                              engine: widget.engine,
                              clock: clock,
                              primaryColor:
                                  widget.primaryColor ??
                                  const Color(0xFF00BCD4),
                              secondaryColor:
                                  widget.secondaryColor ??
                                  const Color(0xFFAB47BC),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}

/// Marks a widget as a node in the circuit.
/// Must be a descendant of [CircuitWaveOverlay].
class CircuitNode extends StatefulWidget {
  final Widget child;

  const CircuitNode({super.key, required this.child});

  @override
  State<CircuitNode> createState() => _CircuitNodeState();
}

class _CircuitNodeState extends State<CircuitNode> {
  final GlobalKey _nodeKey = GlobalKey();
  CircuitWaveOverlayState? _overlay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final overlay = CircuitWaveOverlay.of(context);
    if (_overlay == overlay) return;
    _overlay?.unregisterNode(_nodeKey);
    _overlay = overlay;
    _overlay?.registerNode(_nodeKey);
  }

  @override
  void dispose() {
    _overlay?.unregisterNode(_nodeKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _nodeKey, child: widget.child);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A paint clock, not an audio/session clock. Hidden time is deliberately not
/// accumulated, so returning to the app cannot produce a large visual jump.
class VisualAnimationClock extends ChangeNotifier {
  VisualAnimationClock({
    required TickerProvider vsync,
    required this.duration,
    required this.frameInterval,
  }) : assert(duration > Duration.zero),
       assert(frameInterval > Duration.zero) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  Duration duration;
  Duration frameInterval;
  Duration _elapsed = Duration.zero;
  Duration _sincePaint = Duration.zero;
  Duration? _previousTick;

  Duration get elapsed => _elapsed;
  double get value =>
      (_elapsed.inMicroseconds % duration.inMicroseconds) /
      duration.inMicroseconds;
  bool get isAnimating => _ticker.isActive;

  void setActive(bool active) {
    if (active == _ticker.isActive) return;
    _previousTick = null;
    _sincePaint = Duration.zero;
    if (active) {
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration timestamp) {
    final previous = _previousTick;
    _previousTick = timestamp;
    if (previous == null) return;
    final micros = (timestamp - previous).inMicroseconds.clamp(0, 100000);
    final delta = Duration(microseconds: micros);
    _elapsed += delta;
    _sincePaint += delta;
    if (_sincePaint < frameInterval) return;
    // Never catch up by scheduling a burst of paints after a stalled frame.
    _sincePaint = Duration(
      microseconds: _sincePaint.inMicroseconds % frameInterval.inMicroseconds,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Builds once per configuration change; frames notify only the paint delegate.
/// Works identically on Flutter mobile and web, including tab/app suspension.
class VisualAnimation extends StatefulWidget {
  const VisualAnimation({
    super.key,
    this.active = true,
    this.respectReducedMotion = true,
    this.duration = const Duration(seconds: 10),
    this.frameInterval = const Duration(microseconds: 33333),
    this.child,
    required this.builder,
  });

  final bool active;

  /// Informational refresh (e.g. elapsed time) is not decorative motion.
  final bool respectReducedMotion;
  final Duration duration;
  final Duration frameInterval;
  final Widget? child;
  final Widget Function(BuildContext, VisualAnimationClock, Widget?) builder;

  @override
  State<VisualAnimation> createState() => _VisualAnimationState();
}

class _VisualAnimationState extends State<VisualAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final VisualAnimationClock _clock;
  bool _foreground = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    _clock = VisualAnimationClock(
      vsync: this,
      duration: widget.duration,
      frameInterval: widget.frameInterval,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        !(widget.respectReducedMotion &&
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false));
    _sync();
  }

  @override
  void didUpdateWidget(VisualAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clock.duration = widget.duration;
    _clock.frameInterval = widget.frameInterval;
    _visible =
        TickerMode.valuesOf(context).enabled &&
        !(widget.respectReducedMotion &&
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false));
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() => _clock.setActive(widget.active && _foreground && _visible);

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _clock, widget.child);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }
}

/// Also silences existing widget-vsync animations (button pulses/tutorials).
/// This never controls the audio engine or the session stopwatch.
class VisualActivityScope extends StatefulWidget {
  const VisualActivityScope({super.key, required this.child});
  final Widget child;

  @override
  State<VisualActivityScope> createState() => _VisualActivityScopeState();
}

class _VisualActivityScopeState extends State<VisualActivityScope>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground != foreground) setState(() => _foreground = foreground);
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: _foreground && TickerMode.valuesOf(context).enabled,
    child: widget.child,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

import 'package:flutter/scheduler.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_fractal_engine.dart';
import '../../engine/neom_frequency_painter_engine.dart';

class NeomFractalController extends SintController {
  final NeomFractalEngine fractalEngine = NeomFractalEngine();

  NeomFrequencyPainterEngine? _painterEngine;

  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _closed = false;

  static Object? _safeRouteArguments() {
    try {
      return Sint.arguments;
    } catch (_) {
      return null;
    }
  }

  final RxBool isRunning = true.obs;
  final RxBool showInfo = true.obs;
  final Rx<NeomNeuroState> selectedState = NeomNeuroState.neutral.obs;

  @override
  void onInit() {
    super.onInit();

    // Receive painter engine from navigation arguments
    final args = _safeRouteArguments();
    if (args is List && args.isNotEmpty && args.first is NeomFrequencyPainterEngine) {
      _painterEngine = args.first as NeomFrequencyPainterEngine;
    } else if (args is NeomFrequencyPainterEngine) {
      _painterEngine = args;
    }

    _ticker = Ticker(_onTick);
    _loadAndStart();
  }

  Future<void> _loadAndStart() async {
    try {
      await fractalEngine.loadShaders();
      if (_closed) return;
      _ticker.start();
    } catch (e, st) {
      if (!_closed) {
        NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: '_loadAndStart');
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_closed || !isRunning.value) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!dt.isFinite || dt < 0) return;

    // Sync audio-reactive params from painter engine
    if (_painterEngine != null) {
      fractalEngine.updateFromAudio(
        breath: _painterEngine!.breathPulse,
        neuro: _painterEngine!.glowIntensity,
      );
    }

    fractalEngine.tick(dt);
  }

  void setNeuroState(NeomNeuroState state) {
    selectedState.value = state;
    fractalEngine.setNeuroState(state);
  }

  void toggleSimulation() {
    isRunning.value = !isRunning.value;
  }

  void toggleInfo() {
    showInfo.value = !showInfo.value;
  }

  void resetView() {
    fractalEngine.resetView();
  }

  void exitFullscreen() {
    Sint.back();
  }

  @override
  void onClose() {
    if (_closed) return;
    _closed = true;
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    fractalEngine.dispose();
    isRunning.close();
    showInfo.close();
    selectedState.close();
    super.onClose();
  }
}

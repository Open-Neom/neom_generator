import 'dart:async';

import 'package:flutter/services.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_flocking_engine.dart';
import '../../engine/neom_frequency_painter_engine.dart';

class NeomFlockingController extends SintController {

  late NeomFlockingEngine flockingEngine;
  NeomFrequencyPainterEngine? painterEngine;

  Timer? _simulationTimer;
  bool _closed = false;

  static Object? _safeRouteArguments() {
    try {
      return Sint.arguments;
    } catch (_) {
      return null;
    }
  }

  // Controles de UI
  final RxInt boidCount = 100.obs;
  final RxBool showConnections = true.obs;
  final RxBool showGlow = true.obs;
  final RxBool isRunning = true.obs;
  final RxString colorMode = 'default'.obs;

  // Parámetros ajustables
  final RxDouble separationWeight = 1.5.obs;
  final RxDouble alignmentWeight = 1.0.obs;
  final RxDouble cohesionWeight = 1.0.obs;
  final RxDouble maxSpeed = 4.0.obs;

  // Touch interaction
  final RxBool isTouching = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Forzar landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Fullscreen inmersivo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Inicializar engines
    flockingEngine = NeomFlockingEngine();

    // Recibir el painter engine del generador (para sincronización de audio)
    final args = _safeRouteArguments();
    if (args is NeomFrequencyPainterEngine) {
      painterEngine = args;
    } else if (Sint.isRegistered<NeomFrequencyPainterEngine>()) {
      painterEngine = Sint.find<NeomFrequencyPainterEngine>();
    }
  }

  void initializeSimulation(double width, double height) {
    if (_closed ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    flockingEngine.initialize(
      count: boidCount.value,
      canvasWidth: width,
      canvasHeight: height,
    );

    _startSimulation();
  }

  void _startSimulation() {
    _simulationTimer?.cancel();

    // 60 FPS simulation loop
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_closed || !isRunning.value) return;

      // Sincronizar con audio si está disponible
      if (painterEngine != null) {
        flockingEngine.updateAudio(
          amplitude: painterEngine!.waveHeight,
          frequency: painterEngine!.visualPhase / 6.28, // Normalizar fase
          beat: painterEngine!.binauralPhase * 10, // Escalar beat
          phase: painterEngine!.visualPhase,
        );
      }

      // Actualizar parámetros desde UI
      flockingEngine.separationWeight = separationWeight.value;
      flockingEngine.alignmentWeight = alignmentWeight.value;
      flockingEngine.cohesionWeight = cohesionWeight.value;
      flockingEngine.maxSpeed = maxSpeed.value;
      flockingEngine.showConnections = showConnections.value;

      // Tick de simulación
      flockingEngine.update();

      update([AppPageIdConstants.flocking]);
    });
  }

  @override
  void onClose() {
    if (_closed) return;
    _closed = true;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    flockingEngine.dispose();

    // Restaurar orientación
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restaurar UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    boidCount.close();
    showConnections.close();
    showGlow.close();
    isRunning.close();
    colorMode.close();
    separationWeight.close();
    alignmentWeight.close();
    cohesionWeight.close();
    maxSpeed.close();
    isTouching.close();

    super.onClose();
  }

  // --- Acciones de usuario ---

  void toggleSimulation() {
    isRunning.toggle();
    update([AppPageIdConstants.flocking]);
  }

  void toggleConnections() {
    showConnections.toggle();
    update([AppPageIdConstants.flocking]);
  }

  void toggleGlow() {
    showGlow.toggle();
    update([AppPageIdConstants.flocking]);
  }

  void setColorMode(String mode) {
    colorMode.value = mode;
    flockingEngine.setColorPalette(mode);
    update([AppPageIdConstants.flocking]);
  }

  void onTouchStart(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    isTouching.value = true;
    flockingEngine.setAttractor(Offset(x, y));
  }

  void onTouchMove(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    if (isTouching.value) {
      flockingEngine.setAttractor(Offset(x, y));
    }
  }

  void onTouchEnd() {
    isTouching.value = false;
    flockingEngine.clearAttractor();
  }

  void increaseBoids() {
    if (boidCount.value < 300) {
      boidCount.value += 25;
      _reinitialize();
    }
  }

  void decreaseBoids() {
    if (boidCount.value > 25) {
      boidCount.value -= 25;
      _reinitialize();
    }
  }

  void _reinitialize() {
    flockingEngine.initialize(
      count: boidCount.value,
      canvasWidth: flockingEngine.width,
      canvasHeight: flockingEngine.height,
    );
  }

  void setSeparation(double value) {
    if (!value.isFinite) return;
    separationWeight.value = value.clamp(0.5, 3.0);
  }

  void setAlignment(double value) {
    if (!value.isFinite) return;
    alignmentWeight.value = value.clamp(0.0, 2.0);
  }

  void setCohesion(double value) {
    if (!value.isFinite) return;
    cohesionWeight.value = value.clamp(0.0, 2.0);
  }

  void setSpeed(double value) {
    if (!value.isFinite) return;
    maxSpeed.value = value.clamp(1.0, 8.0);
  }

  void exitFullscreen() {
    Sint.back();
  }

  void updateCanvasSize(double width, double height) {
    if (_closed ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    flockingEngine.height = height;

    // Reposicionar boids que quedaron fuera del área visible
    for (var boid in flockingEngine.boids) {
      if (boid.x > width) boid.x = boid.x % width;
      if (boid.y > height) boid.y = boid.y % height;
    }
  }
}

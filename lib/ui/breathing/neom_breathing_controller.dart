import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';

import '../../engine/neom_breathing_engine.dart';
import '../../engine/neom_frequency_painter_engine.dart';

/// Controlador para el ejercicio de respiración guiada
class NeomBreathingController extends GetxController {

  late NeomBreathingEngine breathingEngine;
  NeomFrequencyPainterEngine? painterEngine;

  Timer? _animationTimer;

  // Controles de UI
  final RxBool isRunning = true.obs;
  final RxBool showGuide = true.obs;
  final RxBool showParticles = true.obs;
  final RxString currentPattern = 'default'.obs;

  // Estadísticas de sesión
  final RxDouble attentionScore = 0.0.obs;
  final RxDouble sessionAverage = 0.0.obs;
  final RxInt breathCycles = 0.obs;

  // Patrones disponibles
  final List<Map<String, dynamic>> patterns = [
    {'id': 'default', 'name': 'Balanceado', 'desc': '4-2-6-2', 'icon': '🔵'},
    {'id': 'relax', 'name': 'Relajación', 'desc': '4-7-8', 'icon': '😌'},
    {'id': 'box', 'name': 'Cuadrada', 'desc': '4-4-4-4', 'icon': '⬜'},
    {'id': 'energize', 'name': 'Energía', 'desc': '2-0-2-0', 'icon': '⚡'},
    {'id': 'calm', 'name': 'Calma', 'desc': '4-0-6-0', 'icon': '🧘'},
    {'id': 'sleep', 'name': 'Dormir', 'desc': '4-7-8-0', 'icon': '😴'},
  ];

  @override
  void onInit() {
    super.onInit();

    // Forzar modo vertical/portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Fullscreen inmersivo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Inicializar engine
    breathingEngine = NeomBreathingEngine();

    // Recibir el painter engine del generador (para sincronización de audio)
    if (Get.arguments != null && Get.arguments is NeomFrequencyPainterEngine) {
      painterEngine = Get.arguments;
    } else if (Get.isRegistered<NeomFrequencyPainterEngine>()) {
      painterEngine = Get.find<NeomFrequencyPainterEngine>();
    }
  }

  void initializeExercise(double width, double height) {
    breathingEngine.initialize(
      width: width,
      height: height,
    );

    _startAnimation();
  }

  void _startAnimation() {
    _animationTimer?.cancel();

    DateTime lastTime = DateTime.now();

    // 60 FPS animation loop
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!isRunning.value) return;

      final now = DateTime.now();
      final dt = (now.difference(lastTime).inMicroseconds) / 1000000.0;
      lastTime = now;

      // Sincronizar con audio si está disponible
      if (painterEngine != null) {
        breathingEngine.updateAudio(
          amplitude: painterEngine!.waveHeight,
          phase: painterEngine!.visualPhase,
        );
      }

      // Tick de simulación
      breathingEngine.update(dt);

      // Actualizar valores observables
      attentionScore.value = breathingEngine.attentionScore;
      sessionAverage.value = breathingEngine.sessionAttentionAvg;

      update([AppPageIdConstants.breathing]);
    });
  }

  @override
  void onClose() {
    _animationTimer?.cancel();

    // Restaurar orientación
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restaurar UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.onClose();
  }

  // --- Acciones de usuario ---

  void toggleExercise() {
    isRunning.toggle();
    update([AppPageIdConstants.breathing]);
  }

  void toggleGuide() {
    showGuide.toggle();
    update([AppPageIdConstants.breathing]);
  }

  void toggleParticles() {
    showParticles.toggle();
    update([AppPageIdConstants.breathing]);
  }

  void setPattern(String patternId) {
    currentPattern.value = patternId;
    breathingEngine.setPattern(patternId);
    breathingEngine.resetSession();
    update([AppPageIdConstants.breathing]);
  }

  void onTouchStart(double y, double maxHeight) {
    // Convertir posición de pantalla a normalizada (0 = abajo, 1 = arriba)
    final margin = breathingEngine.sphereRadius * 1.5;
    final usableHeight = maxHeight - (margin * 2);
    final normalizedY = 1.0 - ((y - margin) / usableHeight).clamp(0.0, 1.0);

    breathingEngine.onTouchStart(normalizedY);
  }

  void onTouchMove(double y, double maxHeight) {
    final margin = breathingEngine.sphereRadius * 1.5;
    final usableHeight = maxHeight - (margin * 2);
    final normalizedY = 1.0 - ((y - margin) / usableHeight).clamp(0.0, 1.0);

    breathingEngine.onTouchMove(normalizedY);
  }

  void onTouchEnd() {
    breathingEngine.onTouchEnd();
  }

  void resetSession() {
    breathingEngine.resetSession();
    breathCycles.value = 0;
    update([AppPageIdConstants.breathing]);
  }

  void exitFullscreen() {
    Get.back();
  }

  // --- Getters para UI ---

  String getPhaseText() => breathingEngine.getPhaseText();

  double getPhaseProgress() => breathingEngine.getPhaseProgress();

  bool get isUserTouching => breathingEngine.isUserTouching;

  String getCurrentPatternName() {
    final pattern = patterns.firstWhere(
          (p) => p['id'] == currentPattern.value,
      orElse: () => patterns.first,
    );
    return pattern['name'] as String;
  }

  String getCurrentPatternDesc() {
    final pattern = patterns.firstWhere(
          (p) => p['id'] == currentPattern.value,
      orElse: () => patterns.first,
    );
    return pattern['desc'] as String;
  }
}

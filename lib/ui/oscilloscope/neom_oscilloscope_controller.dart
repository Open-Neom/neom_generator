import 'package:flutter/services.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_frequency_painter_engine.dart';

class NeomOscilloscopeController extends SintController {

  late NeomFrequencyPainterEngine painterEngine;

  // Controles visuales
  final RxDouble waveThickness = 1.8.obs;
  final RxDouble waveScale = 0.4.obs;      // Altura de la onda (0.1 - 0.8)
  final RxDouble timeScale = 1.0.obs;      // Velocidad/compresión horizontal
  final RxBool isPaused = false.obs;
  final RxBool showGrid = true.obs;
  final RxBool showGlow = true.obs;

  // Para el gesto de pausa
  final RxBool isLongPressing = false.obs;

  // Samples congelados cuando se pausa
  List<double> frozenSamples = [];

  // Rango de controles
  static const double thicknessMin = 0.5;
  static const double thicknessMax = 5.0;
  static const double scaleMin = 0.1;
  static const double scaleMax = 0.9;
  static const double timeScaleMin = 0.25;
  static const double timeScaleMax = 4.0;

  @override
  void onInit() {
    super.onInit();

    // Forzar landscape al entrar
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Ocultar barras del sistema para fullscreen inmersivo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Recibir el engine del generador
    if (Sint.arguments != null && Sint.arguments is NeomFrequencyPainterEngine) {
      painterEngine = Sint.arguments;
    } else if (Sint.isRegistered<NeomFrequencyPainterEngine>()) {
      painterEngine = Sint.find<NeomFrequencyPainterEngine>();
    } else {
      painterEngine = NeomFrequencyPainterEngine();
    }
  }

  @override
  void onClose() {
    // Restaurar orientación normal
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restaurar UI del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.onClose();
  }

  // --- ACCIONES ---

  void togglePause() {
    if (!isPaused.value) {
      // Congelar samples actuales
      frozenSamples = List.from(painterEngine.samples);
    }
    isPaused.toggle();
    update([AppPageIdConstants.oscilloscope]);
  }

  void onLongPressStart() {
    isLongPressing.value = true;
    if (!isPaused.value) {
      frozenSamples = List.from(painterEngine.samples);
    }
    isPaused.value = true;
    update([AppPageIdConstants.oscilloscope]);
  }

  void onLongPressEnd() {
    isLongPressing.value = false;
    isPaused.value = false;
    update([AppPageIdConstants.oscilloscope]);
  }

  void setWaveThickness(double value) {
    waveThickness.value = value.clamp(thicknessMin, thicknessMax);
    update([AppPageIdConstants.oscilloscope]);
  }

  void setWaveScale(double value) {
    waveScale.value = value.clamp(scaleMin, scaleMax);
    update([AppPageIdConstants.oscilloscope]);
  }

  void setTimeScale(double value) {
    timeScale.value = value.clamp(timeScaleMin, timeScaleMax);
    update([AppPageIdConstants.oscilloscope]);
  }

  void toggleGrid() {
    showGrid.toggle();
    update([AppPageIdConstants.oscilloscope]);
  }

  void toggleGlow() {
    showGlow.toggle();
    update([AppPageIdConstants.oscilloscope]);
  }

  void increaseThickness() {
    setWaveThickness(waveThickness.value + 0.3);
  }

  void decreaseThickness() {
    setWaveThickness(waveThickness.value - 0.3);
  }

  void increaseScale() {
    setWaveScale(waveScale.value + 0.05);
  }

  void decreaseScale() {
    setWaveScale(waveScale.value - 0.05);
  }

  void increaseTimeScale() {
    setTimeScale(timeScale.value + 0.25);
  }

  void decreaseTimeScale() {
    setTimeScale(timeScale.value - 0.25);
  }

  /// Samples a dibujar (vivos o congelados)
  List<double> get displaySamples {
    if (isPaused.value && frozenSamples.isNotEmpty) {
      return frozenSamples;
    }
    return painterEngine.samples;
  }

  void exitFullscreen() {
    Sint.back();
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

/// Estados de la respiración
enum BreathingPhase {
  inhale,   // Subiendo - Inhala
  holdIn,   // Pausa arriba
  exhale,   // Bajando - Exhala
  holdOut,  // Pausa abajo
}

/// Motor de ejercicio de respiración guiada con tracking de atención
class NeomBreathingEngine extends ChangeNotifier {
  final Random _random = Random();

  // Posición de la esfera (0 = abajo, 1 = arriba)
  double spherePosition = 0.0;

  // Velocidad actual de movimiento
  double sphereVelocity = 0.0;

  // Fase actual de respiración
  BreathingPhase phase = BreathingPhase.inhale;

  // Configuración de tiempos (en segundos)
  double inhaleTime = 4.0;
  double holdInTime = 2.0;
  double exhaleTime = 6.0;
  double holdOutTime = 2.0;

  // Timer interno
  double _phaseTimer = 0.0;
  double _totalCycleTime = 0.0;

  // Tracking de atención del usuario
  bool isUserTouching = false;
  double userTouchY = 0.0; // Posición Y normalizada del dedo (0-1)
  double attentionScore = 0.0; // 0-1, qué tan bien sigue el usuario
  double sessionAttentionAvg = 0.0;
  int _attentionSamples = 0;

  // Modo libre (sin guía, solo rebote)
  bool freeMode = false;
  double freeBounceVelocity = 0.0;

  // Dimensiones del canvas
  double canvasWidth = 400;
  double canvasHeight = 800;

  // Configuración visual
  double sphereRadius = 40.0;
  double glowIntensity = 0.8;
  Color sphereColor = const Color(0xFF00CED1);

  // Audio reactivo (opcional)
  double audioAmplitude = 0.0;
  double audioPhase = 0.0;

  // Colores por fase
  static const Map<BreathingPhase, Color> phaseColors = {
    BreathingPhase.inhale: Color(0xFF4FC3F7),   // Azul claro - energía entrando
    BreathingPhase.holdIn: Color(0xFF81C784),   // Verde - retención
    BreathingPhase.exhale: Color(0xFFBA68C8),   // Púrpura - liberación
    BreathingPhase.holdOut: Color(0xFFFFB74D),  // Naranja - pausa
  };

  // Textos por fase
  static const Map<BreathingPhase, String> phaseTexts = {
    BreathingPhase.inhale: 'INHALA',
    BreathingPhase.holdIn: 'SOSTÉN',
    BreathingPhase.exhale: 'EXHALA',
    BreathingPhase.holdOut: 'PAUSA',
  };

  /// Inicializa el engine
  void initialize({
    required double width,
    required double height,
    double? inhaleSec,
    double? holdInSec,
    double? exhaleSec,
    double? holdOutSec,
  }) {
    canvasWidth = width;
    canvasHeight = height;

    if (inhaleSec != null) inhaleTime = inhaleSec;
    if (holdInSec != null) holdInTime = holdInSec;
    if (exhaleSec != null) exhaleTime = exhaleSec;
    if (holdOutSec != null) holdOutTime = holdOutSec;

    _totalCycleTime = inhaleTime + holdInTime + exhaleTime + holdOutTime;

    // Iniciar en fase de inhalación
    phase = BreathingPhase.inhale;
    spherePosition = 0.0;
    _phaseTimer = 0.0;
    attentionScore = 0.0;
    sessionAttentionAvg = 0.0;
    _attentionSamples = 0;

    // Para modo libre
    freeBounceVelocity = 0.3 + _random.nextDouble() * 0.2;
  }

  /// Actualiza el estado del audio
  void updateAudio({
    required double amplitude,
    required double phase,
  }) {
    audioAmplitude = amplitude.clamp(0.0, 1.0);
    audioPhase = phase;
  }

  /// Tick principal - llamar cada frame
  void update(double dt) {
    if (freeMode || !isUserTouching) {
      _updateFreeMode(dt);
    } else {
      _updateGuidedMode(dt);
    }

    // Actualizar color de esfera según fase
    sphereColor = Color.lerp(
      sphereColor,
      phaseColors[phase]!,
      dt * 3.0,
    )!;

    // Actualizar radio con audio
    final baseRadius = 35.0 + (canvasWidth * 0.05);
    sphereRadius = baseRadius + (audioAmplitude * 15.0) + (sin(audioPhase * 2) * 5.0);

    // Actualizar intensidad del glow según atención
    glowIntensity = 0.4 + (attentionScore * 0.6);

    notifyListeners();
  }

  /// Modo libre: la esfera rebota sin control
  void _updateFreeMode(double dt) {
    // Rebote simple
    spherePosition += freeBounceVelocity * dt;

    // Rebotar en los bordes
    if (spherePosition >= 1.0) {
      spherePosition = 1.0;
      freeBounceVelocity = -freeBounceVelocity.abs() * (0.8 + _random.nextDouble() * 0.4);
    } else if (spherePosition <= 0.0) {
      spherePosition = 0.0;
      freeBounceVelocity = freeBounceVelocity.abs() * (0.8 + _random.nextDouble() * 0.4);
    }

    // Añadir algo de variación aleatoria
    freeBounceVelocity += (_random.nextDouble() - 0.5) * 0.1 * dt;
    freeBounceVelocity = freeBounceVelocity.clamp(-0.8, 0.8);

    // Determinar fase según dirección
    if (freeBounceVelocity > 0) {
      phase = BreathingPhase.inhale;
    } else {
      phase = BreathingPhase.exhale;
    }

    // En modo libre, la atención es 0
    attentionScore = attentionScore * 0.95; // Decay suave
  }

  /// Modo guiado: la esfera sigue el patrón de respiración
  void _updateGuidedMode(double dt) {
    _phaseTimer += dt;

    double targetPosition;
    double phaseDuration;

    switch (phase) {
      case BreathingPhase.inhale:
        phaseDuration = inhaleTime;
        // Curva ease-out para inhalación natural
        final progress = (_phaseTimer / phaseDuration).clamp(0.0, 1.0);
        targetPosition = _easeOutCubic(progress);

        if (_phaseTimer >= phaseDuration) {
          _phaseTimer = 0.0;
          phase = holdInTime > 0 ? BreathingPhase.holdIn : BreathingPhase.exhale;
        }
        break;

      case BreathingPhase.holdIn:
        phaseDuration = holdInTime;
        targetPosition = 1.0; // Mantener arriba

        if (_phaseTimer >= phaseDuration) {
          _phaseTimer = 0.0;
          phase = BreathingPhase.exhale;
        }
        break;

      case BreathingPhase.exhale:
        phaseDuration = exhaleTime;
        // Curva ease-in para exhalación natural
        final progress = (_phaseTimer / phaseDuration).clamp(0.0, 1.0);
        targetPosition = 1.0 - _easeInOutQuad(progress);

        if (_phaseTimer >= phaseDuration) {
          _phaseTimer = 0.0;
          phase = holdOutTime > 0 ? BreathingPhase.holdOut : BreathingPhase.inhale;
        }
        break;

      case BreathingPhase.holdOut:
        phaseDuration = holdOutTime;
        targetPosition = 0.0; // Mantener abajo

        if (_phaseTimer >= phaseDuration) {
          _phaseTimer = 0.0;
          phase = BreathingPhase.inhale;
        }
        break;
    }

    // Mover esfera hacia posición objetivo
    spherePosition = targetPosition;

    // Calcular score de atención basado en qué tan cerca está el dedo
    if (isUserTouching) {
      final distance = (userTouchY - spherePosition).abs();
      final newScore = (1.0 - (distance * 2.0)).clamp(0.0, 1.0);

      // Suavizar el score
      attentionScore = attentionScore * 0.8 + newScore * 0.2;

      // Actualizar promedio de sesión
      _attentionSamples++;
      sessionAttentionAvg = sessionAttentionAvg + (attentionScore - sessionAttentionAvg) / _attentionSamples;
    }
  }

  /// Curvas de easing para movimiento natural
  double _easeOutCubic(double t) => 1.0 - pow(1.0 - t, 3).toDouble();
  double _easeInOutQuad(double t) => t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;

  /// Usuario comienza a tocar
  void onTouchStart(double normalizedY) {
    isUserTouching = true;
    userTouchY = normalizedY.clamp(0.0, 1.0);
    freeMode = false;
  }

  /// Usuario mueve el dedo
  void onTouchMove(double normalizedY) {
    if (isUserTouching) {
      userTouchY = normalizedY.clamp(0.0, 1.0);
    }
  }

  /// Usuario deja de tocar
  void onTouchEnd() {
    isUserTouching = false;
    // Volver a modo libre después de un tiempo
    Future.delayed(const Duration(seconds: 3), () {
      if (!isUserTouching) {
        freeMode = true;
        freeBounceVelocity = (spherePosition > 0.5 ? -1 : 1) * 0.3;
      }
    });
  }

  /// Obtiene la posición Y real de la esfera en el canvas
  double getSphereY() {
    // Invertir porque Y crece hacia abajo en Flutter
    // Añadir margen para que no toque los bordes
    final margin = sphereRadius * 1.5;
    final usableHeight = canvasHeight - (margin * 2);
    return margin + (1.0 - spherePosition) * usableHeight;
  }

  /// Obtiene el progreso de la fase actual (0-1)
  double getPhaseProgress() {
    double phaseDuration;
    switch (phase) {
      case BreathingPhase.inhale:
        phaseDuration = inhaleTime;
        break;
      case BreathingPhase.holdIn:
        phaseDuration = holdInTime;
        break;
      case BreathingPhase.exhale:
        phaseDuration = exhaleTime;
        break;
      case BreathingPhase.holdOut:
        phaseDuration = holdOutTime;
        break;
    }
    return (_phaseTimer / phaseDuration).clamp(0.0, 1.0);
  }

  /// Obtiene el texto de la fase actual
  String getPhaseText() => phaseTexts[phase]!;

  /// Cambia el patrón de respiración
  void setBreathingPattern({
    required double inhale,
    required double holdIn,
    required double exhale,
    required double holdOut,
  }) {
    inhaleTime = inhale.clamp(2.0, 10.0);
    holdInTime = holdIn.clamp(0.0, 10.0);
    exhaleTime = exhale.clamp(2.0, 15.0);
    holdOutTime = holdOut.clamp(0.0, 10.0);
    _totalCycleTime = inhaleTime + holdInTime + exhaleTime + holdOutTime;
  }

  /// Patrones predefinidos de respiración
  void setPattern(String name) {
    switch (name) {
      case 'relax': // 4-7-8 relajación profunda
        setBreathingPattern(inhale: 4, holdIn: 7, exhale: 8, holdOut: 0);
        break;
      case 'box': // Respiración cuadrada (4-4-4-4)
        setBreathingPattern(inhale: 4, holdIn: 4, exhale: 4, holdOut: 4);
        break;
      case 'energize': // Energizante rápido
        setBreathingPattern(inhale: 2, holdIn: 0, exhale: 2, holdOut: 0);
        break;
      case 'calm': // Calmante (4-0-6-0)
        setBreathingPattern(inhale: 4, holdIn: 0, exhale: 6, holdOut: 0);
        break;
      case 'sleep': // Para dormir (4-7-8-0)
        setBreathingPattern(inhale: 4, holdIn: 7, exhale: 8, holdOut: 0);
        break;
      default: // Balanceado por defecto
        setBreathingPattern(inhale: 4, holdIn: 2, exhale: 6, holdOut: 2);
    }
  }

  /// Reinicia la sesión
  void resetSession() {
    spherePosition = 0.0;
    phase = BreathingPhase.inhale;
    _phaseTimer = 0.0;
    attentionScore = 0.0;
    sessionAttentionAvg = 0.0;
    _attentionSamples = 0;
    freeMode = false;
    isUserTouching = false;
  }

  /// Obtiene el tiempo total del ciclo
  double getTotalCycleTime() => _totalCycleTime;

  /// Obtiene el color actual interpolado
  Color getCurrentColor() => sphereColor;
}

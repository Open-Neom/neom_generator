import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../painters/neom_breathing_painter.dart';
import 'neom_breathing_controller.dart';

/// Página fullscreen para el ejercicio de respiración guiada
/// Modo VERTICAL/PORTRAIT obligatorio
class NeomBreathingFullscreenPage extends StatelessWidget {
  const NeomBreathingFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomBreathingController>(
      id: AppPageIdConstants.breathing,
      init: NeomBreathingController(),
      builder: (controller) => Scaffold(
        backgroundColor: AppColor.darkBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final currentWidth = constraints.maxWidth;
            final currentHeight = constraints.maxHeight;

            // Inicializar cuando tengamos dimensiones
            if (controller.breathingEngine.canvasWidth != currentWidth ||
                controller.breathingEngine.canvasHeight != currentHeight) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.initializeExercise(currentWidth, currentHeight);
              });
            }

            return GestureDetector(
              // Touch para seguir la respiración
              onPanStart: (details) {
                controller.onTouchStart(
                  details.localPosition.dy,
                  currentHeight,
                );
              },
              onPanUpdate: (details) {
                controller.onTouchMove(
                  details.localPosition.dy,
                  currentHeight,
                );
              },
              onPanEnd: (_) => controller.onTouchEnd(),
              // Tap simple para pausar
              onTap: controller.toggleExercise,
              child: Stack(
                children: [
                  // Canvas de respiración
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: controller.breathingEngine,
                      builder: (_, _) => CustomPaint(
                        painter: NeomBreathingPainter(
                          engine: controller.breathingEngine,
                          showGuide: controller.showGuide.value,
                          showParticles: controller.showParticles.value,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),

                  // Indicador de pausa
                  if (!controller.isRunning.value)
                    _buildPauseOverlay(controller),

                  // Selector de patrón (arriba)
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: _buildPatternSelector(controller),
                  ),

                  // Instrucciones (abajo)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: _buildInstructions(controller),
                  ),

                  // Botones de control (esquina superior derecha)
                  Positioned(
                    top: 50,
                    right: 15,
                    child: _buildControlButtons(controller),
                  ),

                  // Botón de salir
                  Positioned(
                    top: 50,
                    left: 15,
                    child: _buildExitButton(controller),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPauseOverlay(NeomBreathingController controller) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColor.bondiBlue.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_outline, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'PAUSADO',
                      style: TextStyle(
                        color: AppColor.bondiBlue,
                        fontFamily: 'Courier',
                        fontSize: 18,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Estadísticas de sesión
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(
                      'ATENCIÓN PROMEDIO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() => Text(
                      '${(controller.sessionAverage.value * 100).toInt()}%',
                      style: TextStyle(
                        color: Color.lerp(
                          Colors.red,
                          Colors.green,
                          controller.sessionAverage.value,
                        ),
                        fontSize: 32,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Toca para continuar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatternSelector(NeomBreathingController controller) {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 60),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.patterns.length,
        itemBuilder: (context, index) {
          final pattern = controller.patterns[index];
          final isSelected = controller.currentPattern.value == pattern['id'];

          return GestureDetector(
            onTap: () => controller.setPattern(pattern['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColor.bondiBlue.withValues(alpha: 0.3)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColor.bondiBlue
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pattern['icon'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pattern['name'],
                        style: TextStyle(
                          color: isSelected ? AppColor.bondiBlue : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        pattern['desc'],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 8,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructions(NeomBreathingController controller) {
    final isTracking = controller.isUserTouching;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Estado actual
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isTracking
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTracking
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.orange.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTracking ? Icons.touch_app : Icons.pan_tool,
                color: isTracking ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isTracking ? 'SIGUIENDO' : 'TOCA Y DESLIZA',
                style: TextStyle(
                  color: isTracking ? Colors.green : Colors.orange,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Instrucción
        Text(
          'Sigue la esfera con tu dedo',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(NeomBreathingController controller) {
    return Column(
      children: [
        // Toggle guía
        _buildMiniButton(
          icon: Icons.grid_on,
          isActive: controller.showGuide.value,
          onTap: controller.toggleGuide,
        ),
        const SizedBox(height: 8),
        // Toggle partículas
        _buildMiniButton(
          icon: Icons.blur_on,
          isActive: controller.showParticles.value,
          onTap: controller.toggleParticles,
        ),
        const SizedBox(height: 8),
        // Reset
        _buildMiniButton(
          icon: Icons.refresh,
          isActive: false,
          onTap: controller.resetSession,
        ),
      ],
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? AppColor.bondiBlue.withValues(alpha: 0.3)
              : Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColor.bondiBlue
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColor.bondiBlue : Colors.white54,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildExitButton(NeomBreathingController controller) {
    return GestureDetector(
      onTap: controller.exitFullscreen,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white70,
          size: 22,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../painters/neom_flocking_painter.dart';
import 'neom_flocking_controller.dart';

class NeomFlockingFullscreenPage extends StatelessWidget {
  const NeomFlockingFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomFlockingController>(
      id: AppPageIdConstants.flocking,
      init: NeomFlockingController(),
      builder: (controller) => Scaffold(
        backgroundColor: AppColor.darkBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final currentWidth = constraints.maxWidth;
            final currentHeight = constraints.maxHeight;

            // Inicializar O actualizar cuando cambian las dimensiones
            if (controller.flockingEngine.boids.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.initializeSimulation(currentWidth, currentHeight);
              });
            } else if (controller.flockingEngine.width != currentWidth ||
                controller.flockingEngine.height != currentHeight) {
              // ← NUEVO: Actualizar dimensiones sin reiniciar boids
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.updateCanvasSize(currentWidth, currentHeight);
              });
            }

            return GestureDetector(
              // Touch para atraer boids
              onPanStart: (details) {
                controller.onTouchStart(
                  details.localPosition.dx,
                  details.localPosition.dy,
                );
              },
              onPanUpdate: (details) {
                controller.onTouchMove(
                  details.localPosition.dx,
                  details.localPosition.dy,
                );
              },
              onPanEnd: (_) => controller.onTouchEnd(),
              // Tap para pausar
              onTap: controller.toggleSimulation,
              child: Stack(
                children: [
                  // Canvas de flocking
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: controller.flockingEngine,
                      builder: (_, _) => CustomPaint(
                        painter: NeomFlockingPainter(
                          engine: controller.flockingEngine,
                          showConnections: controller.showConnections.value,
                          showGlow: controller.showGlow.value,
                        ),
                        size: Size.infinite,

                      ),
                    ),
                  ),
                  // Indicador de pausa
                  if (!controller.isRunning.value)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColor.bondiBlue.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pause, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'PAUSED',
                                style: TextStyle(
                                  color: AppColor.bondiBlue,
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Indicador de touch
                  if (controller.isTouching.value)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'ATTRACTING',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Panel de controles (lado izquierdo)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: _buildLeftControlPanel(controller),
                  ),

                  // Panel de controles (lado derecho)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: _buildRightControlPanel(controller),
                  ),

                  // Botón de salir
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildExitButton(controller),
                  ),

                  // Info panel
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _buildInfoPanel(controller),
                  ),

                  // Color modes
                  Positioned(
                    bottom: 10,
                    right: 80,
                    child: _buildColorModeSelector(controller),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftControlPanel(NeomFlockingController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Velocidad
        _buildSliderControl(
          icon: Icons.speed,
          label: 'SPD',
          value: controller.maxSpeed.value,
          min: 1.0,
          max: 8.0,
          onChanged: controller.setSpeed,
        ),
        const SizedBox(height: 20),

        // Toggles
        _buildToggleButton(
          icon: Icons.hub,
          isActive: controller.showConnections.value,
          onTap: controller.toggleConnections,
        ),
        const SizedBox(height: 8),
        _buildToggleButton(
          icon: Icons.blur_on,
          isActive: controller.showGlow.value,
          onTap: controller.toggleGlow,
        ),
      ],
    );
  }

  Widget _buildRightControlPanel(NeomFlockingController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cantidad de boids
        _buildControlGroup(
          icon: Icons.scatter_plot,
          label: 'NOID',
          value: controller.boidCount.value.toString(),
          onIncrease: controller.increaseBoids,
          onDecrease: controller.decreaseBoids,
        ),
        const SizedBox(height: 15),

        // Separación
        _buildSliderControl(
          icon: Icons.unfold_more,
          label: 'SEP',
          value: controller.separationWeight.value,
          min: 0.5,
          max: 3.0,
          onChanged: controller.setSeparation,
        ),
        const SizedBox(height: 15),

        // Cohesión
        _buildSliderControl(
          icon: Icons.compress,
          label: 'COH',
          value: controller.cohesionWeight.value,
          min: 0.0,
          max: 2.0,
          onChanged: controller.setCohesion,
        ),
      ],
    );
  }

  Widget _buildControlGroup({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onIncrease,
            child: Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                color: AppColor.bondiBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onDecrease,
            child: Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                color: AppColor.bondiBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.remove, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderControl({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 12),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7, letterSpacing: 1)),
          const SizedBox(height: 4),
          SizedBox(
            height: 60,
            width: 20,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  activeTrackColor: AppColor.bondiBlue,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColor.bondiBlue.withValues(alpha: 0.3) : Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AppColor.bondiBlue : Colors.white12),
        ),
        child: Icon(icon, color: isActive ? AppColor.bondiBlue : Colors.white38, size: 18),
      ),
    );
  }

  Widget _buildExitButton(NeomFlockingController controller) {
    return GestureDetector(
      onTap: controller.exitFullscreen,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(Icons.fullscreen_exit, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildInfoPanel(NeomFlockingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoItem('TAP', 'pause'),
          const SizedBox(width: 12),
          _buildInfoItem('DRAG', 'attract'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String key, String action) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColor.bondiBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(key, style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        Text(action, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }

  Widget _buildColorModeSelector(NeomFlockingController controller) {
    final modes = ['default', 'calm', 'focus', 'sleep', 'creativity'];
    final icons = [Icons.auto_awesome, Icons.spa, Icons.psychology, Icons.nightlight, Icons.palette];
    final colors = [AppColor.bondiBlue, Colors.purple, Colors.orange, Colors.indigo, Colors.pink];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(modes.length, (i) {
          final isSelected = controller.colorMode.value == modes[i];
          return GestureDetector(
            onTap: () => controller.setColorMode(modes[i]),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? colors[i].withValues(alpha: 0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? colors[i] : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(icons[i], color: isSelected ? colors[i] : Colors.white38, size: 16),
            ),
          );
        }),
      ),
    );
  }
}

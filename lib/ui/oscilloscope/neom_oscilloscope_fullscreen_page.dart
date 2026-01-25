import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';

import 'neom_oscilloscope_controller.dart';
import 'neom_oscilloscope_fullscreen_painter.dart';

class NeomOscilloscopeFullscreenPage extends StatelessWidget {
  const NeomOscilloscopeFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NeomOscilloscopeController>(
      id: AppPageIdConstants.oscilloscope,
      init: NeomOscilloscopeController(),
      builder: (controller) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Tap simple: toggle pausa
          onTap: controller.togglePause,
          // Long press: pausa mientras se mantiene
          onLongPressStart: (_) => controller.onLongPressStart(),
          onLongPressEnd: (_) => controller.onLongPressEnd(),
          // Pinch vertical: escala de onda
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final delta = (details.scale - 1.0) * 0.01;
              controller.setWaveScale(controller.waveScale.value + delta);
            }
          },
          child: Stack(
            children: [
              // Osciloscopio fullscreen
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller.painterEngine,
                  builder: (_, __) => CustomPaint(
                    painter: NeomOscilloscopeFullscreenPainter(
                      samples: controller.displaySamples,
                      signalColor: controller.isPaused.value
                          ? AppColor.bondiBlue.withOpacity(0.6)
                          : AppColor.bondiBlue,
                      gridColor: Colors.white12,
                      thickness: controller.waveThickness.value,
                      waveScale: controller.waveScale.value,
                      timeScale: controller.timeScale.value,
                      showGrid: controller.showGrid.value,
                      showGlow: controller.showGlow.value,
                      isPaused: controller.isPaused.value,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),

              // Indicador de pausa
              if (controller.isPaused.value)
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
                        border: Border.all(color: AppColor.bondiBlue.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause, color: AppColor.bondiBlue, size: 16),
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

              // Panel de controles (derecha)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: _buildControlPanel(controller),
              ),

              // Botón de salir (esquina superior izquierda)
              Positioned(
                top: 10,
                left: 10,
                child: _buildExitButton(controller),
              ),

              // Info de parámetros (esquina inferior izquierda)
              Positioned(
                bottom: 10,
                left: 10,
                child: _buildInfoPanel(controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(NeomOscilloscopeController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Grosor de onda
        _buildControlGroup(
          icon: Icons.line_weight,
          label: 'THICK',
          value: controller.waveThickness.value.toStringAsFixed(1),
          onIncrease: controller.increaseThickness,
          onDecrease: controller.decreaseThickness,
        ),
        const SizedBox(height: 20),

        // Escala vertical (altura)
        _buildControlGroup(
          icon: Icons.height,
          label: 'HEIGHT',
          value: '${(controller.waveScale.value * 100).toInt()}%',
          onIncrease: controller.increaseScale,
          onDecrease: controller.decreaseScale,
        ),
        const SizedBox(height: 20),

        // Escala temporal (compresión)
        _buildControlGroup(
          icon: Icons.speed,
          label: 'TIME',
          value: '${controller.timeScale.value.toStringAsFixed(2)}x',
          onIncrease: controller.increaseTimeScale,
          onDecrease: controller.decreaseTimeScale,
        ),
        const SizedBox(height: 30),

        // Toggle grid
        _buildToggleButton(
          icon: Icons.grid_on,
          isActive: controller.showGrid.value,
          onTap: controller.toggleGrid,
          tooltip: 'Grid',
        ),
        const SizedBox(height: 10),

        // Toggle glow
        _buildToggleButton(
          icon: Icons.blur_on,
          isActive: controller.showGlow.value,
          onTap: controller.toggleGlow,
          tooltip: 'Glow',
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
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onIncrease,
            child: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: AppColor.bondiBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Courier',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onDecrease,
            child: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: AppColor.bondiBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.remove, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? AppColor.bondiBlue.withOpacity(0.3) : Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColor.bondiBlue : Colors.white12,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColor.bondiBlue : Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildExitButton(NeomOscilloscopeController controller) {
    return GestureDetector(
      onTap: controller.exitFullscreen,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(
          Icons.fullscreen_exit,
          color: Colors.white70,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildInfoPanel(NeomOscilloscopeController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoItem('TAP', 'pause'),
          const SizedBox(width: 16),
          _buildInfoItem('HOLD', 'freeze'),
          const SizedBox(width: 16),
          _buildInfoItem('PINCH', 'scale'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String key, String action) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColor.bondiBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: AppColor.bondiBlue,
              fontFamily: 'Courier',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

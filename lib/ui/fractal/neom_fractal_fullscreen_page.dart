import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_fractal_engine.dart';
import '../../utils/enums/neom_neuro_state.dart';
import '../painters/neom_fractal_painter.dart';
import 'neom_fractal_controller.dart';

class NeomFractalFullscreenPage extends StatelessWidget {
  const NeomFractalFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomFractalController>(
      id: AppPageIdConstants.generator,
      init: NeomFractalController(),
      builder: (controller) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onScaleStart: (_) {},
          onScaleUpdate: (details) {
            // Pan
            if (details.pointerCount == 1) {
              controller.fractalEngine.pan(
                details.focalPointDelta.dx,
                details.focalPointDelta.dy,
              );
            }
            // Pinch zoom
            if (details.pointerCount >= 2) {
              controller.fractalEngine.zoomBy(details.scale);
            }
          },
          onDoubleTap: controller.resetView,
          onTap: controller.toggleInfo,
          child: Stack(
            children: [
              // Fractal canvas
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller.fractalEngine,
                  builder: (_, __) => CustomPaint(
                    painter: NeomFractalPainter(
                      engine: controller.fractalEngine,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),

              // Top bar — neuro state selector
              if (controller.showInfo.value)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  child: _buildTopBar(controller),
                ),

              // Bottom info panel
              if (controller.showInfo.value)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  left: 8,
                  right: 8,
                  child: _buildBottomBar(controller),
                ),

              // Pause overlay
              if (!controller.isRunning.value)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColor.bondiBlue.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'PAUSED',
                          style: TextStyle(
                            color: AppColor.bondiBlue,
                            fontFamily: 'Courier',
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(NeomFractalController controller) {
    return Row(
      children: [
        // Exit button
        _buildIconButton(
          icon: Icons.fullscreen_exit,
          onTap: controller.exitFullscreen,
        ),
        const SizedBox(width: 8),

        // Neuro state chips
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: NeomNeuroState.values.map((state) {
                final isSelected = controller.selectedState.value == state;
                final info = _stateInfo[state]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => controller.setNeuroState(state),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? info.color.withValues(alpha: 0.3)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? info.color : Colors.white12,
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info.icon, size: 14,
                            color: isSelected ? info.color : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            info.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? info.color : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Pause/play
        _buildIconButton(
          icon: controller.isRunning.value ? Icons.pause : Icons.play_arrow,
          onTap: controller.toggleSimulation,
        ),
      ],
    );
  }

  Widget _buildBottomBar(NeomFractalController controller) {
    final config = controller.fractalEngine.config;
    final fractalName = _fractalNames[config.type] ?? 'Fractal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Fractal info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fractalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Courier',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ZOOM: ${controller.fractalEngine.zoom.toStringAsExponential(1)} '
                  '| ITER: ${config.maxIterations.toInt()}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Courier',
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Controls hint
          _buildInfoItem('DRAG', 'pan'),
          const SizedBox(width: 10),
          _buildInfoItem('PINCH', 'zoom'),
          const SizedBox(width: 10),
          _buildInfoItem('2xTAP', 'reset'),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildInfoItem(String key, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColor.bondiBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(key,
            style: const TextStyle(
              color: AppColor.bondiBlue,
              fontFamily: 'Courier',
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(action,
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
      ],
    );
  }

  static const Map<NeomFractalType, String> _fractalNames = {
    NeomFractalType.mandelbrot: 'MANDELBROT',
    NeomFractalType.mandelbrotDeep: 'MANDELBROT DEEP',
    NeomFractalType.julia: 'JULIA SET',
    NeomFractalType.newton: 'NEWTON FRACTAL',
    NeomFractalType.burningShip: 'BURNING SHIP',
    NeomFractalType.multibrot: 'MULTIBROT',
  };
}

class _StateInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _StateInfo(this.label, this.icon, this.color);
}

const Map<NeomNeuroState, _StateInfo> _stateInfo = {
  NeomNeuroState.neutral: _StateInfo('Neutral', Icons.auto_awesome, AppColor.bondiBlue),
  NeomNeuroState.calm: _StateInfo('Calm', Icons.spa, Color(0xFF6A5ACD)),
  NeomNeuroState.focus: _StateInfo('Focus', Icons.psychology, Color(0xFFFFA500)),
  NeomNeuroState.sleep: _StateInfo('Sleep', Icons.nightlight, Color(0xFF4B0082)),
  NeomNeuroState.creativity: _StateInfo('Creative', Icons.palette, Color(0xFFFF69B4)),
  NeomNeuroState.integration: _StateInfo('Integrate', Icons.hub, Color(0xFF00CED1)),
};

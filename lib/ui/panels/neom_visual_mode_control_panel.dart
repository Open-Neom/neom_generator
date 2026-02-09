import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../utils/enums/neom_visual_mode.dart';
import '../neom_generator_controller.dart';

class NeomVisualModeControlPanel extends StatelessWidget {
  const NeomVisualModeControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Sint.find<NeomGeneratorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "MODO DE VISUALIZACIÓN",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            Obx(() => Row(
              children: NeomVisualMode.values.map((mode) {
                final active = controller.visualMode.value == mode;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => controller.setVisualMode(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white12
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? Colors.white38
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            mode == NeomVisualMode.scientific
                                ? Icons.science_outlined
                                : Icons.self_improvement_outlined,
                            color: active
                                ? Colors.white
                                : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mode.name.toUpperCase(),
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),

            const SizedBox(height: 8),

            Obx(() => Text(
              controller.visualMode.value ==
                  NeomVisualMode.scientific
                  ? "Lectura precisa de la señal"
                  : "Visualización fluida y contemplativa",
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

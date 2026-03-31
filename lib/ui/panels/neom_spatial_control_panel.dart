import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../utils/enums/neom_spatial_mode.dart';
import '../neom_generator_controller.dart';

class NeomSpatialControlPanel extends StatelessWidget {
  const NeomSpatialControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Sint.find<NeomGeneratorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ───────── HEADER ─────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "ESPACIALIZACIÓN",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.surround_sound, size: 16, color: Colors.white38),
              ],
            ),

            const SizedBox(height: 12),

            /// ───────── MODO ESPACIAL ─────────
            Obx(() => _paramLabel(
              "MODO",
              controller.spatialMode.value.translationKey.tr,
            )),

            Obx(() => DropdownButton<NeomSpatialMode>(
              value: controller.spatialMode.value,
              isExpanded: true,
              dropdownColor: Colors.black87,
              underline: Container(height: 1, color: Colors.white12),
              items: NeomSpatialMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(
                    mode.translationKey.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (mode) {
                if (mode != null) {
                  controller.setSpatialMode(mode);
                }
              },
            )),

            const SizedBox(height: 14),

            /// ───────── INTENSIDAD ESPACIAL ─────────
            Obx(() => _paramLabel(
              "INTENSIDAD",
              "${(controller.spatialIntensity.value * 100).round()}%",
            )),

            Obx(() => Slider(
              min: 0.0,
              max: 1.0,
              value: controller.spatialIntensity.value,
              onChanged: controller.setSpatialIntensity,
            )),

            const Divider(color: Colors.white12, height: 22),

            /// ───────── ÓRBITA ─────────
            Obx(() {
              if (controller.spatialMode.value != NeomSpatialMode.orbit) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Obx(() => _paramLabel(
                    "VELOCIDAD DE ÓRBITA",
                    controller.orbitSpeed.value.toStringAsFixed(2),
                  )),

                  Obx(() => Slider(
                    min: 0.01,
                    max: 1.0,
                    value: controller.orbitSpeed.value,
                    onChanged: controller.setOrbitSpeed,
                  )),

                  /// 🔹 Dirección de órbita (funcionalidad nueva)
                  const SizedBox(height: 8),

                  Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _orbitDirButton(
                        icon: Icons.rotate_left,
                        active: controller.orbitDirection.value == -1,
                        onTap: () => controller.setOrbitDirection(-1),
                      ),
                      const Text(
                        "DIRECCIÓN",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      _orbitDirButton(
                        icon: Icons.rotate_right,
                        active: controller.orbitDirection.value == 1,
                        onTap: () => controller.setOrbitDirection(1),
                      ),
                    ],
                  )),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ───────── helpers ─────────

  Widget _paramLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Courier',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orbitDirButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? Colors.white : Colors.white38,
        ),
      ),
    );
  }
}

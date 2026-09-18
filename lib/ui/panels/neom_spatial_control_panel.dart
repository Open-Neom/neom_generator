import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../../utils/enums/neom_spatial_mode.dart';
import '../neom_generator_controller.dart';
import '../widgets/chamber_controls.dart';

class NeomSpatialControlPanel extends StatelessWidget {
  final NeomGeneratorController? controller;
  const NeomSpatialControlPanel({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final control = controller ?? Sint.find<NeomGeneratorController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    GeneratorTranslationConstants.spatiality.tr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.surround_sound,
                  size: 20,
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.modeControl.tr,
                control.spatialMode.value.translationKey.tr,
              ),
            ),
            Obx(
              () => DropdownButton<NeomSpatialMode>(
                value: control.spatialMode.value,
                isExpanded: true,
                itemHeight: null,
                dropdownColor: Colors.black87,
                items: NeomSpatialMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            mode.translationKey.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) control.setSpatialMode(mode);
                },
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.intensityControl.tr,
                '${(control.spatialIntensity.value * 100).round()}%',
              ),
            ),
            Obx(
              () => Slider(
                min: 0,
                max: 1,
                value: control.spatialIntensity.value,
                semanticFormatterCallback: (value) =>
                    '${GeneratorTranslationConstants.intensityControl.tr}: ${(value * 100).round()}%',
                onChanged: control.setSpatialIntensity,
              ),
            ),
            Obx(() {
              if (control.spatialMode.value != NeomSpatialMode.orbit) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12, height: 22),
                  ChamberParameterLabel(
                    GeneratorTranslationConstants.orbitSpeedControl.tr,
                    control.orbitSpeed.value.toStringAsFixed(2),
                  ),
                  Slider(
                    min: .01,
                    max: 1,
                    value: control.orbitSpeed.value,
                    semanticFormatterCallback: (value) =>
                        '${GeneratorTranslationConstants.orbitSpeedControl.tr}: ${value.toStringAsFixed(2)}',
                    onChanged: control.setOrbitSpeed,
                  ),
                  Text(GeneratorTranslationConstants.directionControl.tr),
                  Wrap(
                    spacing: 12,
                    children: [
                      _directionButton(
                        icon: Icons.rotate_left,
                        label:
                            GeneratorTranslationConstants.orbitLeftControl.tr,
                        active: control.orbitDirection.value == -1,
                        onPressed: () => control.setOrbitDirection(-1),
                      ),
                      _directionButton(
                        icon: Icons.rotate_right,
                        label:
                            GeneratorTranslationConstants.orbitRightControl.tr,
                        active: control.orbitDirection.value == 1,
                        onPressed: () => control.setOrbitDirection(1),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _directionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) => Semantics(
    selected: active,
    child: IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: label,
      onPressed: onPressed,
      color: active ? Colors.white : Colors.white54,
      style: IconButton.styleFrom(
        backgroundColor: active ? Colors.white12 : Colors.transparent,
      ),
      icon: Icon(icon),
    ),
  );
}

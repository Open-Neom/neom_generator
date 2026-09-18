import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_breath_engine.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';
import '../widgets/chamber_controls.dart';

class NeomBreathControlPanel extends StatelessWidget {
  final NeomGeneratorController? controller;
  const NeomBreathControlPanel({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? Sint.find<NeomGeneratorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(GeneratorTranslationConstants.breathing.tr),

            const SizedBox(height: 12),

            Obx(
              () => DropdownButton<NeomBreathMode>(
                value: controller.breathMode.value,
                isExpanded: true,
                itemHeight: null,
                dropdownColor: Colors.black87,
                underline: Container(height: 1, color: Colors.white12),
                items: NeomBreathMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(
                      mode.translationKey.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) controller.setBreathMode(v);
                },
              ),
            ),

            const SizedBox(height: 12),

            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.breathRateControl.tr,
                controller.breathRate.value.toStringAsFixed(1),
              ),
            ),

            Obx(
              () => Slider(
                min: 3,
                max: 12,
                value: controller.breathRate.value,
                onChanged: controller.setBreathRate,
              ),
            ),

            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.breathDepthControl.tr,
                "${(controller.breathDepth.value * 100).round()}%",
              ),
            ),

            Obx(
              () => Slider(
                min: 0,
                max: 1,
                value: controller.breathDepth.value,
                onChanged: controller.setBreathDepth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 11,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
    ),
  );
}

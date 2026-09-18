import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_modulator_engine.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';
import '../widgets/chamber_controls.dart';

class NeomModulationControlPanel extends StatelessWidget {
  final NeomGeneratorController? controller;
  const NeomModulationControlPanel({super.key, this.controller});

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
            _header(
              GeneratorTranslationConstants.isochronicPulse.tr,
              Obx(
                () => Switch(
                  value: control.isIsochronicEnabled.value,
                  onChanged: control.setIsochronicEnabled,
                ),
              ),
            ),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.frequency.tr,
                '${control.isochronicFreq.value.toStringAsFixed(1)} Hz',
              ),
            ),
            Obx(
              () => Slider(
                min: .5,
                max: 40,
                label: '${control.isochronicFreq.value.toStringAsFixed(1)} Hz',
                semanticFormatterCallback: (value) =>
                    '${GeneratorTranslationConstants.frequency.tr}: ${value.toStringAsFixed(1)} Hz',
                value: control.isochronicFreq.value,
                onChanged: control.setIsochronicFrequency,
              ),
            ),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.isochronicDuty.tr,
                '${(control.isochronicDuty.value * 100).round()}%',
              ),
            ),
            Obx(
              () => Slider(
                min: .1,
                max: 1,
                semanticFormatterCallback: (value) =>
                    '${GeneratorTranslationConstants.isochronicDuty.tr}: ${(value * 100).round()}%',
                value: control.isochronicDuty.value,
                onChanged: control.setIsochronicDuty,
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
            _header(
              GeneratorTranslationConstants.modulation.tr,
              Obx(
                () => Switch(
                  value: control.isModulationEnabled.value,
                  onChanged: control.setModulationEnabled,
                ),
              ),
            ),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.typeControl.tr,
                control.modulationType.value.translationKey.tr,
              ),
            ),
            Obx(
              () => DropdownButton<NeomModulationType>(
                value: control.modulationType.value,
                isExpanded: true,
                itemHeight: null,
                dropdownColor: Colors.black87,
                items: NeomModulationType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            type.translationKey.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: control.isModulationEnabled.value
                    ? (value) {
                        if (value != null) control.setModulationType(value);
                      }
                    : null,
              ),
            ),
            Obx(
              () => ChamberParameterLabel(
                GeneratorTranslationConstants.intensityControl.tr,
                '${(control.modulationDepth.value * 100).round()}%',
              ),
            ),
            Obx(
              () => Slider(
                min: 0,
                max: 1,
                value: control.modulationDepth.value,
                semanticFormatterCallback: (value) =>
                    '${GeneratorTranslationConstants.intensityControl.tr}: ${(value * 100).round()}%',
                onChanged: control.isModulationEnabled.value
                    ? control.setModulationDepth
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, Widget toggle) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Semantics(label: title, child: toggle),
    ],
  );
}

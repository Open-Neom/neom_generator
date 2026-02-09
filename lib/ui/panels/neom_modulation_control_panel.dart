import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_modulator_engine.dart';
import '../neom_generator_controller.dart';

class NeomModulationControlPanel extends StatelessWidget {
  const NeomModulationControlPanel({super.key});

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

            /// ───────── ISOCRÓNICO ─────────
            _sectionHeader(
              title: "ISOCRÓNICO (AM)",
              switchWidget: Obx(() => Switch(
                value: controller.isIsochronicEnabled.value,
                onChanged: controller.setIsochronicEnabled,
              )),
            ),

            _paramLabel("FRECUENCIA", "${controller.isochronicFreq.value.toStringAsFixed(1)} Hz"),
            Obx(() => Slider(
              min: 0.5,
              max: 40,
              value: controller.isochronicFreq.value,
              onChanged: controller.setIsochronicFrequency,
            )),

            _paramLabel("DUTY", "${(controller.isochronicDuty.value * 100).round()}%"),
            Obx(() => Slider(
              min: 0.1,
              max: 1.0,
              value: controller.isochronicDuty.value,
              onChanged: controller.setIsochronicDuty,
            )),

            _divider(),

            /// ───────── MODULACIÓN ─────────
            _sectionHeader(
              title: "MODULACIÓN (FM / PHASE)",
              switchWidget: Obx(() => Switch(
                value: controller.isModulationEnabled.value,
                onChanged: controller.setModulationEnabled,
              )),
            ),

            _paramLabel(
              "TIPO",
              controller.modulationType.value.name.toUpperCase(),
            ),

            Obx(() => DropdownButton<NeomModulationType>(
              value: controller.modulationType.value,
              isExpanded: true,
              underline: Container(height: 1, color: Colors.white12),
              dropdownColor: Colors.black87,
              items: NeomModulationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    type.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
              onChanged: controller.isModulationEnabled.value
                  ? (v) => v != null ? controller.setModulationType(v) : null
                  : null,
            )),

            _paramLabel(
              "INTENSIDAD",
              "${(controller.modulationDepth.value * 100).round()}%",
            ),

            Obx(() => Slider(
              min: 0,
              max: 1,
              value: controller.modulationDepth.value,
              onChanged: controller.isModulationEnabled.value
                  ? controller.setModulationDepth
                  : null,
            )),
          ],
        ),
      ),
    );
  }

  // ───────── helpers ─────────

  Widget _sectionHeader({required String title, required Widget switchWidget}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        switchWidget,
      ],
    );
  }

  Widget _paramLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
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

  Widget _divider() => const Divider(color: Colors.white12, height: 20);
}

import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../engine/neom_breath_engine.dart';
import '../neom_generator_controller.dart';

class NeomBreathControlPanel extends StatelessWidget {
  const NeomBreathControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Sint.find<NeomGeneratorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _header("RESPIRACIÓN SINCRONIZADA"),

            const SizedBox(height: 12),

            Obx(() => DropdownButton<NeomBreathMode>(
              value: controller.breathMode.value,
              isExpanded: true,
              dropdownColor: Colors.black87,
              underline: Container(height: 1, color: Colors.white12),
              items: NeomBreathMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(
                    mode.name.toUpperCase(),
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
            )),

            const SizedBox(height: 12),

            _label("RITMO (resp/min)",
                controller.breathRate.value.toStringAsFixed(1)),

            Obx(() => Slider(
              min: 3,
              max: 12,
              value: controller.breathRate.value,
              onChanged: controller.setBreathRate,
            )),

            _label("PROFUNDIDAD",
                "${(controller.breathDepth.value * 100).round()}%"),

            Obx(() => Slider(
              min: 0,
              max: 1,
              value: controller.breathDepth.value,
              onChanged: controller.setBreathDepth,
            )),
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

  Widget _label(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'Courier')),
      ],
    ),
  );
}

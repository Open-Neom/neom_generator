import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../utils/enums/neom_neuro_state.dart';
import '../neom_generator_controller.dart';

class NeomNeuroStateControlPanel extends StatelessWidget {
  const NeomNeuroStateControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Sint.find<NeomGeneratorController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _header("ESTADO NEURO-ARMÓNICO"),

            const SizedBox(height: 14),

            Obx(() => Wrap(
              spacing: 18,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: NeomNeuroState.values.map((state) {
                final bool active =
                    controller.neuroState.value == state;

                return InkWell(
                  onTap: () => controller.setNeuroState(state),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white12
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: active
                            ? Colors.white38
                            : Colors.white12,
                      ),
                    ),
                    child: Text(
                      state.name.toUpperCase(),
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 15,
                        letterSpacing: 1.2,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
            const SizedBox(height: 10),
            const Text(
              "El sistema ajusta respiración, modulación y espacialidad.",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.3,
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
      letterSpacing: 1.6,
      fontWeight: FontWeight.w600,
    ),
  );
}

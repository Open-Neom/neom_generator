import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:sint/sint.dart';

import '../../data/incienso_catalog.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../incienso/incienso_detail_sheet.dart';
import '../neom_generator_controller.dart';

class NeomNeuroStateControlPanel extends StatefulWidget {
  const NeomNeuroStateControlPanel({super.key});

  @override
  State<NeomNeuroStateControlPanel> createState() => _NeomNeuroStateControlPanelState();
}

class _NeomNeuroStateControlPanelState extends State<NeomNeuroStateControlPanel> {
  NeomNeuroState _selectedFilter = NeomNeuroState.calm;

  static const _stateColors = {
    NeomNeuroState.sleep: Color(0xFF6C63FF),
    NeomNeuroState.calm: Color(0xFF4FC3F7),
    NeomNeuroState.neutral: AppColor.bondiBlue,
    NeomNeuroState.creativity: Color(0xFFAB47BC),
    NeomNeuroState.focus: Color(0xFF66BB6A),
    NeomNeuroState.integration: Color(0xFFFFB74D),
  };

  @override
  Widget build(BuildContext context) {
    final controller = Sint.find<NeomGeneratorController>();
    final locale = Sint.locale?.languageCode ?? 'es';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Builder(builder: (context) {
          final current = _selectedFilter;
          final color = _stateColors[current] ?? AppColor.bondiBlue;
          final related = InciensoCatalog.all
              .where((i) => i.targetState == current)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── State dropdown ──
              Row(
                children: [
                  Text(
                    GeneratorTranslationConstants.neuroharmony.tr.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70, fontSize: 11,
                      letterSpacing: 1.6, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<NeomNeuroState>(
                        value: current,
                        isDense: true,
                        dropdownColor: const Color(0xFF1A1A2E),
                        icon: Icon(Icons.expand_more, size: 18, color: color),
                        items: NeomNeuroState.values.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(
                              state.nameKey.tr,
                              style: TextStyle(
                                color: _stateColors[state] ?? Colors.white70,
                                fontFamily: 'Courier',
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedFilter = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // ── INCIENSO section ──
              if (related.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 13, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'INCIENSO',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: GeneratorTranslationConstants.helpIncienso.tr,
                      preferBelow: true,
                      showDuration: const Duration(seconds: 8),
                      child: Icon(Icons.info_outline, size: 12, color: color.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: related.map((incienso) {
                    final name = incienso.getName(locale);
                    final shortName = name.split(' ').first;
                    return GestureDetector(
                      onTap: () => InciensoDetailSheet.show(context, incienso, () {
                        controller.setFrequency(incienso.leftFrequencyHz);
                        controller.setBinauralBeat(beat: incienso.binauralBeatHz);
                        controller.setNeuroState(incienso.targetState);
                        if (!controller.isPlaying.value) {
                          controller.playStopPreview();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              incienso.iconCodePoint != null
                                  ? IconData(incienso.iconCodePoint!, fontFamily: 'MaterialIcons')
                                  : Icons.local_fire_department,
                              size: 12, color: color,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              shortName,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            if (incienso.isPro) ...[
                              const SizedBox(width: 4),
                              Text('PRO',
                                style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 7, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

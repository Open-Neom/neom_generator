import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:sint/sint.dart';

import '../../domain/models/incienso.dart';
import '../../utils/constants/generator_translation_constants.dart';

/// Bottom sheet showing Incienso details: description, parameters, and start button.
class InciensoDetailSheet extends StatelessWidget {
  final Incienso incienso;
  final VoidCallback onStart;

  const InciensoDetailSheet({
    super.key,
    required this.incienso,
    required this.onStart,
  });

  static void show(BuildContext context, Incienso incienso, VoidCallback onStart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InciensoDetailSheet(incienso: incienso, onStart: onStart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Sint.locale?.languageCode ?? 'es';
    final name = incienso.getName(locale);
    final description = incienso.getDescription(locale);
    final beat = incienso.binauralBeatHz;
    final state = incienso.targetState;
    final duration = incienso.suggestedDuration.inMinutes;
    Color(incienso.screenColorValue).withAlpha(255);
    final accentColor = _stateColor(state);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + name + pro badge
                Row(
                  children: [
                    if (incienso.iconCodePoint != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          IconData(incienso.iconCodePoint!, fontFamily: 'MaterialIcons'),
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (incienso.isPro) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('PRO',
                                    style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${state.name.toUpperCase()} · ${beat.toStringAsFixed(1)} Hz · $duration min',
                            style: TextStyle(color: accentColor.withAlpha(150), fontSize: 12, fontFamily: 'Courier'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),

                const SizedBox(height: 20),

                // Parameter chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('${incienso.leftFrequencyHz.toStringAsFixed(0)} Hz L', Icons.hearing, accentColor),
                    _chip('${incienso.rightFrequencyHz.toStringAsFixed(0)} Hz R', Icons.hearing, accentColor),
                    _chip('${beat.toStringAsFixed(1)} Hz beat', Icons.waves, accentColor),
                    _chip('$duration min', Icons.timer, accentColor),
                    if (incienso.defaultVisual != null)
                      _chip(incienso.defaultVisual!.name, Icons.visibility, accentColor),
                    if (incienso.isMultiPhase)
                      _chip('${incienso.phases.length} fases', Icons.timeline, accentColor),
                    if (incienso.requiresHeadphones)
                      _chip('Headphones', Icons.headphones, accentColor),
                    ...incienso.tags.map((t) => _chip(t, Icons.tag, accentColor)),
                  ],
                ),

                const SizedBox(height: 24),

                // Start button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onStart();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      GeneratorTranslationConstants.activateChamber.tr.toUpperCase(),
                      style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withAlpha(40),
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: accentColor.withAlpha(80)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withAlpha(150)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withAlpha(200), fontSize: 11, fontFamily: 'Courier')),
        ],
      ),
    );
  }

  Color _stateColor(NeomNeuroState state) {
    switch (state) {
      case NeomNeuroState.sleep: return const Color(0xFF6C63FF);
      case NeomNeuroState.calm: return const Color(0xFF4FC3F7);
      case NeomNeuroState.neutral: return AppColor.bondiBlue;
      case NeomNeuroState.creativity: return const Color(0xFFAB47BC);
      case NeomNeuroState.focus: return const Color(0xFF66BB6A);
      case NeomNeuroState.integration: return const Color(0xFFFFB74D);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:sint/sint.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    ...incienso.tags.map((t) => _chip(t, Icons.tag, accentColor)),
                  ],
                ),

                // Compatibility sources
                const SizedBox(height: 12),
                _CompatibilityRow(
                  compatibility: incienso.compatibility,
                  accentColor: accentColor,
                ),

                // References (expandable)
                if (incienso.references.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReferencesSection(
                    references: incienso.references,
                    accentColor: accentColor,
                  ),
                ],

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

/// Expandable section showing scientific references for research-based inciensos.
class _ReferencesSection extends StatefulWidget {
  final List<InciensoReference> references;
  final Color accentColor;

  const _ReferencesSection({
    required this.references,
    required this.accentColor,
  });

  @override
  State<_ReferencesSection> createState() => _ReferencesSectionState();
}

class _ReferencesSectionState extends State<_ReferencesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.accentColor.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.accentColor.withAlpha(25)),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 14, color: widget.accentColor.withAlpha(150)),
                const SizedBox(width: 8),
                Text(
                  'Referencias (${widget.references.length})',
                  style: TextStyle(
                    color: widget.accentColor.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: widget.accentColor.withAlpha(120),
                ),
              ],
            ),
          ),
        ),

        // Expandable list
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: widget.references.map((ref) => _referenceCard(ref)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _referenceCard(InciensoReference ref) {
    final hasLink = ref.link.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: hasLink ? () => _openLink(ref.link) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Citation + year
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.citation,
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasLink)
                    Icon(Icons.open_in_new, size: 12, color: widget.accentColor.withAlpha(100)),
                ],
              ),
              const SizedBox(height: 3),

              // Title
              Text(
                ref.title,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Journal + finding
              if (ref.journal.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ref.journal,
                  style: TextStyle(
                    color: Colors.white.withAlpha(80),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                ref.finding,
                style: TextStyle(
                  color: widget.accentColor.withAlpha(140),
                  fontSize: 10,
                  fontFamily: 'Courier',
                ),
              ),

              // Evidence + Safety + Source badges
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _evidenceBadge(ref.studyTypeLabel, _studyTypeColor(ref.studyType)),
                  _evidenceBadge(ref.evidenceLevelLabel, _evidenceLevelColor(ref.evidenceLevel)),
                  _evidenceBadge(ref.safetyLabel, _safetyColor(ref.safetyProfile)),
                  if (ref.sampleSize != null)
                    _evidenceBadge('n=${ref.sampleSize}', Colors.white54),
                  if (ref.doi != null)
                    _badge('DOI', widget.accentColor),
                  if (ref.pmcId != null)
                    _badge(ref.pmcId!, widget.accentColor),
                ],
              ),

              // Safety note
              if (ref.safetyNote != null) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 10,
                      color: _safetyColor(ref.safetyProfile).withAlpha(150)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ref.safetyNote!,
                        style: TextStyle(
                          color: _safetyColor(ref.safetyProfile).withAlpha(150),
                          fontSize: 9,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withAlpha(120), fontSize: 9, fontFamily: 'Courier'),
      ),
    );
  }

  Widget _evidenceBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withAlpha(200), fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _studyTypeColor(StudyType type) {
    switch (type) {
      case StudyType.metaAnalysis: return const Color(0xFF4CAF50);
      case StudyType.rctDoubleBlind: return const Color(0xFF66BB6A);
      case StudyType.rct: return const Color(0xFF81C784);
      case StudyType.controlledStudy: return const Color(0xFF4FC3F7);
      case StudyType.pilotStudy: return const Color(0xFFFFB74D);
      case StudyType.inVitro: return const Color(0xFFBA68C8);
      case StudyType.preclinical: return const Color(0xFFAB47BC);
      case StudyType.caseReport: return const Color(0xFFE0E0E0);
    }
  }

  Color _evidenceLevelColor(EvidenceLevel level) {
    switch (level) {
      case EvidenceLevel.high: return const Color(0xFF4CAF50);
      case EvidenceLevel.moderateHigh: return const Color(0xFF8BC34A);
      case EvidenceLevel.moderate: return const Color(0xFFFFEB3B);
      case EvidenceLevel.lowModerate: return const Color(0xFFFFB74D);
      case EvidenceLevel.low: return const Color(0xFFFF8A65);
    }
  }

  Color _safetyColor(SafetyProfile safety) {
    switch (safety) {
      case SafetyProfile.noRisk: return const Color(0xFF4CAF50);
      case SafetyProfile.minimal: return const Color(0xFF8BC34A);
      case SafetyProfile.low: return const Color(0xFFFFEB3B);
      case SafetyProfile.moderate: return const Color(0xFFFF8A65);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Row of output source icons with effectiveness indicator.
class _CompatibilityRow extends StatelessWidget {
  final Map<OutputSource, SourceEffectiveness> compatibility;
  final Color accentColor;

  const _CompatibilityRow({
    required this.compatibility,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: optimal first, then effective, partial, notRecommended
    final sorted = compatibility.entries.toList()
      ..sort((a, b) => a.value.index.compareTo(b.value.index));

    return Row(
      children: [
        Icon(Icons.speaker_group_outlined, size: 12, color: accentColor.withAlpha(100)),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: sorted.map((e) => _sourceChip(e.key, e.value)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sourceChip(OutputSource source, SourceEffectiveness effectiveness) {
    final color = _effectivenessColor(effectiveness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_sourceIcon(source), size: 11, color: color.withAlpha(180)),
          const SizedBox(width: 3),
          Text(
            _sourceLabel(source),
            style: TextStyle(color: color.withAlpha(200), fontSize: 9, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 3),
          _effectivenessDot(effectiveness, color),
        ],
      ),
    );
  }

  Widget _effectivenessDot(SourceEffectiveness eff, Color color) {
    final int bars = switch (eff) {
      SourceEffectiveness.optimal => 3,
      SourceEffectiveness.effective => 2,
      SourceEffectiveness.partial => 1,
      SourceEffectiveness.notRecommended => 0,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Container(
        width: 3,
        height: 6 + i * 2.0,
        margin: const EdgeInsets.only(left: 1),
        decoration: BoxDecoration(
          color: i < bars ? color.withAlpha(180) : color.withAlpha(30),
          borderRadius: BorderRadius.circular(1),
        ),
      )),
    );
  }

  IconData _sourceIcon(OutputSource source) {
    switch (source) {
      case OutputSource.headphones: return Icons.headphones;
      case OutputSource.speakers: return Icons.speaker;
      case OutputSource.smartphone: return Icons.smartphone;
      case OutputSource.subwoofer: return Icons.surround_sound;
      case OutputSource.boneConduction: return Icons.hearing;
      case OutputSource.sleepBand: return Icons.bedtime;
    }
  }

  String _sourceLabel(OutputSource source) {
    switch (source) {
      case OutputSource.headphones: return 'Headphones';
      case OutputSource.speakers: return 'Speakers';
      case OutputSource.smartphone: return 'Phone';
      case OutputSource.subwoofer: return 'Subwoofer';
      case OutputSource.boneConduction: return 'Bone';
      case OutputSource.sleepBand: return 'Sleep';
    }
  }

  Color _effectivenessColor(SourceEffectiveness eff) {
    switch (eff) {
      case SourceEffectiveness.optimal: return const Color(0xFF4CAF50);
      case SourceEffectiveness.effective: return const Color(0xFF8BC34A);
      case SourceEffectiveness.partial: return const Color(0xFFFFB74D);
      case SourceEffectiveness.notRecommended: return const Color(0xFFE57373);
    }
  }
}

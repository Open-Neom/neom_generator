import 'package:flutter/material.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/web_content_wrapper.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_states/data/state_catalog.dart';
import 'package:neom_states/domain/models/frequency_state.dart';
import 'package:sint/sint.dart';

import '../../data/incienso_catalog.dart';
import '../../domain/models/incienso.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../incienso/incienso_detail_sheet.dart';

class NeomExperiencesPage extends StatelessWidget {
  const NeomExperiencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Sint.locale?.languageCode ?? 'es';

    return Scaffold(
      backgroundColor: AppFlavour.getBackgroundColor(),
      appBar: SintAppBar(
        title: GeneratorTranslationConstants.experiences.tr,
      ),
      body: WebContentWrapper(
        maxWidth: 900,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.appBoxDecoration,
          child: ListView(
            children: [
              // ═══ EXPERIENCIAS ═══
              _sectionHeader(
                icon: Icons.auto_awesome,
                title: GeneratorTranslationConstants.experiences.tr,
                subtitle: GeneratorTranslationConstants.experiencesSubtitle.tr,
                color: AppColor.bondiBlue,
              ),
              const SizedBox(height: 12),
              _experienceCard(
                icon: Icons.blur_on,
                title: GeneratorTranslationConstants.neuroFlocking.tr,
                color: Colors.cyan,
                onTap: () => Sint.toNamed(AppRouteConstants.flockingFullscreen),
              ),
              _experienceCard(
                icon: Icons.self_improvement,
                title: GeneratorTranslationConstants.neuroBreathing.tr,
                color: Colors.green,
                onTap: () => Sint.toNamed(AppRouteConstants.breathingFullscreen),
              ),
              _experienceCard(
                icon: Icons.auto_awesome,
                title: GeneratorTranslationConstants.fractalVisualization.tr,
                color: Colors.purple,
                onTap: () => Sint.toNamed(AppRouteConstants.fractalFullscreen),
              ),
              _experienceCard(
                icon: Icons.threed_rotation,
                title: GeneratorTranslationConstants.neuroVR360.tr,
                color: Colors.orange,
                onTap: () => Sint.toNamed(AppRouteConstants.spatial360Fullscreen),
              ),
              _experienceCard(
                icon: Icons.view_in_ar,
                title: GeneratorTranslationConstants.neuroVR360Stereo.tr,
                color: Colors.deepOrange,
                onTap: () => Sint.toNamed(AppRouteConstants.vr360StereoFullscreen),
              ),

              const SizedBox(height: 28),

              // ═══ INCIENSOS ═══
              _sectionHeader(
                icon: Icons.local_fire_department,
                title: 'INCIENSO',
                subtitle: locale == 'es'
                    ? 'Protocolos de frecuencia basados en investigación científica'
                    : 'Evidence-based frequency protocols',
                color: const Color(0xFFFF6D00),
              ),
              const SizedBox(height: 12),
              ...InciensoCatalog.free.map((i) => _inciensoCard(context, i, locale)),
              if (InciensoCatalog.pro.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('PRO', style: TextStyle(color: Colors.amber.withAlpha(150), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                      ),
                      const Expanded(child: Divider(color: Colors.white12)),
                    ],
                  ),
                ),
                ...InciensoCatalog.pro.map((i) => _inciensoCard(context, i, locale)),
              ],

              const SizedBox(height: 28),

              // ═══ ESTADOS ═══
              _sectionHeader(
                icon: Icons.psychology,
                title: GeneratorTranslationConstants.states.tr,
                subtitle: GeneratorTranslationConstants.statesSubtitle.tr,
                color: Colors.amber,
              ),
              const SizedBox(height: 12),
              ...StateCatalog.free.map((state) => _stateCard(state, locale)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: color.withAlpha(160), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _experienceCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color.withAlpha(100), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateCard(FrequencyState state, String locale) {
    final name = state.names[locale] ?? state.names['es'] ?? state.id;
    final beatHz = (state.rightFrequency - state.leftFrequency).abs();
    final minutes = state.duration.inMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Sint.toNamed('/x/${state.id}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: state.screenColor.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: state.screenColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: state.screenColor.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(state.icon, color: state.screenColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: state.screenColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${beatHz.toStringAsFixed(0)} Hz · $minutes min',
                        style: TextStyle(
                          color: state.screenColor.withAlpha(120),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_outline, color: state.screenColor.withAlpha(100), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inciensoCard(BuildContext context, Incienso incienso, String locale) {
    final name = incienso.getName(locale);
    final beat = incienso.binauralBeatHz;
    final minutes = incienso.suggestedDuration.inMinutes;
    final color = _stateColor(incienso.targetState);
    final description = incienso.getDescription(locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => InciensoDetailSheet.show(context, incienso, () {
            // TODO: load incienso into generator and start
            Sint.toNamed(AppRouteConstants.generator);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    incienso.iconCodePoint != null
                        ? IconData(incienso.iconCodePoint!, fontFamily: 'MaterialIcons')
                        : Icons.local_fire_department,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (incienso.isPro) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(30),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('PRO',
                                  style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${beat.toStringAsFixed(1)} Hz · $minutes min',
                        style: TextStyle(color: color.withAlpha(120), fontSize: 11, fontFamily: 'Courier'),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.info_outline, color: color.withAlpha(80), size: 18),
              ],
            ),
          ),
        ),
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

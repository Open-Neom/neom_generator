import 'package:flutter/material.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import '../../data/firestore/incienso_firestore.dart';
import '../../domain/models/incienso.dart';
import '../incienso/incienso_detail_sheet.dart';

class InciensoExplorePage extends StatefulWidget {
  const InciensoExplorePage({super.key});

  @override
  State<InciensoExplorePage> createState() => _InciensoExplorePageState();
}

class _InciensoExplorePageState extends State<InciensoExplorePage> {
  final InciensoFirestore _firestoreService = InciensoFirestore();
  List<Incienso> _allInciensos = [];
  List<Incienso> _filteredInciensos = [];
  bool _isLoading = true;
  String _selectedTag = 'all';

  final List<String> _filterTags = ['all', 'sleep', 'focus', 'calm', 'creativity', 'integration'];

  @override
  void initState() {
    super.initState();
    _loadPublicInciensos();
  }

  Future<void> _loadPublicInciensos() async {
    setState(() => _isLoading = true);
    final list = await _firestoreService.fetchPublic(limit: 50);
    setState(() {
      _allInciensos = list;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_selectedTag == 'all') {
      _filteredInciensos = List.from(_allInciensos);
    } else {
      _filteredInciensos = _allInciensos.where((i) {
        final stateName = i.targetState.name.toLowerCase();
        return stateName == _selectedTag || i.tags.any((t) => t.toLowerCase() == _selectedTag);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Sint.locale?.languageCode ?? 'es';

    return Scaffold(
      backgroundColor: AppFlavour.getBackgroundColor(),
      appBar: SintAppBar(
        title: locale == 'es' ? 'Explorar Comunidad' : 'Explore Community',
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.appBoxDecoration,
        child: Column(
          children: [
            _buildTagsRow(),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: AppColor.bondiBlue,
                backgroundColor: const Color(0xFF0D0D1A),
                onRefresh: _loadPublicInciensos,
                child: _isLoading
                    ? _buildLoader()
                    : _filteredInciensos.isEmpty
                        ? _buildEmptyState(locale)
                        : _buildList(locale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsRow() {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterTags.length,
        itemBuilder: (context, index) {
          final tag = _filterTags[index];
          final isSelected = _selectedTag == tag;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                tag.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedTag = tag;
                    _applyFilter();
                  });
                }
              },
              selectedColor: AppColor.bondiBlue.withAlpha(80),
              backgroundColor: Colors.white.withAlpha(8),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColor.bondiBlue : Colors.white12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColor.bondiBlue),
          SizedBox(height: 16),
          Text(
            'Sintonizando ondas de la comunidad...',
            style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.waves_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            locale == 'es'
                ? 'No se encontraron Inciensos en esta frecuencia'
                : 'No Inciensos found on this frequency',
            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            locale == 'es'
                ? '¡Sé el primero en grabar y compartir uno!'
                : 'Be the first to record and share one!',
            style: const TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String locale) {
    return ListView.builder(
      itemCount: _filteredInciensos.length,
      itemBuilder: (context, index) {
        final incienso = _filteredInciensos[index];
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
                Sint.toNamed(AppRouteConstants.generator, arguments: [incienso]);
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
                            : Icons.local_fire_department_rounded,
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
                          Row(
                            children: [
                              Text(
                                '${beat.toStringAsFixed(1)} Hz · $minutes min',
                                style: TextStyle(color: color.withAlpha(120), fontSize: 11, fontFamily: 'Courier'),
                              ),
                              const Spacer(),
                              Icon(Icons.play_arrow_rounded, size: 12, color: color.withAlpha(120)),
                              const SizedBox(width: 2),
                              Text(
                                '${incienso.practiceCount}',
                                style: TextStyle(color: color.withAlpha(150), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
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
                    const SizedBox(width: 10),
                    Icon(Icons.info_outline, color: color.withAlpha(80), size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

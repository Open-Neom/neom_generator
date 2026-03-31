import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../domain/models/incienso_review.dart';
import '../../domain/models/incienso_session.dart';
import '../../utils/constants/generator_translation_constants.dart';

/// Summary data passed to [InciensoReviewModal].
class InciensoSessionSummary {
  final String sessionId;
  final String? inciensoId;
  final String? userId;
  final int inciensoCount;
  final InciensoQualityTier qualityTier;
  final Duration duration;
  final double avgCoherence;

  const InciensoSessionSummary({
    required this.sessionId,
    this.inciensoId,
    this.userId,
    required this.inciensoCount,
    required this.qualityTier,
    required this.duration,
    required this.avgCoherence,
  });

  /// Convenience factory from a full [InciensoSession].
  factory InciensoSessionSummary.fromSession(InciensoSession session) {
    return InciensoSessionSummary(
      sessionId: session.id,
      inciensoId: session.inciensoId,
      userId: session.userId,
      inciensoCount: session.inciensoCount,
      qualityTier: session.qualityTier,
      duration: session.duration,
      avgCoherence: session.avgCoherence,
    );
  }
}

// ── Colors ──

const _kDeepPurple = Color(0xFF1A0A2E);
const _kMidPurple = Color(0xFF2D1B69);
const _kAccentCyan = Color(0xFF00BCD4);
const _kGlassWhite = Color(0x1AFFFFFF);
const _kGlassBorder = Color(0x33FFFFFF);

// ── Tag keys (translation constant keys) ──

const List<String> _kTagKeys = [
  GeneratorTranslationConstants.reviewTagSleep,
  GeneratorTranslationConstants.reviewTagStudy,
  GeneratorTranslationConstants.reviewTagAnxiety,
  GeneratorTranslationConstants.reviewTagCreativity,
  GeneratorTranslationConstants.reviewTagMeditate,
  GeneratorTranslationConstants.reviewTagWorkout,
  GeneratorTranslationConstants.reviewTagPain,
  GeneratorTranslationConstants.reviewTagFocus,
];

/// Post-session review modal for the INCIENSO system.
///
/// Call [InciensoReviewModal.show] after a Camara Neom session.
/// Returns an [InciensoReview] if the user saves, or `null` if skipped.
class InciensoReviewModal extends StatefulWidget {
  final InciensoSessionSummary summary;

  const InciensoReviewModal._({required this.summary});

  /// Show the review modal and return the review data (null if skipped).
  static Future<InciensoReview?> show(
    BuildContext context, {
    required InciensoSessionSummary sessionSummary,
  }) {
    return showGeneralDialog<InciensoReview?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'InciensoReview',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return InciensoReviewModal._(summary: sessionSummary);
      },
    );
  }

  @override
  State<InciensoReviewModal> createState() => _InciensoReviewModalState();
}

class _InciensoReviewModalState extends State<InciensoReviewModal> {
  InciensoEmotion? _selectedEmotion;
  InciensoIntensity? _selectedIntensity;
  bool? _recommended;
  final Set<String> _selectedTags = {};
  final TextEditingController _noteController = TextEditingController();

  bool get _canSave =>
      _selectedEmotion != null &&
      _selectedIntensity != null &&
      _recommended != null;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  void _onSkip() => Navigator.of(context).pop(null);

  void _onSave() {
    if (!_canSave) return;
    final review = InciensoReview(
      sessionId: widget.summary.sessionId,
      inciensoId: widget.summary.inciensoId,
      userId: widget.summary.userId,
      timestamp: DateTime.now(),
      emotion: _selectedEmotion!,
      intensity: _selectedIntensity!,
      recommended: _recommended!,
      tags: _selectedTags.toList(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    Navigator.of(context).pop(review);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth > 540 ? 500.0 : screenWidth * 0.92;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: modalWidth,
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
            color: _kDeepPurple.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kGlassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: _kAccentCyan.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 16),
                    _buildEmotionSection(),
                    const SizedBox(height: 18),
                    _buildIntensitySection(),
                    const SizedBox(height: 18),
                    _buildRecommendSection(),
                    const SizedBox(height: 18),
                    _buildTagsSection(),
                    const SizedBox(height: 16),
                    _buildNoteField(),
                    const SizedBox(height: 20),
                    _buildButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Summary section ──

  Widget _buildSummarySection() {
    final summary = widget.summary;
    final coherencePercent = (summary.avgCoherence * 100).toStringAsFixed(0);
    final tier = summary.qualityTier;

    return Column(
      children: [
        // INCIENSO count with glow
        Text(
          '${summary.inciensoCount}',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: _kAccentCyan.withValues(alpha: 0.7),
                blurRadius: 24,
              ),
              Shadow(
                color: _kAccentCyan.withValues(alpha: 0.4),
                blurRadius: 48,
              ),
            ],
          ),
        ),
        Text(
          'INCIENSO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kAccentCyan.withValues(alpha: 0.8),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        // Quality tier badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kGlassWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _kAccentCyan.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _tierName(tier),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(
                tier.stars,
                (_) => const Padding(
                  padding: EdgeInsets.only(left: 1),
                  child: Icon(Icons.star, size: 14, color: _kAccentCyan),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Duration + Coherence row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniStat(
              Icons.timer_outlined,
              _formatDuration(summary.duration),
            ),
            const SizedBox(width: 24),
            _buildMiniStat(
              Icons.auto_graph,
              '$coherencePercent%',
            ),
          ],
        ),
      ],
    );
  }

  String _tierName(InciensoQualityTier tier) {
    return switch (tier) {
      InciensoQualityTier.explorer =>
        GeneratorTranslationConstants.reviewTierExplorer.tr,
      InciensoQualityTier.practitioner =>
        GeneratorTranslationConstants.reviewTierPractitioner.tr,
      InciensoQualityTier.master =>
        GeneratorTranslationConstants.reviewTierMaster.tr,
    };
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _kAccentCyan.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Emotion section ──

  Widget _buildEmotionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          GeneratorTranslationConstants.reviewOverallExperience.tr,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: InciensoEmotion.values.map((emotion) {
            final isSelected = _selectedEmotion == emotion;
            return GestureDetector(
              onTap: () => setState(() => _selectedEmotion = emotion),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kAccentCyan.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _kAccentCyan
                        : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emotion.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emotionLabel(emotion),
                      style: TextStyle(
                        color: isSelected ? _kAccentCyan : Colors.white54,
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _emotionLabel(InciensoEmotion emotion) {
    return switch (emotion) {
      InciensoEmotion.relaxed =>
        GeneratorTranslationConstants.reviewEmotionRelaxed.tr,
      InciensoEmotion.peaceful =>
        GeneratorTranslationConstants.reviewEmotionPeaceful.tr,
      InciensoEmotion.deep =>
        GeneratorTranslationConstants.reviewEmotionDeep.tr,
      InciensoEmotion.energized =>
        GeneratorTranslationConstants.reviewEmotionEnergized.tr,
      InciensoEmotion.transformed =>
        GeneratorTranslationConstants.reviewEmotionTransformed.tr,
    };
  }

  // ── Intensity section ──

  Widget _buildIntensitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          GeneratorTranslationConstants.reviewIntensityLevel.tr,
        ),
        const SizedBox(height: 8),
        Row(
          children: InciensoIntensity.values.map((intensity) {
            final isSelected = _selectedIntensity == intensity;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIntensity = intensity),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kAccentCyan.withValues(alpha: 0.2)
                          : _kGlassWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _kAccentCyan : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _intensityLabel(intensity),
                        style: TextStyle(
                          color:
                              isSelected ? _kAccentCyan : Colors.white60,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _intensityLabel(InciensoIntensity intensity) {
    return switch (intensity) {
      InciensoIntensity.gentle =>
        GeneratorTranslationConstants.reviewIntensityGentle.tr,
      InciensoIntensity.moderate =>
        GeneratorTranslationConstants.reviewIntensityModerate.tr,
      InciensoIntensity.intense =>
        GeneratorTranslationConstants.reviewIntensityIntense.tr,
    };
  }

  // ── Recommend section ──

  Widget _buildRecommendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          GeneratorTranslationConstants.reviewRecommend.tr,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildThumbButton(
              icon: Icons.thumb_up_outlined,
              selected: _recommended == true,
              onTap: () => setState(() => _recommended = true),
            ),
            const SizedBox(width: 20),
            _buildThumbButton(
              icon: Icons.thumb_down_outlined,
              selected: _recommended == false,
              onTap: () => setState(() => _recommended = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThumbButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? _kAccentCyan.withValues(alpha: 0.2)
              : _kGlassWhite,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _kAccentCyan : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: selected ? _kAccentCyan : Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  // ── Tags section ──

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          GeneratorTranslationConstants.reviewTags.tr,
          optional: true,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kTagKeys.map((tagKey) {
            final isSelected = _selectedTags.contains(tagKey);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tagKey);
                  } else {
                    _selectedTags.add(tagKey);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kAccentCyan.withValues(alpha: 0.2)
                      : _kGlassWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _kAccentCyan : Colors.white12,
                  ),
                ),
                child: Text(
                  tagKey.tr,
                  style: TextStyle(
                    color: isSelected ? _kAccentCyan : Colors.white60,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Note field ──

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLength: 200,
      maxLines: 2,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: GeneratorTranslationConstants.reviewNoteHint.tr,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: _kGlassWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        counterStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAccentCyan, width: 1),
        ),
      ),
    );
  }

  // ── Buttons ──

  Widget _buildButtons() {
    return Row(
      children: [
        // Skip
        TextButton(
          onPressed: _onSkip,
          child: Text(
            GeneratorTranslationConstants.reviewSkip.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
        const Spacer(),
        // Save
        GestureDetector(
          onTap: _canSave ? _onSave : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: _canSave
                  ? const LinearGradient(
                      colors: [_kAccentCyan, _kMidPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _canSave ? null : Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              GeneratorTranslationConstants.reviewSave.tr,
              style: TextStyle(
                color: _canSave ? Colors.white : Colors.white30,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  Widget _buildSectionLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(${GeneratorTranslationConstants.reviewOptional.tr})',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

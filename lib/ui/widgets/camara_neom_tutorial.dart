import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';

/// A localized, scrollable guide shared by the mobile and web chamber.
class CamaraNeomTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  const CamaraNeomTutorial({super.key, required this.onComplete});

  static const String _hiveBox = 'settings';
  static const String _hiveKey = 'camara_neom_tutorial_seen';

  static Future<bool> shouldShow() async {
    try {
      final box = await Hive.openBox(_hiveBox);
      return box.get(_hiveKey, defaultValue: false) != true;
    } catch (_) {
      // Storage restrictions must not prevent access to the chamber.
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final box = await Hive.openBox(_hiveBox);
      await box.put(_hiveKey, true);
    } catch (_) {
      // The manual Help button is always available, even without storage.
    }
  }

  @override
  State<CamaraNeomTutorial> createState() => _CamaraNeomTutorialState();
}

class _CamaraNeomTutorialState extends State<CamaraNeomTutorial> {
  int _step = 0;
  static const _steps = [
    (
      Icons.play_circle_outline,
      GeneratorTranslationConstants.neomChamber,
      GeneratorTranslationConstants.guideSound,
    ),
    (
      Icons.tune,
      GeneratorTranslationConstants.frequency,
      GeneratorTranslationConstants.guideFrequency,
    ),
    (
      Icons.mic,
      GeneratorTranslationConstants.detectMyVoice,
      GeneratorTranslationConstants.guideVoice,
    ),
    (
      Icons.surround_sound,
      GeneratorTranslationConstants.modulation,
      GeneratorTranslationConstants.guideEffects,
    ),
    (
      Icons.home_outlined,
      GeneratorTranslationConstants.neomChamber,
      GeneratorTranslationConstants.guideBackground,
    ),
  ];

  void _finish() {
    CamaraNeomTutorial.markSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _steps[_step];
    final last = _step == _steps.length - 1;
    return Material(
      color: Colors.black.withValues(alpha: .94),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_step + 1} / ${_steps.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Icon(entry.$1, color: AppColor.bondiBlue, size: 48),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      entry.$2.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    entry.$3.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (_step > 0)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => setState(() => _step--),
                          child: Text(
                            GeneratorTranslationConstants.guidePrevious.tr,
                          ),
                        ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: last
                            ? _finish
                            : () => setState(() => _step++),
                        child: Text(
                          (last
                                  ? GeneratorTranslationConstants.guideFinish
                                  : GeneratorTranslationConstants.guideNext)
                              .tr,
                        ),
                      ),
                    ],
                  ),
                  if (!last)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _finish,
                      child: Text(GeneratorTranslationConstants.guideSkip.tr),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

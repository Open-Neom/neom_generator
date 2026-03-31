import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neom_commons/ui/theme/app_color.dart';

/// A step-by-step coach-marks tutorial overlay for the Cámara Neom web
/// interface. Shows on first visit only (persisted via Hive).
///
/// Usage: wrap or stack on top of NeomGeneratorWebPage:
/// ```dart
/// CamaraNeomTutorial(onComplete: () => setState(() => _showTutorial = false))
/// ```
class CamaraNeomTutorial extends StatefulWidget {
  /// Called when the user finishes or skips the tutorial.
  final VoidCallback onComplete;

  const CamaraNeomTutorial({super.key, required this.onComplete});

  /// Hive key used to persist whether the tutorial has been seen.
  static const String _hiveBox = 'settings';
  static const String _hiveKey = 'camara_neom_tutorial_seen';

  /// Returns `true` if the tutorial should be displayed (first visit).
  static Future<bool> shouldShow() async {
    final box = await Hive.openBox(_hiveBox);
    return box.get(_hiveKey, defaultValue: false) != true;
  }

  /// Marks the tutorial as seen so it won't appear again.
  static Future<void> markSeen() async {
    final box = await Hive.openBox(_hiveBox);
    await box.put(_hiveKey, true);
  }

  @override
  State<CamaraNeomTutorial> createState() => _CamaraNeomTutorialState();
}

class _CamaraNeomTutorialState extends State<CamaraNeomTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;

  late final AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.music_note,
      title: 'Frecuencia Raíz',
      description:
          'Tu frecuencia base. Detecta tu voz o ajústala manualmente. '
          'Es el tono fundamental de tu sesión.',
      area: 'Centro superior — display de frecuencia',
      color: AppColor.bondiBlue,
    ),
    _TutorialStep(
      icon: Icons.hearing,
      title: 'Beat Binaural',
      description:
          'La diferencia entre oído izquierdo y derecho. Este beat induce '
          'estados cerebrales específicos: 4 Hz = calma, 10 Hz = alerta, '
          '40 Hz = enfoque.',
      area: 'Centro — display de beat binaural',
      color: Colors.purpleAccent,
    ),
    _TutorialStep(
      icon: Icons.show_chart,
      title: 'Osciloscopio',
      description:
          'Visualización en tiempo real de la onda que estás generando. '
          'Muestra la forma y amplitud del sonido.',
      area: 'Centro — panel de osciloscopio',
      color: Colors.tealAccent,
    ),
    _TutorialStep(
      icon: Icons.tune,
      title: 'Controles de Frecuencia',
      description:
          'Ajusta frecuencia, volumen y beat binaural con los sliders. '
          'Usa + y − para cambios precisos.',
      area: 'Centro inferior — sliders de onda',
      color: Colors.amber,
    ),
    _TutorialStep(
      icon: Icons.mic,
      title: 'Detección de Voz',
      description:
          'Detecta tu frecuencia vocal única. Mantén un sonido constante '
          'con tu voz durante 5 segundos.',
      area: 'Centro inferior — botón de micrófono',
      color: Colors.redAccent,
    ),
    _TutorialStep(
      icon: Icons.surround_sound,
      title: 'Modulación / Espacialidad',
      description:
          'Efectos avanzados: Isocrónico (pulsos de amplitud), Modulación '
          'FM/Phase, y Espacialidad (movimiento del sonido entre oídos).',
      area: 'Panel izquierdo',
      color: Colors.cyanAccent,
    ),
    _TutorialStep(
      icon: Icons.self_improvement,
      title: 'Respiración / Estados',
      description:
          'Sincroniza la respiración con el audio. Los Estados '
          'Neuro-Armónicos ajustan automáticamente todos los parámetros.',
      area: 'Panel derecho',
      color: Colors.greenAccent,
    ),
    _TutorialStep(
      icon: Icons.auto_awesome,
      title: 'Experiencias',
      description:
          'Experiencias visuales inmersivas: NeuroFlocking, Neuro Respiración, '
          'Fractales, Neomatics y NeuroMandala. Cada una reacciona a tu '
          'frecuencia.',
      area: 'Panel izquierdo inferior',
      color: Colors.orangeAccent,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _fadeCtrl.reverse().then((_) {
        setState(() => _currentStep++);
        _fadeCtrl.forward();
      });
    } else {
      _finish();
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      _fadeCtrl.reverse().then((_) {
        setState(() => _currentStep--);
        _fadeCtrl.forward();
      });
    }
  }

  void _finish() {
    CamaraNeomTutorial.markSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withAlpha(222), // ~87%
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Step counter ──
                      Text(
                        '${_currentStep + 1} / ${_steps.length}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Step progress bar ──
                      _buildProgressBar(step.color),

                      const SizedBox(height: 32),

                      // ── Icon with glow ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: step.color.withAlpha(25),
                          border: Border.all(
                            color: step.color.withAlpha(100),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: step.color.withAlpha(60),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(step.icon, color: step.color, size: 36),
                      ),

                      const SizedBox(height: 24),

                      // ── Title ──
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Area indicator ──
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place, color: step.color.withAlpha(180), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            step.area,
                            style: TextStyle(
                              color: step.color.withAlpha(180),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Description ──
                      Text(
                        step.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Navigation buttons ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Back button
                          if (_currentStep > 0)
                            TextButton(
                              onPressed: _previous,
                              child: const Text(
                                'Anterior',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 16),

                          // Next / Finish button
                          ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isLast ? 'Comenzar' : 'Siguiente',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Skip link ──
                      if (!isLast)
                        GestureDetector(
                          onTap: _finish,
                          child: const Text(
                            'Omitir tutorial',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    return Row(
      children: List.generate(_steps.length, (i) {
        final isActive = i <= _currentStep;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive ? color : Colors.white12,
            ),
          ),
        );
      }),
    );
  }
}

/// Internal data class for a single tutorial step.
class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final String area;
  final Color color;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.area,
    required this.color,
  });
}

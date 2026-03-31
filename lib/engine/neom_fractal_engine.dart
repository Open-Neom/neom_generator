import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

/// Fractal type mapped to each [NeomNeuroState].
enum NeomFractalType {
  mandelbrot,     // neutral — classic, balanced
  mandelbrotDeep, // calm — deep zoom, hypnotic spirals
  julia,          // focus — sharp, symmetric, structured
  newton,         // sleep — soft basins, gradient flows
  burningShip,    // creativity — chaotic, asymmetric
  multibrot,      // integration — complex symmetry, evolving
}

/// Color palette preset for each fractal/neuro-state.
class FractalPalette {
  final Color color1;
  final Color color2;
  final Color color3;

  const FractalPalette({
    required this.color1,
    required this.color2,
    required this.color3,
  });
}

/// Configuration for a fractal visualization tied to a [NeomNeuroState].
class FractalConfig {
  final NeomFractalType type;
  final String shaderAsset;
  final double defaultCenterX;
  final double defaultCenterY;
  final double defaultZoom;
  final double maxIterations;
  final double zoomDriftSpeed;
  final double colorCycleSpeed;
  final FractalPalette palette;

  // Julia-specific
  final double juliaCx;
  final double juliaCy;

  // Multibrot-specific
  final double power;

  const FractalConfig({
    required this.type,
    required this.shaderAsset,
    this.defaultCenterX = -0.5,
    this.defaultCenterY = 0.0,
    this.defaultZoom = 0.5,
    this.maxIterations = 100,
    this.zoomDriftSpeed = 0.0,
    this.colorCycleSpeed = 1.0,
    required this.palette,
    this.juliaCx = -0.7,
    this.juliaCy = 0.27015,
    this.power = 3.0,
  });

  /// Returns iteration count scaled for the current platform.
  /// Mobile/web GPUs need fewer iterations to maintain 60fps.
  double get platformIterations {
    if (kIsWeb) return (maxIterations * 0.3).clamp(24, 60);
    return maxIterations;
  }
}

/// Central fractal visualization engine for mobile and web.
///
/// Uses Flutter fragment shaders (GPU-accelerated via Impeller/CanvasKit).
/// Falls back to CPU-rendered [CustomPainter] on platforms where
/// fragment shaders are not available (e.g. web HTML renderer).
class NeomFractalEngine extends ChangeNotifier {
  FractalConfig _config = _configs[NeomNeuroState.neutral]!;
  NeomNeuroState _currentState = NeomNeuroState.neutral;

  // Animation state
  double _time = 0.0;
  double _centerX = -0.5;
  double _centerY = 0.0;
  double _zoom = 0.5;

  // Audio-reactive inputs
  double _breath = 0.0;
  double _neuro = 0.0;

  // Interactive state
  double _userOffsetX = 0.0;
  double _userOffsetY = 0.0;
  double _userZoomFactor = 1.0;

  // Shader programs (loaded once, cached per unique asset)
  final Map<String, ui.FragmentProgram> _programCache = {};
  final Map<NeomFractalType, ui.FragmentShader?> _shaders = {};
  bool _shadersLoaded = false;
  bool _shadersFailed = false;

  // Getters
  FractalConfig get config => _config;
  NeomNeuroState get currentState => _currentState;
  double get time => _time;
  double get centerX => _centerX + _userOffsetX;
  double get centerY => _centerY + _userOffsetY;
  double get zoom => _zoom * _userZoomFactor;
  double get breath => _breath;
  double get neuro => _neuro;
  bool get shadersLoaded => _shadersLoaded;
  bool get useFallback => _shadersFailed || !_shadersLoaded;

  ui.FragmentShader? get currentShader => _shaders[_config.type];

  /// Load fragment shader programs from assets.
  /// Each unique .frag file is loaded once and shared across fractal types.
  Future<void> loadShaders() async {
    if (_shadersLoaded) return;

    final shaderAssets = <NeomFractalType, String>{
      NeomFractalType.mandelbrot: 'packages/neom_generator/shaders/mandelbrot.frag',
      NeomFractalType.mandelbrotDeep: 'packages/neom_generator/shaders/mandelbrot.frag',
      NeomFractalType.julia: 'packages/neom_generator/shaders/julia.frag',
      NeomFractalType.newton: 'packages/neom_generator/shaders/newton.frag',
      NeomFractalType.burningShip: 'packages/neom_generator/shaders/burning_ship.frag',
      NeomFractalType.multibrot: 'packages/neom_generator/shaders/multibrot.frag',
    };

    int loaded = 0;
    for (final entry in shaderAssets.entries) {
      try {
        // Reuse program if same asset was already loaded
        ui.FragmentProgram? program = _programCache[entry.value];
        if (program == null) {
          program = await ui.FragmentProgram.fromAsset(entry.value);
          _programCache[entry.value] = program;
        }
        _shaders[entry.key] = program.fragmentShader();
        loaded++;
      } catch (e) {
        debugPrint('NeomFractalEngine: Failed to load ${entry.value}: $e');
      }
    }

    _shadersLoaded = loaded > 0;
    _shadersFailed = loaded == 0;
    notifyListeners();
  }

  /// Set fractal based on neuro-state.
  void setNeuroState(NeomNeuroState state) {
    _currentState = state;
    _config = _configs[state] ?? _configs[NeomNeuroState.neutral]!;

    _centerX = _config.defaultCenterX;
    _centerY = _config.defaultCenterY;
    _zoom = _config.defaultZoom;
    _userOffsetX = 0.0;
    _userOffsetY = 0.0;
    _userZoomFactor = 1.0;

    notifyListeners();
  }

  double _timeSinceLastNotify = 0.0;

  /// Update animation frame.
  void tick(double dt) {
    _time += dt;

    // Slow zoom drift (meditative auto-exploration)
    if (_config.zoomDriftSpeed > 0) {
      _zoom *= 1.0 + _config.zoomDriftSpeed * dt * 0.01;
      // Reset zoom to prevent float precision issues on mobile
      if (_zoom > 1e5) _zoom = _config.defaultZoom;
    }

    // Throttle repaints: GPU shaders run at 60fps fine,
    // but CPU fallback (web without shader support) needs throttling
    // to ~8fps to stay responsive — each frame is a full Mandelbrot compute.
    if (useFallback) {
      _timeSinceLastNotify += dt;
      if (_timeSinceLastNotify < 0.125) return; // ~8fps
      _timeSinceLastNotify = 0.0;
    }

    notifyListeners();
  }

  /// Update audio-reactive parameters from the painter engine.
  void updateFromAudio({
    required double breath,
    required double neuro,
  }) {
    _breath = breath;
    _neuro = neuro;
  }

  // ═══════════════════════════════════════════
  // Interactive controls (touch gestures)
  // ═══════════════════════════════════════════

  void pan(double dx, double dy) {
    _userOffsetX -= dx / (zoom * 500);
    _userOffsetY -= dy / (zoom * 500);
    notifyListeners();
  }

  void zoomBy(double factor) {
    _userZoomFactor *= factor;
    _userZoomFactor = _userZoomFactor.clamp(0.001, 1e6);
    notifyListeners();
  }

  void resetView() {
    _userOffsetX = 0.0;
    _userOffsetY = 0.0;
    _userZoomFactor = 1.0;
    _centerX = _config.defaultCenterX;
    _centerY = _config.defaultCenterY;
    _zoom = _config.defaultZoom;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // Shader uniform configuration
  // ═══════════════════════════════════════════

  /// Configure the current shader with all uniforms for this frame.
  void configureShader(Size size) {
    final shader = currentShader;
    if (shader == null) return;

    int idx = 0;
    // uSize (vec2)
    shader.setFloat(idx++, size.width);
    shader.setFloat(idx++, size.height);
    // uCenter (vec2)
    shader.setFloat(idx++, centerX);
    shader.setFloat(idx++, centerY);
    // uZoom (float)
    shader.setFloat(idx++, zoom);
    // uTime (float)
    shader.setFloat(idx++, _time);
    // uIterMax (float) — platform-scaled
    shader.setFloat(idx++, _config.platformIterations);
    // uColor1 (vec3) — normalized 0..1
    shader.setFloat(idx++, _config.palette.color1.red / 255.0);
    shader.setFloat(idx++, _config.palette.color1.green / 255.0);
    shader.setFloat(idx++, _config.palette.color1.blue / 255.0);
    // uColor2 (vec3)
    shader.setFloat(idx++, _config.palette.color2.red / 255.0);
    shader.setFloat(idx++, _config.palette.color2.green / 255.0);
    shader.setFloat(idx++, _config.palette.color2.blue / 255.0);
    // uColor3 (vec3)
    shader.setFloat(idx++, _config.palette.color3.red / 255.0);
    shader.setFloat(idx++, _config.palette.color3.green / 255.0);
    shader.setFloat(idx++, _config.palette.color3.blue / 255.0);
    // uBreath (float)
    shader.setFloat(idx++, _breath);
    // uNeuro (float)
    shader.setFloat(idx++, _neuro);

    // Type-specific uniforms (must match shader layout)
    if (_config.type == NeomFractalType.julia) {
      // uJuliaC (vec2)
      shader.setFloat(idx++, _config.juliaCx);
      shader.setFloat(idx++, _config.juliaCy);
    } else if (_config.type == NeomFractalType.multibrot) {
      // uPower (float)
      shader.setFloat(idx++, _config.power);
    }
  }

  // ═══════════════════════════════════════════
  // CPU fallback — Mandelbrot for web HTML renderer
  // ═══════════════════════════════════════════

  /// CPU-computed Mandelbrot iteration count for a single point.
  /// Used by [NeomFractalFallbackPainter] when shaders aren't available.
  double computeMandelbrotAt(double cx, double cy) {
    double zx = 0, zy = 0;
    final maxIter = _config.platformIterations;
    double i = 0;
    while (i < maxIter && zx * zx + zy * zy <= 4.0) {
      final tmp = zx * zx - zy * zy + cx;
      zy = 2.0 * zx * zy + cy;
      zx = tmp;
      i++;
    }
    if (i >= maxIter) return -1;
    // Smooth iteration count
    return i - log(log(sqrt(zx * zx + zy * zy))) / log(2);
  }

  /// Palette lookup for CPU fallback.
  Color paletteAt(double t) {
    t = t % 1.0;
    if (t < 0) t += 1.0;
    final c1 = _config.palette.color1;
    final c2 = _config.palette.color2;
    final c3 = _config.palette.color3;

    if (t < 0.33) {
      return Color.lerp(c1, c2, t * 3.0)!;
    } else if (t < 0.66) {
      return Color.lerp(c2, c3, (t - 0.33) * 3.0)!;
    } else {
      return Color.lerp(c3, c1, (t - 0.66) * 3.0)!;
    }
  }

  // ═══════════════════════════════════════════
  // Neuro-state presets
  // ═══════════════════════════════════════════

  static final Map<NeomNeuroState, FractalConfig> _configs = {
    NeomNeuroState.neutral: const FractalConfig(
      type: NeomFractalType.mandelbrot,
      shaderAsset: 'mandelbrot.frag',
      defaultCenterX: -0.5,
      defaultCenterY: 0.0,
      defaultZoom: 0.4,
      maxIterations: 100,
      zoomDriftSpeed: 0.0,
      colorCycleSpeed: 1.0,
      palette: FractalPalette(
        color1: Color(0xFF00CED1),
        color2: Color(0xFF4169E1),
        color3: Color(0xFF191970),
      ),
    ),
    NeomNeuroState.calm: const FractalConfig(
      type: NeomFractalType.mandelbrotDeep,
      shaderAsset: 'mandelbrot.frag',
      defaultCenterX: -0.745,
      defaultCenterY: 0.186,
      defaultZoom: 5.0,
      maxIterations: 150,
      zoomDriftSpeed: 0.5,
      colorCycleSpeed: 0.5,
      palette: FractalPalette(
        color1: Color(0xFF4B0082),
        color2: Color(0xFF6A5ACD),
        color3: Color(0xFF1A0033),
      ),
    ),
    NeomNeuroState.focus: const FractalConfig(
      type: NeomFractalType.julia,
      shaderAsset: 'julia.frag',
      defaultCenterX: 0.0,
      defaultCenterY: 0.0,
      defaultZoom: 0.5,
      maxIterations: 120,
      zoomDriftSpeed: 0.0,
      colorCycleSpeed: 0.8,
      palette: FractalPalette(
        color1: Color(0xFFFFA500),
        color2: Color(0xFFFF6347),
        color3: Color(0xFF2F1B00),
      ),
      juliaCx: -0.7,
      juliaCy: 0.27015,
    ),
    NeomNeuroState.sleep: const FractalConfig(
      type: NeomFractalType.newton,
      shaderAsset: 'newton.frag',
      defaultCenterX: 0.0,
      defaultCenterY: 0.0,
      defaultZoom: 0.35,
      maxIterations: 50,
      zoomDriftSpeed: 0.2,
      colorCycleSpeed: 0.3,
      palette: FractalPalette(
        color1: Color(0xFF191970),
        color2: Color(0xFF4B0082),
        color3: Color(0xFF2E0854),
      ),
    ),
    NeomNeuroState.creativity: const FractalConfig(
      type: NeomFractalType.burningShip,
      shaderAsset: 'burning_ship.frag',
      defaultCenterX: -1.75,
      defaultCenterY: -0.03,
      defaultZoom: 0.15,
      maxIterations: 100,
      zoomDriftSpeed: 0.3,
      colorCycleSpeed: 1.5,
      palette: FractalPalette(
        color1: Color(0xFFFF69B4),
        color2: Color(0xFF00CED1),
        color3: Color(0xFF9400D3),
      ),
    ),
    NeomNeuroState.integration: const FractalConfig(
      type: NeomFractalType.multibrot,
      shaderAsset: 'multibrot.frag',
      defaultCenterX: 0.0,
      defaultCenterY: 0.0,
      defaultZoom: 0.4,
      maxIterations: 120,
      zoomDriftSpeed: 0.4,
      colorCycleSpeed: 1.0,
      palette: FractalPalette(
        color1: Color(0xFF00CED1),
        color2: Color(0xFFFFA500),
        color3: Color(0xFF7B68EE),
      ),
      power: 4.0,
    ),
  };
}

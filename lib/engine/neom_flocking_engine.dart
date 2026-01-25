import 'dart:math';
import 'package:flutter/material.dart';
import 'package:neom_core/app_config.dart';

/// Representa una partícula/pájaro en el sistema de flocking con profundidad 3D
class Boid {
  double x;
  double y;
  double z; // Profundidad (0 = cerca, 1 = lejos)
  double vx;
  double vy;
  double vz;
  double size;
  Color color;
  double energy;

  Boid({
    required this.x,
    required this.y,
    this.z = 0.5,
    required this.vx,
    required this.vy,
    this.vz = 0,
    this.size = 3.0,
    this.color = Colors.white,
    this.energy = 1.0,
  });

  Offset get position => Offset(x, y);
  Offset get velocity => Offset(vx, vy);

  /// Tamaño visual considerando profundidad (más lejos = más pequeño)
  double get visualSize => size * (0.4 + (1 - z) * 0.6);

  /// Opacidad considerando profundidad
  double get depthOpacity => 0.3 + (1 - z) * 0.7;
}

/// Motor de simulación Boids OPTIMIZADO con profundidad 3D y spatial hashing
class NeomFlockingEngine extends ChangeNotifier {
  final Random _random = Random();

  List<Boid> boids = [];

  // Spatial grid para optimización O(n) en lugar de O(n²)
  Map<int, List<Boid>> _spatialGrid = {};
  int _gridCellSize = 50;

  // Parámetros del algoritmo Boids
  double separationWeight = 1.5;
  double alignmentWeight = 1.0;
  double cohesionWeight = 1.0;
  double maxSpeed = 4.0;
  double maxForce = 0.1;
  double perceptionRadius = 50.0;

  // Parámetros de audio reactivo
  double audioAmplitude = 0.0;
  double audioFrequency = 0.5;
  double audioBeat = 0.0;
  double audioPhase = 0.0;

  // Attractor central (opcional)
  Offset? attractor;
  double attractorStrength = 0.02;

  // Dimensiones del canvas
  double width = 400;
  double height = 800;

  // Paleta de colores
  List<Color> colorPalette = [
    const Color(0xFF00CED1),
    const Color(0xFF6A5ACD),
    const Color(0xFF4B0082),
    const Color(0xFFFF6B6B),
    const Color(0xFF98D8C8),
  ];

  // Modo visual
  bool showConnections = true;
  bool showTrails = false;
  double connectionMaxDistance = 45.0;

  // Cache para conexiones (evita recalcular cada frame)
  final List<(Boid, Boid, double)> _cachedConnections = [];
  int _connectionUpdateCounter = 0;

  /// Inicializa el sistema con N boids
  void initialize({
    required int count,
    required double canvasWidth,
    required double canvasHeight,
  }) {

    AppConfig.logger.d('🎯 ENGINE INIT: canvasWidth=$canvasWidth, canvasHeight=$canvasHeight');

    width = canvasWidth;
    height = canvasHeight;
    _gridCellSize = (perceptionRadius * 1.1).toInt().clamp(35, 70);
    boids.clear();
    _spatialGrid = {};

    for (int i = 0; i < count; i++) {
      boids.add(Boid(
        x: _random.nextDouble() * width,
        y: _random.nextDouble() * height,
        z: _random.nextDouble(), // Profundidad aleatoria
        vx: (_random.nextDouble() - 0.5) * maxSpeed,
        vy: (_random.nextDouble() - 0.5) * maxSpeed,
        vz: (_random.nextDouble() - 0.5) * 0.015,
        size: 2.5 + _random.nextDouble() * 2.0,
        color: colorPalette[_random.nextInt(colorPalette.length)],
        energy: 0.5 + _random.nextDouble() * 0.5,
      ));
    }

    AppConfig.logger.d('🎯 ENGINE AFTER: width=$width, height=$height');
  }

  /// Actualiza el estado del audio para reactividad
  void updateAudio({
    required double amplitude,
    required double frequency,
    required double beat,
    required double phase,
  }) {
    audioAmplitude = amplitude.clamp(0.0, 1.0);
    audioFrequency = frequency.clamp(0.0, 1.0);
    audioBeat = beat.clamp(0.0, 40.0);
    audioPhase = phase;
  }

  /// Construye el spatial grid para búsqueda eficiente
  void _buildSpatialGrid() {
    _spatialGrid.clear();
    for (var boid in boids) {
      final key = _getGridKey(boid.x, boid.y);
      _spatialGrid.putIfAbsent(key, () => []).add(boid);
    }
  }

  int _getGridKey(double x, double y) {
    final gx = (x / _gridCellSize).floor();
    final gy = (y / _gridCellSize).floor();
    return gx + gy * 10000;
  }

  /// Obtiene vecinos cercanos usando spatial grid - MUCHO más eficiente
  List<Boid> _getNeighbors(Boid boid, double radius) {
    final neighbors = <Boid>[];
    final gx = (boid.x / _gridCellSize).floor();
    final gy = (boid.y / _gridCellSize).floor();
    final radiusSq = radius * radius;

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final key = (gx + dx) + (gy + dy) * 10000;
        final cell = _spatialGrid[key];
        if (cell != null) {
          for (var other in cell) {
            if (other != boid) {
              final ddx = boid.x - other.x;
              final ddy = boid.y - other.y;
              if (ddx * ddx + ddy * ddy < radiusSq) {
                neighbors.add(other);
              }
            }
          }
        }
      }
    }
    return neighbors;
  }

  /// Tick principal de la simulación - OPTIMIZADO
  void update() {
    if (boids.isEmpty) return;

    // Reconstruir spatial grid
    _buildSpatialGrid();

    // Parámetros dinámicos basados en audio
    final dynamicPerception = perceptionRadius + (audioAmplitude * 15);
    final dynamicMaxSpeed = maxSpeed + (audioAmplitude * 1.2);
    final dynamicCohesion = cohesionWeight + (sin(audioPhase) * 0.15);

    for (var boid in boids) {
      final neighbors = _getNeighbors(boid, dynamicPerception);

      // Acumuladores para las 3 reglas
      double sepX = 0, sepY = 0;
      double aliX = 0, aliY = 0;
      double cohX = 0, cohY = 0;
      int sepCount = 0, aliCount = 0;

      for (var other in neighbors) {
        final dx = boid.x - other.x;
        final dy = boid.y - other.y;
        final dSq = dx * dx + dy * dy;
        final d = sqrt(dSq);

        // Separación (muy cercanos)
        final sepRadius = dynamicPerception * 0.35;
        if (d < sepRadius && d > 0.001) {
          final invD = 1 / (dSq + 1);
          sepX += dx * invD;
          sepY += dy * invD;
          sepCount++;
        }

        // Alineación y cohesión
        aliX += other.vx;
        aliY += other.vy;
        cohX += other.x;
        cohY += other.y;
        aliCount++;
      }

      double ax = 0, ay = 0;

      // Aplicar separación
      if (sepCount > 0) {
        sepX /= sepCount;
        sepY /= sepCount;
        final sepMag = sqrt(sepX * sepX + sepY * sepY);
        if (sepMag > 0.001) {
          sepX = sepX / sepMag * maxSpeed - boid.vx;
          sepY = sepY / sepMag * maxSpeed - boid.vy;
          final steerMag = sqrt(sepX * sepX + sepY * sepY);
          if (steerMag > maxForce) {
            sepX = sepX / steerMag * maxForce;
            sepY = sepY / steerMag * maxForce;
          }
        }
        ax += sepX * separationWeight;
        ay += sepY * separationWeight;
      }

      // Aplicar alineación y cohesión
      if (aliCount > 0) {
        // Alineación
        aliX /= aliCount;
        aliY /= aliCount;
        final aliMag = sqrt(aliX * aliX + aliY * aliY);
        if (aliMag > 0.001) {
          aliX = aliX / aliMag * maxSpeed - boid.vx;
          aliY = aliY / aliMag * maxSpeed - boid.vy;
          final steerMag = sqrt(aliX * aliX + aliY * aliY);
          if (steerMag > maxForce) {
            aliX = aliX / steerMag * maxForce;
            aliY = aliY / steerMag * maxForce;
          }
        }
        ax += aliX * (alignmentWeight + audioFrequency * 0.2);
        ay += aliY * (alignmentWeight + audioFrequency * 0.2);

        // Cohesión
        cohX = cohX / aliCount - boid.x;
        cohY = cohY / aliCount - boid.y;
        final cohMag = sqrt(cohX * cohX + cohY * cohY);
        if (cohMag > 0.001) {
          cohX = cohX / cohMag * maxSpeed - boid.vx;
          cohY = cohY / cohMag * maxSpeed - boid.vy;
          final steerMag = sqrt(cohX * cohX + cohY * cohY);
          if (steerMag > maxForce) {
            cohX = cohX / steerMag * maxForce;
            cohY = cohY / steerMag * maxForce;
          }
        }
        ax += cohX * dynamicCohesion;
        ay += cohY * dynamicCohesion;
      }

      // Attractor
      if (attractor != null) {
        final toAttrX = attractor!.dx - boid.x;
        final toAttrY = attractor!.dy - boid.y;
        ax += toAttrX * attractorStrength * (1 + audioAmplitude);
        ay += toAttrY * attractorStrength * (1 + audioAmplitude);
      }

      // Fuerza de pulso con el beat (simplificado)
      if (audioBeat > 0 && audioAmplitude > 0.15) {
        final beatPulse = sin(audioPhase * audioBeat * 0.5) * audioAmplitude * 0.2;
        final centerX = width / 2;
        final centerY = height / 2;
        final fromCenterX = boid.x - centerX;
        final fromCenterY = boid.y - centerY;
        final dist = sqrt(fromCenterX * fromCenterX + fromCenterY * fromCenterY) + 1;
        ax += (fromCenterX / dist) * beatPulse;
        ay += (fromCenterY / dist) * beatPulse;
      }

      // Actualizar velocidad
      boid.vx += ax;
      boid.vy += ay;

      // Limitar velocidad
      final speed = sqrt(boid.vx * boid.vx + boid.vy * boid.vy);
      if (speed > dynamicMaxSpeed) {
        boid.vx = boid.vx / speed * dynamicMaxSpeed;
        boid.vy = boid.vy / speed * dynamicMaxSpeed;
      }

      // Actualizar posición
      boid.x += boid.vx;
      boid.y += boid.vy;

      // Actualizar profundidad Z (movimiento lento de vaivén)
      boid.vz += (_random.nextDouble() - 0.5) * 0.001;
      boid.vz = boid.vz.clamp(-0.008, 0.008);
      boid.z += boid.vz;
      boid.z = boid.z.clamp(0.0, 1.0);

      // Wrap around edges
      if (boid.x < 0) boid.x += width;
      if (boid.x > width) boid.x -= width;
      if (boid.y < 0) boid.y += height;
      if (boid.y > height) boid.y -= height;

      // Actualizar energía y tamaño
      boid.energy = 0.5 + audioAmplitude * 0.5;
      boid.size = 2.5 + (speed / dynamicMaxSpeed) * 1.2 + audioAmplitude * 1.0;
    }

    // Actualizar conexiones cada 4 frames para ahorrar CPU
    _connectionUpdateCounter++;
    if (_connectionUpdateCounter >= 4) {
      _updateConnections();
      _connectionUpdateCounter = 0;
    }

    notifyListeners();
  }

  void _updateConnections() {
    if (!showConnections) {
      _cachedConnections.clear();
      return;
    }

    _cachedConnections.clear();
    final maxDist = connectionMaxDistance;
    final maxDistSq = maxDist * maxDist;

    // Usar spatial grid para conexiones - MUCHO más eficiente
    final processed = <int>{};

    for (int i = 0; i < boids.length; i++) {
      final boid = boids[i];
      final neighbors = _getNeighbors(boid, maxDist);

      for (var other in neighbors) {
        final j = boids.indexOf(other);
        if (j > i) {
          final pairKey = i * 10000 + j;
          if (!processed.contains(pairKey)) {
            processed.add(pairKey);
            final dx = boid.x - other.x;
            final dy = boid.y - other.y;
            final distSq = dx * dx + dy * dy;
            if (distSq < maxDistSq) {
              final dist = sqrt(distSq);
              final opacity = 1.0 - (dist / maxDist);
              _cachedConnections.add((boid, other, opacity));
            }
          }
        }
      }
    }
  }

  /// Obtiene conexiones entre boids cercanos (cached)
  List<(Boid, Boid, double)> getConnections() => _cachedConnections;

  /// Establece el attractor en una posición
  void setAttractor(Offset position) {
    attractor = position;
  }

  /// Elimina el attractor
  void clearAttractor() {
    attractor = null;
  }

  /// Cambia la paleta de colores según el estado neuronal
  void setColorPalette(String mode) {
    switch (mode) {
      case 'calm':
        colorPalette = [
          const Color(0xFF4B0082),
          const Color(0xFF6A5ACD),
          const Color(0xFF9370DB),
          const Color(0xFF8B668B),
        ];
        break;
      case 'focus':
        colorPalette = [
          const Color(0xFFFFA500),
          const Color(0xFFFF8C00),
          const Color(0xFFFFD700),
          const Color(0xFFFF6347),
        ];
        break;
      case 'sleep':
        colorPalette = [
          const Color(0xFF191970),
          const Color(0xFF000080),
          const Color(0xFF0000CD),
          const Color(0xFF4169E1),
        ];
        break;
      case 'creativity':
        colorPalette = [
          const Color(0xFFFF1493),
          const Color(0xFF00CED1),
          const Color(0xFF7B68EE),
          const Color(0xFF00FA9A),
        ];
        break;
      default:
        colorPalette = [
          const Color(0xFF00CED1),
          const Color(0xFF6A5ACD),
          const Color(0xFF4B0082),
          const Color(0xFFFF6B6B),
          const Color(0xFF98D8C8),
        ];
    }

    for (var boid in boids) {
      boid.color = colorPalette[_random.nextInt(colorPalette.length)];
    }
  }
}

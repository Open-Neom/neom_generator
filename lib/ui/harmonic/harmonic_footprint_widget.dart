import 'package:flutter/material.dart';

import '../../domain/models/harmonic/harmonic_footprint.dart';
import '../../domain/models/harmonic/vocal_range.dart';
import 'harmonic_footprint_painter.dart';

/// Displays the user's Huella Armonica (Harmonic Footprint) as a unique
/// visual shape with key stats.
class HarmonicFootprintWidget extends StatelessWidget {
  /// The footprint data to visualize.
  final HarmonicFootprint footprint;

  /// Size of the visualization (width and height).
  final double size;

  const HarmonicFootprintWidget({
    super.key,
    required this.footprint,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    final resonance = footprint.resonanceHz;
    final vocalRange =
        resonance > 0 ? VocalRange.classify(resonance) : null;
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size + 60, // Extra space for labels
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Text(
              'Huella Armonica',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // The visualization
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                size: Size(size, size),
                painter: HarmonicFootprintPainter(footprint: footprint),
              ),
            ),
          ),

          // Bottom: resonance + vocal range
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (resonance > 0)
                  Text(
                    '${resonance.toStringAsFixed(0)} Hz'
                    '${vocalRange != null ? ' - ${vocalRange.displayName}' : ''}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                if (footprint.totalCaptures > 0)
                  Text(
                    '${footprint.totalCaptures} capturas'
                    ' | ${footprint.vocalRangeOctaves.toStringAsFixed(1)} oct'
                    ' | centroide ${footprint.spectralCentroidAvg.toStringAsFixed(0)} Hz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

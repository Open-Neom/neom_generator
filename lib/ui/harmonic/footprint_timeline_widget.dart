import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/harmonic/footprint_snapshot.dart';

/// Visualizes the evolution of a user's Huella Armónica over time.
///
/// Shows a line chart of the **coherence score** (0–1) per snapshot,
/// proving that continued Cyberneom practice leads to a more symmetric,
/// balanced harmonic signature. Below the chart, mini footprint shapes
/// show visual progression.
class FootprintTimelineWidget extends StatelessWidget {
  final List<FootprintSnapshot> snapshots;
  final double height;

  const FootprintTimelineWidget({
    super.key,
    required this.snapshots,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Captura tu voz regularmente para ver tu evolución',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evolución Armónica',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${snapshots.length} registros · coherencia ${_trend()}',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 0.25,
                    getTitlesWidget: (v, _) => Text(
                      '${(v * 100).toInt()}%',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: _xInterval(),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= snapshots.length) return const SizedBox.shrink();
                      final d = snapshots[idx].takenAt;
                      return Text(
                        '${d.day}/${d.month}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    snapshots.length,
                    (i) => FlSpot(i.toDouble(), snapshots[i].coherenceScore),
                  ),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: const Color(0xFF7C4DFF),
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF7C4DFF),
                      strokeColor: Colors.white24,
                      strokeWidth: 1,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                        const Color(0xFF7C4DFF).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _xInterval() {
    if (snapshots.length <= 7) return 1;
    return (snapshots.length / 6).ceilToDouble();
  }

  String _trend() {
    if (snapshots.length < 2) return '';
    final first = snapshots.first.coherenceScore;
    final last = snapshots.last.coherenceScore;
    final delta = last - first;
    if (delta > 0.05) return '↑ mejorando';
    if (delta < -0.05) return '↓ variando';
    return '→ estable';
  }
}

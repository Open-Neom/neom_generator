import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

/// Report generated at end of an INCIENSO meditation session.
///
/// Contains metrics from the session for Firebase analytics:
/// - Duration, frequency, beat, coherence
/// - Attention analysis from mic monitoring
/// - Breathing cycle count
/// - INCIENSO score (cycles × coherence)
class InciensoSessionReport {
  final String? userId;
  final String? inciensoId;
  final DateTime startedAt;
  final DateTime endedAt;
  final double rootFrequencyHz;
  final double avgBinauralBeatHz;
  final double avgCoherence;
  final int breathCycles;
  final int totalIncienso; // score = breathCycles with coherence > 70%
  final double focusPercentage; // from MeditationAttentionAnalyzer
  final int distractionCount;
  final int interruptionCount;
  final NeomNeuroState dominantState;
  final String? experienceUsed; // flocking, fractals, neomatics, etc.
  final Map<String, double> frequencyTimeline; // second -> Hz snapshot

  const InciensoSessionReport({
    this.userId,
    this.inciensoId,
    required this.startedAt,
    required this.endedAt,
    required this.rootFrequencyHz,
    this.avgBinauralBeatHz = 0,
    this.avgCoherence = 0,
    this.breathCycles = 0,
    this.totalIncienso = 0,
    this.focusPercentage = 100,
    this.distractionCount = 0,
    this.interruptionCount = 0,
    this.dominantState = NeomNeuroState.neutral,
    this.experienceUsed,
    this.frequencyTimeline = const {},
  });

  Duration get duration => endedAt.difference(startedAt);

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'inciensoId': inciensoId,
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': Timestamp.fromDate(endedAt),
    'durationSeconds': duration.inSeconds,
    'rootFrequencyHz': rootFrequencyHz,
    'avgBinauralBeatHz': avgBinauralBeatHz,
    'avgCoherence': avgCoherence,
    'breathCycles': breathCycles,
    'totalIncienso': totalIncienso,
    'focusPercentage': focusPercentage,
    'distractionCount': distractionCount,
    'interruptionCount': interruptionCount,
    'dominantState': dominantState.name,
    'experienceUsed': experienceUsed,
  };

  factory InciensoSessionReport.fromFirestore(Map<String, dynamic> data) {
    return InciensoSessionReport(
      userId: data['userId'] as String?,
      inciensoId: data['inciensoId'] as String?,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rootFrequencyHz: (data['rootFrequencyHz'] as num?)?.toDouble() ?? 0,
      avgBinauralBeatHz: (data['avgBinauralBeatHz'] as num?)?.toDouble() ?? 0,
      avgCoherence: (data['avgCoherence'] as num?)?.toDouble() ?? 0,
      breathCycles: data['breathCycles'] as int? ?? 0,
      totalIncienso: data['totalIncienso'] as int? ?? 0,
      focusPercentage: (data['focusPercentage'] as num?)?.toDouble() ?? 100,
      distractionCount: data['distractionCount'] as int? ?? 0,
      interruptionCount: data['interruptionCount'] as int? ?? 0,
      dominantState: NeomNeuroState.values.firstWhere(
        (s) => s.name == data['dominantState'],
        orElse: () => NeomNeuroState.neutral,
      ),
      experienceUsed: data['experienceUsed'] as String?,
    );
  }
}

/// Accumulates mic audio chunks during a meditation session.
///
/// Stores raw PCM data in memory for local processing at session end.
/// Does NOT upload audio to Firebase — only the report metrics.
class MeditationAudioCache {
  final List<Uint8List> _chunks = [];
  int _totalBytes = 0;
  static const _maxCacheBytes = 50 * 1024 * 1024; // 50MB max cache

  bool get isEmpty => _chunks.isEmpty;
  int get totalBytes => _totalBytes;
  int get chunkCount => _chunks.length;

  /// Add a PCM audio chunk from the mic.
  void addChunk(Uint8List chunk) {
    if (_totalBytes + chunk.length > _maxCacheBytes) return; // Cap
    _chunks.add(chunk);
    _totalBytes += chunk.length;
  }

  /// Get all cached audio as a single buffer (for local analysis).
  Uint8List? consolidate() {
    if (_chunks.isEmpty) return null;
    final buffer = Uint8List(_totalBytes);
    int offset = 0;
    for (final chunk in _chunks) {
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return buffer;
  }

  /// Clear cache after processing.
  void clear() {
    _chunks.clear();
    _totalBytes = 0;
  }
}

/// Saves INCIENSO session reports to Firestore.
class InciensoReportService {
  static const _collection = 'inciensoSessions';

  /// Save a session report to Firestore.
  static Future<String?> saveReport(InciensoSessionReport report) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .add(report.toFirestore());
      AppConfig.logger.d('INCIENSO report saved: ${doc.id} '
          '(${report.totalIncienso} INCIENSO, ${report.duration.inMinutes}min)');
      return doc.id;
    } catch (e) {
      AppConfig.logger.w('Failed to save INCIENSO report: $e');
      return null;
    }
  }

  /// Get session history for a user.
  static Future<List<InciensoSessionReport>> getHistory(String userId, {int limit = 30}) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => InciensoSessionReport.fromFirestore(d.data())).toList();
    } catch (e) {
      AppConfig.logger.w('Failed to fetch INCIENSO history: $e');
      return [];
    }
  }

  /// Get total INCIENSO score for a user.
  static Future<int> getTotalIncienso(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();
      int total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['totalIncienso'] as int?) ?? 0;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}

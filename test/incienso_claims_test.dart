import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/incienso_catalog.dart';
import 'package:neom_generator/domain/models/incienso.dart';

/// Guards the line between describing a practice and claiming a treatment.
///
/// Protocols are named after conditions people actually have, so the catalogue
/// is read by people looking for help. A description may say what the session
/// does; it may not imply an intervention the evidence does not support.
void main() {
  final catalogue = [...InciensoCatalog.free, ...InciensoCatalog.pro];

  /// Wording that asserts a clinical effect or derivation.
  const clinicalClaims = [
    'trata', 'treats', 'cura', 'cures',
    'basado en protocolos de neurofeedback', 'based on clinical neurofeedback',
    'diseñado para personas con', 'designed for people with',
    'promueven la liberación', 'promote natural endorphin',
    'complemento para el manejo', 'complement for chronic pain management',
  ];

  test('the catalogue is not empty', () {
    expect(catalogue, isNotEmpty);
  });

  test('no description asserts an unsupported clinical effect', () {
    final offenders = <String>[];

    for (final incienso in catalogue) {
      if (incienso.evidence == InciensoEvidence.clinical) continue;
      for (final locale in ['es', 'en']) {
        final text = incienso.getDescription(locale).toLowerCase();
        for (final claim in clinicalClaims) {
          // Whole words only: "trata" must not match inside "tratamiento",
          // which appears in the disclaimers rather than in a claim.
          final pattern = RegExp(r'\b' + RegExp.escape(claim) + r'\b');
          if (pattern.hasMatch(text)) {
            offenders.add('${incienso.id} [$locale]: "$claim"');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'A protocol below clinical evidence is making a clinical '
            'claim:\n${offenders.join('\n')}');
  });

  test('every protocol declares an evidence level', () {
    for (final incienso in catalogue) {
      expect(incienso.evidence, isA<InciensoEvidence>());
    }
  });

  test('clinical protocols carry the references that justify them', () {
    // The strongest label is the one that must be backed.
    final clinical =
        catalogue.where((i) => i.evidence == InciensoEvidence.clinical);

    expect(clinical, isNotEmpty);
    for (final incienso in clinical) {
      expect(incienso.references, isNotEmpty,
          reason: '${incienso.id} claims clinical support with no citation');
    }
  });

  test('binaural parameters stay in a range where the effect exists', () {
    for (final incienso in catalogue) {
      final beat =
          (incienso.rightFrequencyHz - incienso.leftFrequencyHz).abs();
      final carrier = [incienso.leftFrequencyHz, incienso.rightFrequencyHz]
          .reduce((a, b) => a > b ? a : b);

      // Above ~1000 Hz the binaural percept breaks down.
      expect(carrier, lessThanOrEqualTo(1000),
          reason: '${incienso.id} carrier too high for a binaural beat');
      // Entrainment is not claimed above the gamma band.
      expect(beat, lessThanOrEqualTo(50),
          reason: '${incienso.id} beat outside the entrainment range');
    }
  });
}

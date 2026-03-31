enum NeomVisualMode {
  scientific,
  meditative;

  String get translationKey => switch (this) {
    scientific => 'generatorVisualScientific',
    meditative => 'generatorVisualMeditative',
  };
}

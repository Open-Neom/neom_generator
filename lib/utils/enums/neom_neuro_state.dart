enum NeomNeuroState {
  neutral,
  calm,
  focus,
  sleep,
  creativity,
  integration;

  String get translationKey => switch (this) {
    neutral => 'generatorStateNeutral',
    calm => 'generatorStateCalm',
    focus => 'generatorStateFocus',
    sleep => 'generatorStateSleep',
    creativity => 'generatorStateCreativity',
    integration => 'generatorStateIntegration',
  };
}

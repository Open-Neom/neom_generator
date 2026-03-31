enum NeomSpatialMode {
  softPan,      // panoramización suave (default)
  hardPan,      // solo L o R
  crossfade,    // transición progresiva controlada
  orbit,         // movimiento automático
  centered;    // centrado (sin panoramización)

  /// Translation key for humanized label.
  String get translationKey => switch (this) {
    softPan => 'spatialSoftPan',
    hardPan => 'spatialHardPan',
    crossfade => 'spatialCrossfade',
    orbit => 'spatialOrbit',
    centered => 'spatialCentered',
  };
}

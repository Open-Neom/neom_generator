
abstract class NeomGeneratorService {

  // Future<void> settingChamber();
  void setFrequency(double frequency);
  void setVolume(double volume);
  void setParameterPosition({required double x, required double y, required double z});
  void setBinauralBeat({double beat = 0});

    ///DEPRECATED Future<void> stopPlay();

}

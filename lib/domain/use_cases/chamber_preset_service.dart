import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/utils/enums/chamber_preset_state.dart';

abstract class ChamberPresetService {

  Future<void> updateChamberPreset(NeomChamberPreset updatedPreset);
  Future<bool> removePresetFromChamber(NeomChamberPreset chamberPreset);
  void setChamberPresetState(ChamberPresetState newState);
  Future<void> getChamberPresetDetails(NeomChamberPreset chamberPreset);
  Future<bool> addPresetToChamber(NeomChamberPreset chamberPreset, String chamberId);
  void loadPresetsFromChamber();

}

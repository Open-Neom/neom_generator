import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/app_properties.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/data/implementations/neom_stopwatch.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_frequency.dart';
import 'package:neom_core/domain/model/neom/neom_parameter.dart';
import 'package:neom_core/domain/use_cases/frequency_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:neom_core/utils/enums/user_role.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import '../data/firestore/chamber_firestore.dart';
import '../domain/use_cases/neom_generator_service.dart';
import '../engine/neom_breath_engine.dart';
import '../engine/neom_frequency_painter_engine.dart';
import '../engine/neom_modulator_engine.dart';
import '../engine/neom_sine_engine.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/enums/neom_frequency_target.dart';
import '../utils/enums/neom_neuro_state.dart';
import '../utils/enums/neom_numeric_target.dart';
import '../utils/enums/neom_spatial_mode.dart';
import '../utils/enums/neom_visual_mode.dart';

class NeomGeneratorController extends SintController implements NeomGeneratorService {

  UserService? userServiceImpl;
  FrequencyService? frequencyServiceImpl;

  final NeomSineEngine _sineEngine = NeomSineEngine();
  late final NeomFrequencyPainterEngine painterEngine;

  final RxBool isIsochronicEnabled = false.obs;
  final RxDouble isochronicFreq = 4.0.obs;   // Hz
  final RxDouble isochronicDuty = 0.5.obs;

  final RxBool isModulationEnabled = false.obs;

  final Rx<NeomModulationType> modulationType =
      NeomModulationType.none.obs;

  final RxDouble modulationFreq = 0.5.obs;  // Hz
  final RxDouble modulationDepth = 0.3.obs;


  // // Constante de calibración (Hz base de la onda senoidal en SoLoud)
  // static const double kBaseSoLoudFreq = 440.00;

// --- VARIABLES REACTIVAS DE ESTADO ---  final RxDouble currentFreq = 432.0.obs;
  final RxDouble currentFreq = NeomGeneratorConstants.defaultFrequency.obs;
  final RxDouble currentVol = 0.5.obs;
  final RxDouble currentBeat = 0.0.obs; // La diferencia para el binaural

  // Posición Espacial (Solo visual/guardado por ahora en modo binaural)
  final RxDouble posX = 0.0.obs;
  final RxDouble posY = 0.0.obs;
  final RxDouble posZ = 0.0.obs;

  // Animación del Visualizador
  late Ticker _waveTicker;
  final RxDouble wavePhase = 0.0.obs; // Controla el movimiento de la onda

  AppProfile? profile;
  NeomChamberPreset chamberPreset = NeomChamberPreset();

  RxBool isPlaying = false.obs;
  RxBool isLoading = true.obs;
  final RxInt frequencyState = 0.obs;
  final RxMap<String, NeomChamber> chambers = <String, NeomChamber>{}.obs;
  final Rx<NeomChamber> chamber = NeomChamber().obs;
  final RxBool existsInChamber = false.obs;
  final RxBool isUpdate = false.obs;
  final RxBool isButtonDisabled = false.obs;

  RxString frequencyDescription = "".obs;
  bool noChambers = false;

  // Grabadora
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  double detectedFrequency = 0;
  StreamController<Uint8List>? _audioStreamController;
  final List<int> _accumulatedData = [];
  List<double> detectedPitches = [];

  bool _isDisposed = false;
  bool isAdmin = false;

  @override
  void onInit() async {
    super.onInit();
    List<dynamic> arguments  = Sint.arguments ?? [];
    painterEngine = NeomFrequencyPainterEngine();
    _sineEngine.painterEngine = painterEngine; // 🔗 conexión directa
    try {
      if(arguments.isNotEmpty) {
        if(arguments.elementAt(0) is NeomChamberPreset) {
          chamberPreset =  arguments.elementAt(0);
        } else if(arguments.elementAt(0) is NeomFrequency) {
          chamberPreset.mainFrequency = arguments.elementAt(0);
        }
      }

      if(Sint.isRegistered<UserService>()) userServiceImpl = Sint.find<UserService>();
      if(Sint.isRegistered<FrequencyService>()) frequencyServiceImpl = Sint.find<FrequencyService>();

      profile = userServiceImpl?.profile;
      isAdmin = (userServiceImpl?.user.userRole.value ?? UserRole.subscriber.value) <= UserRole.admin.value;
      chambers.value = profile?.chambers ?? {};

      chamberPreset.mainFrequency ??= NeomFrequency();
      chamberPreset.neomParameter ??= NeomParameter();
      // Inicializar valores locales desde el preset
      currentFreq.value = chamberPreset.mainFrequency?.frequency ?? NeomGeneratorConstants.defaultFrequency;
      currentVol.value = chamberPreset.neomParameter?.volume ?? 0.5;

      // Ahora verificamos directamente la propiedad binauralFrequency
      if (chamberPreset.binauralFrequency != null) {
        double bFreq = chamberPreset.binauralFrequency!.frequency;
        currentBeat.value = (bFreq - currentFreq.value).abs();
      } else {
        currentBeat.value = 0;
      }

      // Inicializar Player y Recorder
      await _sineEngine.init();
      await initializeRecorder();

      // Inicializar Ticker para animación
      _waveTicker = Ticker((elapsed) {
        if (!isPlaying.value) return;

        final dt = elapsed.inMilliseconds / 1000.0;

        wavePhase.value += dt * currentFreq.value * 0.02;
        wavePhase.value %= (2 * pi);

        painterEngine.updateFromAudio(
          phase: wavePhase.value,
          amplitude: currentVol.value,
          pan: posX.value,
          breath: breathDepth.value,
          modulation: modulationDepth.value,
          neuro: neuroState.value.index / NeomNeuroState.values.length,
          frequency: currentFreq.value,
        );

        painterEngine.tickBinaural(currentBeat.value.abs(), dt);

      });

    } catch(e) {
      AppConfig.logger.e(e.toString());
    }

  }

  @override
  void onReady() async {
    super.onReady();
    try {
      if(chambers.isEmpty) {
        noChambers = true;
      } else {
        existsInChamber.value = frequencyAlreadyInItemlist();
        if(chamber.value.id.isEmpty) {
          chamber.value = chambers.values.first;
        }
      }

      frequencyDescription.value = chamberPreset.description.isNotEmpty
          ? chamberPreset.description : chamberPreset.mainFrequency?.description ?? '';

    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    isLoading.value = false;
    update([AppPageIdConstants.generator]);
  }

  @override
  void onClose() {
    _isDisposed = true;
    if(_waveTicker.isActive) _waveTicker.stop();
    _waveTicker.dispose();

    _recorder.closeRecorder();
    _sineEngine.dispose();

    _audioStreamController?.close();

    super.onClose();
  }

  @override
  void setVolume(double volume, {bool? rightOrLeft}) {
    currentVol.value = volume;
    _sineEngine.volume = volume;
    chamberPreset.neomParameter!.volume = volume;
    final visualAmp = 0.12 + (volume * 0.25);
    setVisualAmplitude(visualAmp);
    if(existsInChamber.value) isUpdate.value = true;
  }

  Future<void> playStopPreview({bool stop = false}) async {
    if (isPlaying.value || stop) {
      await _sineEngine.stop();
      isPlaying.value = false;
      NeomStopwatch().pause(ref: chamberPreset.id);
      if(_waveTicker.isActive) _waveTicker.stop();
    } else {
      _syncParams();
      await _sineEngine.start();
      isPlaying.value = true;
      NeomStopwatch().start(ref: chamberPreset.id);
      if(!_waveTicker.isActive) _waveTicker.start();
    }
    update([AppPageIdConstants.generator]);
  }

  @override
  Future<void> setFrequency(double frequency) async {
    currentFreq.value = frequency;
    _sineEngine.frequency = frequency;
    chamberPreset.mainFrequency?.frequency = frequency;
    updateDescriptionForFrequency(frequency);
    if (existsInChamber.value) isUpdate.value = true;
  }

  @override
  void setBinauralBeat({double beat = 0}) {
    final clampedBeat = beat.clamp(
      -NeomGeneratorConstants.binauralBeatMax,
      NeomGeneratorConstants.binauralBeatMax,
    );

    currentBeat.value = clampedBeat;
    _sineEngine.beat = clampedBeat.abs(); // 🔊 audio usa diferencia

    if (clampedBeat != 0) {
      final secondFreq = currentFreq.value + clampedBeat;

      chamberPreset.binauralFrequency = NeomFrequency(
        frequency: secondFreq,
        description: clampedBeat > 0
            ? "Binaural +${clampedBeat.toStringAsFixed(0)}"
            : "Binaural ${clampedBeat.toStringAsFixed(0)}",
      );
    } else {
      chamberPreset.binauralFrequency = null;
    }

    update([AppPageIdConstants.generator]);
  }


  // --- HELPERS ---
  void updateDescriptionForFrequency(double frequency) {
    frequencyDescription.value = "";
    if (frequencyServiceImpl != null) {
      for (NeomFrequency neomFreq in frequencyServiceImpl!.frequencies.values) {
        if(neomFreq.frequency.ceilToDouble() == frequency.ceilToDouble()) {
          frequencyDescription.value = neomFreq.description;
          break;
        }
      }
    }
  }

  void setFrequencyState(AppItemState newState){
    AppConfig.logger.d("Setting new appItem $newState");
    frequencyState.value = newState.value;
    chamberPreset.state = newState.value;
    update([AppPageIdConstants.generator]);
  }

  void setSelectedItemlist(String selectedItemlist){
    AppConfig.logger.d("Setting selectedItemlist $selectedItemlist");
    chamber.value.id  = selectedItemlist;
    update([AppPageIdConstants.generator]);
  }

  bool frequencyAlreadyInItemlist() {
    bool already = false;
    for (var nChamber in chambers.values) {
      for (var presets in nChamber.chamberPresets ?? []) {
        if (chamberPreset.id == presets.id) {
          already = true;
          chamber.value = nChamber;
        }
      }
    }
    return already;
  }

  Future<void> addPreset(BuildContext context, {int frequencyPracticeState = 0}) async {

    if(!isButtonDisabled.value) {
      isButtonDisabled.value = true;
      isLoading.value = true;
      update([AppPageIdConstants.generator]);

      AppConfig.logger.i("ChamberPreset would be added as $frequencyState for Itemlist ${chamber.value.id}");

      if(frequencyPracticeState > 0) frequencyState.value = frequencyPracticeState;

      if(noChambers) {
        chamber.value.name = CommonTranslationConstants.myFavItemlistName.tr;
        chamber.value.description = CommonTranslationConstants.myFavItemlistDesc.tr;
        chamber.value.imgUrl = AppProperties.getAppLogoUrl();
        chamber.value.ownerId = profile?.id ?? '';
        chamber.value.id = await ChamberFirestore().insert(chamber.value);
      } else {
        if(chamber.value.id.isEmpty) chamber.value.id = chambers.values.first.id;
      }

      if(chamber.value.id.isNotEmpty) {

        try {
          chamberPreset.id = "${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()}_${chamberPreset.neomParameter!.volume.toString()}"
              "_${chamberPreset.neomParameter!.x.toString()}_${chamberPreset.neomParameter!.y.toString()}_${chamberPreset.neomParameter!.z.toString()}";
          chamberPreset.name = "${AppTranslationConstants.frequency.tr} ${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()} Hz";
          chamberPreset.imgUrl = AppProperties.getAppLogoUrl();
          chamberPreset.ownerId = profile?.id ?? '';
          chamberPreset.mainFrequency!.description = frequencyDescription.value;
          if(await ChamberFirestore().addPreset(chamber.value.id, chamberPreset)) {
            await ProfileFirestore().addChamberPreset(profileId: profile?.id ?? '', chamberPresetId: chamberPreset.id);
            await userServiceImpl?.reloadProfileItemlists();
            await userServiceImpl?.loadProfileChambers();
            userServiceImpl?.profile.chamberPresets?.add(chamberPreset.id);
            AppConfig.logger.d("Preset added to Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not added to Neom NeomChamber");
          }
        } catch (e) {
          AppConfig.logger.e(e.toString());
          AppUtilities.showSnackBar(
              title: AppTranslationConstants.generator.tr,
              message: 'Algo salió mal agregando tu preset a tu cámara Neom.'
          );
        }

        AppUtilities.showSnackBar(
            title: AppTranslationConstants.generator.tr,
            message: 'El preajuste para la frecuencia de "${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()}"'
                ' Hz fue agregado a la Cámara Neom: ${chamber.value.name}.'
        );
      }
    }

    existsInChamber.value = true;
    isButtonDisabled.value = false;
    isLoading.value = false;

    update([]);
  }

  Future<void> removePreset(BuildContext context) async {


    if(!isButtonDisabled.value) {
      isButtonDisabled.value = true;
      isLoading.value = true;
      update([AppPageIdConstants.generator]);

      AppConfig.logger.i("ChamberPreset would be removed for Itemlist ${chamber.value.id}");

      if(chamber.value.id.isEmpty) chamber.value.id = chambers.values.first.id;

      if(chamber.value.id.isNotEmpty) {
        try {
          if(await ChamberFirestore().deletePreset(chamber.value.id, chamberPreset)) {
            await userServiceImpl?.reloadProfileItemlists();
            chambers.value = userServiceImpl?.profile.chambers ?? {};
            AppConfig.logger.d("Preset removed from Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not removed from Neom NeomChamber");
          }
        } catch (e) {
          AppConfig.logger.e(e.toString());
          AppUtilities.showSnackBar(
              title: GeneratorTranslationConstants.neomChamber.tr,
              message: 'Algo salió mal eliminando tu preset de tu cámara Neom.'
          );
        }

        AppUtilities.showSnackBar(
            title: GeneratorTranslationConstants.neomChamber.tr,
            message: 'El preajuste para la frecuencia de "${chamberPreset.binauralFrequency?.frequency.ceilToDouble().toString()}"'
                ' Hz fue removido de la Cámara Neom: ${chamber.value.name} satisfactoriamente.'
        );
      }
    }

    existsInChamber.value = false;
    isButtonDisabled.value = false;
    isLoading.value = false;
    update([]);
  }

  @override
  void setParameterPosition({required double x, required double y, required double z}) {
    AppConfig.logger.d("Setting position x:$x y:$y z:$z");
    posX.value = x;
    posY.value = y;
    posZ.value = z;
    _sineEngine.posX = x / NeomGeneratorConstants.positionMax;
    _sineEngine.posY = y / NeomGeneratorConstants.positionMax;
    _sineEngine.posZ = z / NeomGeneratorConstants.positionMax;

    chamberPreset.neomParameter!.x = x;
    chamberPreset.neomParameter!.y = y;
    chamberPreset.neomParameter!.z = z;
    if(existsInChamber.value) isUpdate.value = true;
    // update(); // No necesario si usamos Obx en UI para sliders
  }

  Future<void> increaseFrequency({double step = 1}) async {
    double newFreq = currentFreq.value + step;
    await setFrequency(newFreq);
  }

  Future<void> decreaseFrequency({double step = 1}) async {
    double newFreq = currentFreq.value - step;
    if(newFreq > 0) await setFrequency(newFreq);
  }

  Future<void> increaseActiveValue({double step = 1}) async {
    switch (activeNumericTarget.value) {
      case NeomNumericTarget.rootFrequency:
        await increaseFrequency(step: step);
        break;

      case NeomNumericTarget.binauralBeat:
        setBinauralBeat(
          beat: currentBeat.value + step,
        );
        break;
    }
  }

  Future<void> decreaseActiveValue({double step = 1}) async {
    switch (activeNumericTarget.value) {
      case NeomNumericTarget.rootFrequency:
        await decreaseFrequency(step: step);
        break;

      case NeomNumericTarget.binauralBeat:
        setBinauralBeat(
          beat: currentBeat.value - step,
        );
        break;
    }
  }

  RxBool longPressed = false.obs;
  RxInt timerDuration = NeomGeneratorConstants.recursiveCallTimerDuration.obs;

  void increaseOnLongPress() {
    if (longPressed.value) {
      if (timerDuration > NeomGeneratorConstants.recursiveCallTimerDurationMin) {
        timerDuration--;
      }
      increaseActiveValue();
      Timer(Duration(milliseconds: timerDuration.value), increaseOnLongPress);
    }
  }

  void decreaseOnLongPress() {
    if (longPressed.value) {
      if (timerDuration > NeomGeneratorConstants.recursiveCallTimerDurationMin) {
        timerDuration--;
      }
      decreaseActiveValue();
      Timer(Duration(milliseconds: timerDuration.value), decreaseOnLongPress);
    }
  }

  Future<void> initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  void initializeStreamController(){
    _audioStreamController = StreamController<Uint8List>(sync: true);
    _audioStreamController!.stream.listen((audioData) async {
      if (_isDisposed) return;
      double freqPitch = await getPitchFromAudioData(audioData);
      if(freqPitch > NeomGeneratorConstants.frequencyMin && freqPitch < (isAdmin ? NeomGeneratorConstants.frequencyMax : NeomGeneratorConstants.frequencyLimit)) {
        AppConfig.logger.d("Pitch: $freqPitch Hz");
        detectedFrequency = freqPitch;
        detectedPitches.add(freqPitch);
      }

      update([AppPageIdConstants.generator]);
    });
  }

  Future<void> startRecording() async {
    AppConfig.logger.d("Start Recording");

    try {
      // 1. Detener audio (Obligatorio para evitar feedback)
      if (isPlaying.value) await playStopPreview(stop: true);

      isRecording = true;
      detectedFrequency = 0;

      if (_audioStreamController == null) {
        initializeStreamController();
      }

      _recorder.startRecorder(
        codec: Codec.pcm16,
        sampleRate: NeomGeneratorConstants.sampleRate,
        numChannels: 1,
        toStream: _audioStreamController?.sink, //
      );

      // Stop the recorder after x seconds
      Timer(Duration(seconds: NeomGeneratorConstants.sampleDuration), () {
        if (!_isDisposed) stopRecording();
        if((detectedFrequency) > 0) {
          setFrequency(detectedFrequency);
        }
      });
    } catch(e) {
      AppConfig.logger.e(e.toString());
    }

    update([AppPageIdConstants.generator]);
  }

  void stopRecording() async {
    await _recorder.stopRecorder();
    isRecording = false;
    detectedFrequency = getMostFrequentPitch();
    if(detectedFrequency > 0) playStopPreview();
    update([AppPageIdConstants.generator]);
  }

  Future<double> getPitchFromAudioData(Uint8List audioData) async {
    _accumulatedData.addAll(audioData);

    const int bytesPerSample = 2;
    double pitch = 0;
    int neededBytes = NeomGeneratorConstants.neededSamples * bytesPerSample;

    while (_accumulatedData.length >= neededBytes) {
      // Extraemos los primeros neededBytes
      final chunk = _accumulatedData.sublist(0, neededBytes);
      // Los removemos del acumulado para postearior analisis del buffer
      _accumulatedData.removeRange(0, neededBytes);

      final pitchDetectorDart = PitchDetector(
        audioSampleRate: NeomGeneratorConstants.sampleRate.toDouble(),
        bufferSize: NeomGeneratorConstants.neededSamples,
      );

      try {
        final chunkAsUint8List = Uint8List.fromList(chunk);

        PitchDetectorResult pitchResult = await pitchDetectorDart.getPitchFromIntBuffer(chunkAsUint8List);
        pitch = pitchResult.pitch.roundToDouble();
      } catch (e) {
        AppConfig.logger.e("Pitch detector error: $e");
      }
    }

    return pitch;
  }

  double getMostFrequentPitch() {
    if (detectedPitches.isEmpty) return 0;

    final Map<double, int> frequencyMap = {};

    for (var pitch in detectedPitches) {
      frequencyMap[pitch] = (frequencyMap[pitch] ?? 0) + 1;
    }

    final mostFrequentEntry = frequencyMap.entries
        .reduce((a, b) => a.value >= b.value ? a : b);

    return mostFrequentEntry.key; //Most recurrent freq
  }

  void _syncParams() {
    _sineEngine.frequency = currentFreq.value;
    _sineEngine.beat = currentBeat.value;
    _sineEngine.volume = currentVol.value;
  }

  void setIsochronicEnabled(bool enabled) {
    isIsochronicEnabled.value = enabled;
    _sineEngine.isochronic.enabled = enabled;
  }

  void setIsochronicFrequency(double hz) {
    isochronicFreq.value = hz;
    _sineEngine.isochronic.pulseFrequency = hz;
  }

  void setIsochronicDuty(double duty) {
    isochronicDuty.value = duty;
    _sineEngine.isochronic.dutyCycle = duty;
  }

  void setModulationType(NeomModulationType type) {
    modulationType.value = type;
    _sineEngine.modulator.type = type;
  }

  void setModulationFrequency(double hz) {
    modulationFreq.value = hz;
    _sineEngine.modulator.modFrequency = hz;
  }

  void setModulationDepth(double depth) {
    modulationDepth.value = depth;
    _sineEngine.modulator.depth = depth;
  }

  final Rx<NeomSpatialMode> spatialMode =
      NeomSpatialMode.softPan.obs;

  final RxDouble orbitSpeed = 0.15.obs;

  void setSpatialMode(NeomSpatialMode mode) {
    spatialMode.value = mode;
    _sineEngine.spatialMode = mode;
  }

  void setOrbitSpeed(double speed) {
    orbitSpeed.value = speed;
    _sineEngine.orbitSpeed = speed;
  }

  void setModulationEnabled(bool enabled) {
    AppConfig.logger.d("Setting modulation enabled: $enabled");
    isModulationEnabled.value = enabled;
    _sineEngine.modulator.enabled = enabled;
  }

  final RxDouble spatialIntensity = 0.5.obs;
  final RxInt orbitDirection = 1.obs;

  void setSpatialIntensity(double v) {
    spatialIntensity.value = v;
    _sineEngine.spatialIntensity = v;
  }

  void setOrbitDirection(int dir) {
    orbitDirection.value = dir;
    _sineEngine.orbitDirection = dir;
  }

  final Rx<NeomBreathMode> breathMode =
      NeomBreathMode.off.obs;

  final RxDouble breathRate = 6.0.obs;
  final RxDouble breathDepth = 0.5.obs;

  void setBreathMode(NeomBreathMode mode) {
    breathMode.value = mode;
    _sineEngine.breathEngine.mode = mode;
  }

  void setBreathRate(double bpm) {
    breathRate.value = bpm;
    _sineEngine.breathEngine.breathsPerMinute = bpm;
  }

  void setBreathDepth(double depth) {
    breathDepth.value = depth;
    _sineEngine.breathEngine.depth = depth;
  }

  final Rx<NeomNeuroState> neuroState =
      NeomNeuroState.neutral.obs;

  void setNeuroState(NeomNeuroState state) {
    neuroState.value = state;

    _sineEngine.neuroStateEngine.applyState(
      state: state,
      breath: _sineEngine.breathEngine,
      modulator: _sineEngine.modulator,
      setIsochronic: setIsochronicEnabled,
      setIsoFreq: setIsochronicFrequency,
      setSpatialMode: setSpatialMode,
      setSpatialIntensity: setSpatialIntensity,
    );
  }

  void setVisualAmplitude(double v) {
    painterEngine.visualAmplitudeBase = v;
    painterEngine.notifyListeners();
  }

  final Rx<NeomVisualMode> visualMode =
      NeomVisualMode.scientific.obs;

  void setVisualMode(NeomVisualMode mode) {
    visualMode.value = mode;

    // Ajustes visuales únicamente
    if (mode == NeomVisualMode.scientific) {
      painterEngine.visualAmplitudeBase = 0.10;
      painterEngine.visualAmplitudeMax = 0.35;
      painterEngine.setSmoothingProfile(
        amplitude: 0.35,
        breath: 0.15,
        neuro: 0.12,
      );
    } else {
      painterEngine.visualAmplitudeBase = 0.18;
      painterEngine.visualAmplitudeMax = 0.55;
      painterEngine.setSmoothingProfile(
        amplitude: 0.15,
        breath: 0.35,
        neuro: 0.25,
      );
    }

    painterEngine.notifyListeners();
  }

  final isEditingFrequency = false.obs;
  final TextEditingController frequencyEditCtrl = TextEditingController();
  final Rx<NeomNumericTarget> activeNumericTarget =
      NeomNumericTarget.rootFrequency.obs;


  void startEditFrequency() {
    activeNumericTarget.value = NeomNumericTarget.rootFrequency;
    frequencyEditCtrl.text = currentFreq.value.toStringAsFixed(0);
    isEditingFrequency.value = true;
  }

  void finishEditFrequency() {
    setFrequencyFromText(frequencyEditCtrl.text);
    isEditingFrequency.value = false;
  }

  void setFrequencyFromText(String value) {
    if (value.isEmpty) return;

    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return;

    final min = NeomGeneratorConstants.frequencyMin;
    final max = isAdmin
        ? NeomGeneratorConstants.frequencyMax
        : NeomGeneratorConstants.frequencyLimit;

    final clamped = parsed.clamp(min, max);

    setFrequency(clamped);
  }

  final isEditingBeat = false.obs;
  final TextEditingController beatEditCtrl = TextEditingController();

  void startEditBeat() {
    activeNumericTarget.value = NeomNumericTarget.binauralBeat;
    beatEditCtrl.text = currentBeat.value.toStringAsFixed(0);
    isEditingBeat.value = true;
  }

  void finishEditBeat() {
    final v = double.tryParse(beatEditCtrl.text);
    if (v != null) {
      final clamped = v.clamp(0.0, NeomGeneratorConstants.binauralBeatMax);
      setBinauralBeat(beat: clamped);
    }
    isEditingBeat.value = false;
  }

  final Rx<NeomFrequencyTarget> selectedTarget =
      NeomFrequencyTarget.root.obs;

  void selectRootFrequency() {
    selectedTarget.value = NeomFrequencyTarget.root;
    activeNumericTarget.value = NeomNumericTarget.rootFrequency;
  }

  void selectBinauralBeat() {
    selectedTarget.value = NeomFrequencyTarget.binaural;
    activeNumericTarget.value = NeomNumericTarget.binauralBeat;
  }

  Future<void> increaseSelected({double step = 1}) async {
    if (selectedTarget.value == NeomFrequencyTarget.root) {
      await setFrequency(currentFreq.value + step);
    } else {
      setBinauralBeat(beat: currentBeat.value + step);
    }
  }

  Future<void> decreaseSelected({double step = 1}) async {
    if (selectedTarget.value == NeomFrequencyTarget.root) {
      await setFrequency(currentFreq.value - step);
    } else {
      setBinauralBeat(beat: currentBeat.value - step);
    }
  }

}

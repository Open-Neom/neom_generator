import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter_sound/flutter_sound.dart';
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
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/domain/model/neom/neom_parameter.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/domain/use_cases/frequency_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:neom_core/utils/enums/user_role.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import 'package:sint/sint.dart';

import '../data/firestore/chamber_firestore.dart';
import '../data/implementations/incienso_recorder.dart';
import '../data/implementations/incienso_tracker.dart';
import '../domain/models/incienso.dart';
import '../domain/models/incienso_session.dart';
import '../domain/use_cases/neom_generator_service.dart';
import '../engine/neom_breath_engine.dart';
import '../engine/neom_frequency_painter_engine.dart';
import '../engine/neom_modulator_engine.dart';
import '../engine/neom_sine_engine.dart';
import '../engine/web_audio_context_stub.dart'
    if (dart.library.js_interop) '../engine/web_audio_context_impl.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/enums/neom_frequency_target.dart';
import '../utils/enums/neom_numeric_target.dart';
import '../utils/enums/neom_spatial_mode.dart';
import '../utils/enums/neom_visual_mode.dart';

class NeomGeneratorController extends SintController implements NeomGeneratorService {

  UserService? userServiceImpl;
  FrequencyService? frequencyServiceImpl;
  final ChamberRepository chamberRepository = ChamberFirestore();

  final NeomSineEngine _sineEngine = NeomSineEngine();
  final NeomFrequencyPainterEngine painterEngine = NeomFrequencyPainterEngine();

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
  final RxInt currentOctave = 0.obs; // Octave shift: -4=/16 ... 0=1x ... +4=x16

  // Visual effect flags (web)
  final RxBool showCircuitWave = true.obs;
  final RxBool showPerimeterWave = true.obs;

  // Posición Espacial (Solo visual/guardado por ahora en modo binaural)
  final RxDouble posX = 0.0.obs;
  final RxDouble posY = 0.0.obs;
  final RxDouble posZ = 0.0.obs;

  // Animación del Visualizador
  Ticker? _waveTicker;
  final RxDouble wavePhase = 0.0.obs; // Controla el movimiento de la onda

  AppProfile? profile;
  NeomChamberPreset chamberPreset = NeomChamberPreset();

  RxBool isPlaying = false.obs;
  RxBool isLoading = true.obs;

  /// Oscilloscope time scale (1.0 = full buffer, 0.15 = zoomed in).
  final RxDouble oscTimeScale = 1.0.obs;

  /// Real-time microphone waveform bars for visualization during voice detection.
  /// Values are normalized 0.0–1.0 amplitudes, max 200 bars.
  final RxList<double> micWaveform = <double>[].obs;
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
  RxBool isRecording = false.obs;
  RxDouble detectedFrequency = 0.0.obs;
  StreamController<Uint8List>? _audioStreamController;
  final List<int> _accumulatedData = [];
  List<double> detectedPitches = [];

  bool _isDisposed = false;
  bool isAdmin = false;

  // ── Web sample rate (from AudioContext — exact) ──
  bool _webSampleRateDetected = false;
  double _webSampleRate = 48000.0;
  bool _webIsStereoDetermined = false;
  bool _webIsStereo = false;
  int _webByteAccum = 0;
  DateTime? _webByteStart;

  // ── Incienso tracking & recording ──
  final InciensoTracker inciensoTracker = InciensoTracker();
  final InciensoRecorder inciensoRecorder = InciensoRecorder();
  DateTime? _sessionStartedAt;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  double _prevBreathPhase = 0.0;

  @override
  void onInit() async {
    super.onInit();
    _sineEngine.painterEngine = painterEngine;
    try {
      final arguments = (Sint.arguments as List<dynamic>?) ?? [];
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

        // ── Incienso hooks ──
        final coherence = painterEngine.hemisphericCoherence;

        // Detect breath cycle completion (phase wrap)
        final breathPhase = _sineEngine.breathEngine.currentValue;
        if (_prevBreathPhase > 0.8 && breathPhase < 0.2
            && _sineEngine.breathEngine.mode != NeomBreathMode.off) {
          inciensoTracker.onBreathCycle(coherence: coherence);
        }
        _prevBreathPhase = breathPhase;

        // Continuous coherence reading (~every frame)
        inciensoTracker.onCoherenceReading(coherence);

        // Feed recorder with current values
        if (inciensoRecorder.isRecording) {
          inciensoRecorder.updateValues(
            leftHz: currentFreq.value,
            rightHz: currentFreq.value + currentBeat.value,
            coherence: coherence,
            volume: currentVol.value,
            neuroState: neuroState.value,
            breathPhase: breathPhase,
          );
        }

      });

    } catch(e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'onInit');
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

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'onReady');
    }

    isLoading.value = false;
    update([AppPageIdConstants.generator]);
  }

  @override
  void onClose() {
    _isDisposed = true;
    if(_waveTicker?.isActive ?? false) _waveTicker?.stop();
    _waveTicker?.dispose();

    _recorder.closeRecorder();
    // Don't dispose the sine engine — it's a singleton shared across
    // onboarding, mini player, and Cámara Neom. Audio persists after
    // navigating away from the generator page.
    // _sineEngine.dispose();

    _audioStreamController?.close();

    inciensoTracker.dispose();
    inciensoRecorder.dispose();

    frequencyEditCtrl.dispose();
    beatEditCtrl.dispose();

    super.onClose();
  }

  @override
  void setVolume(double volume, {bool? rightOrLeft}) {
    currentVol.value = volume;
    _sineEngine.volume = volume;
    chamberPreset.neomParameter?.volume = volume;
    final visualAmp = 0.12 + (volume * 0.25);
    setVisualAmplitude(visualAmp);
    if(existsInChamber.value) isUpdate.value = true;
  }

  Future<void> playStopPreview({bool stop = false}) async {
    // Ensure engine is ready before any play/stop
    await _sineEngine.init();

    if (isPlaying.value || stop) {
      await _sineEngine.stop();
      isPlaying.value = false;
      NeomStopwatch().pause(ref: chamberPreset.id);
      if(_waveTicker?.isActive ?? false) _waveTicker?.stop();

      // Stop incienso tracking
      inciensoTracker.stop();
      _prevBreathPhase = 0.0;
    } else {
      _syncParams();
      await _sineEngine.start();
      isPlaying.value = true;
      NeomStopwatch().start(ref: chamberPreset.id);
      if(!(_waveTicker?.isActive ?? false)) _waveTicker?.start();

      // Start incienso tracking
      _sessionStartedAt = DateTime.now();
      inciensoTracker.start();
      inciensoRecorder.startRecording();
    }
    update([AppPageIdConstants.generator, 'miniNeomPlayer']);
  }

  /// Effective frequency sent to the audio engine (base * 2^octave).
  /// Positive octaves multiply (2x, 4x, 8x, 16x).
  /// Negative octaves divide (/2, /4, /8, /16).
  double get effectiveFrequency {
    final oct = currentOctave.value;
    if (oct >= 0) {
      return currentFreq.value * (1 << oct); // base * 2^oct
    }
    return currentFreq.value / (1 << oct.abs()); // base / 2^|oct|
  }

  @override
  Future<void> setFrequency(double frequency) async {
    currentFreq.value = frequency;
    _applyEffectiveFrequency();
    chamberPreset.mainFrequency?.frequency = frequency;
    updateDescriptionForFrequency(frequency);
    if (existsInChamber.value) isUpdate.value = true;

    if (inciensoRecorder.isRecording) {
      inciensoRecorder.captureUserAction(leftHz: effectiveFrequency);
    }
  }

  void setOctave(int octave) {
    currentOctave.value = octave.clamp(-4, 4);
    _applyEffectiveFrequency();
  }

  void _applyEffectiveFrequency() {
    _sineEngine.frequency = effectiveFrequency;
  }

  @override
  void setBinauralBeat({double beat = 0}) {
    final clampedBeat = beat.clamp(
      -NeomGeneratorConstants.binauralBeatMax,
      NeomGeneratorConstants.binauralBeatMax,
    );

    currentBeat.value = clampedBeat;
    _sineEngine.beat = clampedBeat.abs();

    // Record user-driven beat change
    if (inciensoRecorder.isRecording) {
      inciensoRecorder.captureUserAction(
        rightHz: currentFreq.value + clampedBeat,
      );
    }

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
        chamber.value.id = await chamberRepository.insert(chamber.value);
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
          if(await chamberRepository.addPreset(chamber.value.id, chamberPreset)) {
            await ProfileFirestore().addChamberPreset(profileId: profile?.id ?? '', chamberPresetId: chamberPreset.id);
            await userServiceImpl?.reloadProfileItemlists();
            await userServiceImpl?.loadProfileChambers();
            userServiceImpl?.profile.chamberPresets?.add(chamberPreset.id);
            AppConfig.logger.d("Preset added to Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not added to Neom NeomChamber");
          }
        } catch (e, st) {
          NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'addPreset');
          AppUtilities.showSnackBar(
              title: AppTranslationConstants.generator.tr,
              message: GeneratorTranslationConstants.presetAddError.tr,
          );
        }

        AppUtilities.showSnackBar(
            title: AppTranslationConstants.generator.tr,
            message: '${GeneratorTranslationConstants.presetAddedMsg.tr}'
                ' ${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()}'
                ' Hz - ${chamber.value.name}.',
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
          if(await chamberRepository.deletePreset(chamber.value.id, chamberPreset)) {
            await userServiceImpl?.reloadProfileItemlists();
            chambers.value = userServiceImpl?.profile.chambers ?? {};
            AppConfig.logger.d("Preset removed from Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not removed from Neom NeomChamber");
          }
        } catch (e, st) {
          NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'removePreset');
          AppUtilities.showSnackBar(
              title: GeneratorTranslationConstants.neomChamber.tr,
              message: GeneratorTranslationConstants.presetRemoveError.tr,
          );
        }

        AppUtilities.showSnackBar(
            title: GeneratorTranslationConstants.neomChamber.tr,
            message: '${GeneratorTranslationConstants.presetRemovedMsg.tr}'
                ' ${chamberPreset.binauralFrequency?.frequency.ceilToDouble().toString()}'
                ' Hz - ${chamber.value.name}.',
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

    chamberPreset.neomParameter?.x = x;
    chamberPreset.neomParameter?.y = y;
    chamberPreset.neomParameter?.z = z;
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

      // Get exact sample rate from AudioContext + detect mono/stereo
      if (kIsWeb) _detectWebSampleRate(audioData.length);

      // Feed real-time waveform visualization
      _pushMicAmplitude(audioData);

      double freqPitch = await getPitchFromAudioData(audioData);
      if(freqPitch > NeomGeneratorConstants.frequencyMin && freqPitch < (isAdmin ? NeomGeneratorConstants.frequencyMax : NeomGeneratorConstants.frequencyLimit)) {
        AppConfig.logger.d("Pitch: $freqPitch Hz");
        detectedFrequency.value = freqPitch;
        detectedPitches.add(freqPitch);
      }

      update([AppPageIdConstants.generator]);
    });
  }

  /// Get the real sample rate from the browser's AudioContext.
  /// This is exact — no heuristics, no guessing.
  ///
  /// Also determines mono/stereo by comparing actual byte throughput
  /// against the known sample rate:
  ///   mono  = sampleRate × 2 bytes/sample
  ///   stereo = sampleRate × 4 bytes/frame
  void _detectWebSampleRate(int chunkBytes) {
    if (!_webSampleRateDetected) {
      _webSampleRate = getWebAudioContextSampleRate();
      _webSampleRateDetected = true;
      AppConfig.logger.d('Web AudioContext.sampleRate: $_webSampleRate Hz');
    }

    // Determine mono vs stereo from byte throughput
    if (_webIsStereoDetermined) return;
    _webByteStart ??= DateTime.now();
    _webByteAccum += chunkBytes;
    final elapsedMs = DateTime.now().difference(_webByteStart!).inMilliseconds;
    if (elapsedMs < 400) return; // Need 400ms of data

    final bytesPerSec = _webByteAccum * 1000.0 / elapsedMs;
    final expectedMono = _webSampleRate * 2;   // 2 bytes per int16 sample
    final expectedStereo = _webSampleRate * 4;  // 4 bytes per stereo frame

    final diffMono = (bytesPerSec - expectedMono).abs();
    final diffStereo = (bytesPerSec - expectedStereo).abs();

    _webIsStereo = diffStereo < diffMono;
    _webIsStereoDetermined = true;
    AppConfig.logger.d('Web audio format: ${_webIsStereo ? "STEREO" : "MONO"} '
        '(${bytesPerSec.round()} B/s, expected mono=${expectedMono.round()}, stereo=${expectedStereo.round()})');
  }

  /// Extract RMS amplitude from PCM int16 chunk and push to waveform.
  void _pushMicAmplitude(Uint8List audioData) {
    if (audioData.length < 2) return;
    final byteData = ByteData.sublistView(audioData);
    final sampleCount = audioData.length ~/ 2;
    double sumSquares = 0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / sampleCount) / 32768.0;
    final bar = rms.clamp(0.02, 1.0);
    micWaveform.add(bar);
    if (micWaveform.length > 200) {
      micWaveform.removeAt(0);
    }
  }

  Future<void> startRecording() async {
    AppConfig.logger.d("Start Recording");

    try {
      // 1. Detener audio (Obligatorio para evitar feedback)
      if (isPlaying.value) await playStopPreview(stop: true);

      isRecording.value = true;
      detectedFrequency.value = 0;
      micWaveform.clear();
      _webSampleRateDetected = false;
      _webSampleRate = 48000.0;
      _webIsStereoDetermined = false;
      _webIsStereo = false;
      _webByteAccum = 0;
      _webByteStart = null;

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
        if((detectedFrequency.value) > 0) {
          setFrequency(detectedFrequency.value);
        }
      });
    } catch(e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'startRecording');
    }

    update([AppPageIdConstants.generator]);
  }

  void stopRecording() async {
    await _recorder.stopRecorder();
    isRecording.value = false;
    detectedFrequency.value = getMostFrequentPitch();
    if(detectedFrequency.value > 0) playStopPreview();
    update([AppPageIdConstants.generator]);
  }

  Future<double> getPitchFromAudioData(Uint8List audioData) async {
    // Web browsers may deliver stereo (2-ch interleaved int16) even when mono
    // is requested. Down-mix to mono so the pitch detector sees the correct
    // period — otherwise every other sample belongs to a different channel,
    // which halves the apparent frequency (one octave down).
    if (kIsWeb) {
      _accumulatedData.addAll(_stereoToMono(audioData));
    } else {
      _accumulatedData.addAll(audioData);
    }

    const int bytesPerSample = 2;
    double pitch = 0;
    int neededBytes = NeomGeneratorConstants.neededSamples * bytesPerSample;

    // On web, use the auto-detected sample rate from _calibrateWebSampleRate().
    // On mobile, use the requested rate (OS respects it).
    final double effectiveSampleRate = kIsWeb
        ? _webSampleRate
        : NeomGeneratorConstants.sampleRate.toDouble();

    while (_accumulatedData.length >= neededBytes) {
      final chunk = _accumulatedData.sublist(0, neededBytes);
      _accumulatedData.removeRange(0, neededBytes);

      final pitchDetectorDart = PitchDetector(
        audioSampleRate: effectiveSampleRate,
        bufferSize: NeomGeneratorConstants.neededSamples,
      );

      try {
        final chunkAsUint8List = Uint8List.fromList(chunk);

        PitchDetectorResult pitchResult = await pitchDetectorDart.getPitchFromIntBuffer(chunkAsUint8List);
        pitch = pitchResult.pitch.roundToDouble();
      } catch (e, st) {
        NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'getPitchFromAudioData');
      }
    }

    return pitch;
  }

  /// Convert interleaved stereo int16 PCM to mono by averaging L+R channels.
  /// If the buffer has an odd number of samples (already mono), returns as-is.
  /// Convert stereo int16 interleaved data to mono by averaging L+R.
  /// Only converts if [_webIsStereo] is true (determined from byte rate).
  /// If mono, returns data unchanged.
  Uint8List _stereoToMono(Uint8List data) {
    // Don't convert until we've determined the format
    if (!_webIsStereoDetermined || !_webIsStereo) return data;
    if (data.length < 4) return data;

    final byteData = ByteData.sublistView(data);
    final int totalSamples = data.length ~/ 2;
    if (totalSamples < 2) return data;

    final int frames = totalSamples ~/ 2;
    final monoBytes = Uint8List(frames * 2);
    final monoView = ByteData.sublistView(monoBytes);

    for (int i = 0; i < frames; i++) {
      final int left = byteData.getInt16(i * 4, Endian.little);
      final int right = byteData.getInt16(i * 4 + 2, Endian.little);
      final int mono = ((left + right) ~/ 2).clamp(-32768, 32767);
      monoView.setInt16(i * 2, mono, Endian.little);
    }

    return monoBytes;
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
    _sineEngine.frequency = effectiveFrequency;
    _sineEngine.beat = currentBeat.value;
    _sineEngine.volume = currentVol.value;
    _sineEngine.isochronic.enabled = isIsochronicEnabled.value;
    _sineEngine.isochronic.pulseFrequency = isochronicFreq.value;
    _sineEngine.isochronic.dutyCycle = isochronicDuty.value;
    _sineEngine.modulator.enabled = isModulationEnabled.value;
    _sineEngine.modulator.type = modulationType.value;
    _sineEngine.modulator.modFrequency = modulationFreq.value;
    _sineEngine.modulator.depth = modulationDepth.value;
  }

  Future<void> setIsochronicEnabled(bool enabled) async {
    isIsochronicEnabled.value = enabled;
    _sineEngine.isochronic.enabled = enabled;
    // Restart stream so the change takes effect immediately on web,
    // where buffered audio may delay parameter updates.
    if (isPlaying.value) {
      await _sineEngine.stop();
      _syncParams();
      await _sineEngine.start();
    }
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
    inciensoTracker.onStateChanged(state);

    // Capture user action in recorder
    if (inciensoRecorder.isRecording) {
      inciensoRecorder.captureUserAction(neuroState: state);
    }

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
    painterEngine.notifyVisualUpdate();
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

    painterEngine.notifyVisualUpdate();
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

  // ── Incienso public getters for UI binding ──

  /// Qualifying breath cycles in this session.
  int get inciensoCount => inciensoTracker.inciensoCount;

  /// Quality ratio: qualifying / total cycles.
  double get qualityRatio => inciensoTracker.qualityRatio;

  /// Whether the incienso recorder is actively recording.
  bool get isInciensoRecording => inciensoRecorder.isRecording;

  // ── Incienso session builder ──

  /// Build an [InciensoSession] from the current tracker data.
  /// Call after stopping playback.
  InciensoSession buildInciensoSession({
    String inciensoId = '',
    InciensoSource source = InciensoSource.userCreated,
    InciensoSessionEnd endReason = InciensoSessionEnd.stoppedByUser,
  }) {
    final now = DateTime.now();
    return InciensoSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      userId: profile?.id,
      inciensoId: inciensoId,
      inciensoSource: source,
      startedAt: _sessionStartedAt ?? now,
      endedAt: now,
      suggestedDuration: const Duration(minutes: 10),
      rootFrequencyHz: detectedFrequency.value,
      carrierLeftHz: currentFreq.value,
      carrierRightHz: currentFreq.value + currentBeat.value,
      volume: currentVol.value,
      isochronicEnabled: isIsochronicEnabled.value,
      isochronicHz: isochronicFreq.value,
      totalBreathCycles: inciensoTracker.totalCycles,
      inciensoCount: inciensoTracker.inciensoCount,
      avgCoherence: inciensoTracker.avgCoherence,
      peakCoherence: inciensoTracker.peakCoherence,
      minCoherence: inciensoTracker.minCoherence,
      coherenceStdDev: inciensoTracker.coherenceStdDev,
      coherenceTimeline: inciensoTracker.coherenceTimeline,
      avgBreathCycleMs: inciensoTracker.avgBreathCycleMs,
      breathCV: inciensoTracker.breathCV,
      dominantState: inciensoTracker.dominantState,
      stateTimeSeconds: inciensoTracker.stateTimeMap.map(
        (k, v) => MapEntry(k.name, v),
      ),
      stateTransitions: inciensoTracker.stateTransitions,
      breathingGuideActive: breathMode.value != NeomBreathMode.off,
      spatialAudioEnabled: spatialMode.value != NeomSpatialMode.softPan,
      platform: kIsWeb ? 'web' : 'mobile',
      endReason: endReason,
    );
  }

  /// Stop recording and build a shareable [Incienso] from the session.
  /// Returns null if session was too short (< 30s or < 5 keyframes).
  Incienso? saveAsIncienso(String name) {
    return inciensoRecorder.stopAndBuild(
      name: name,
      creatorId: profile?.id,
    );
  }

}

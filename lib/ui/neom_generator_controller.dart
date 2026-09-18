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
import 'package:neom_core/domain/model/incienso_practice_draft.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_frequency.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/domain/model/neom/neom_parameter.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/domain/use_cases/frequency_service.dart';
import 'package:neom_core/domain/use_cases/neom_audio_visual_signal.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:neom_core/utils/enums/user_role.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import 'package:sint/sint.dart';

import '../data/firestore/chamber_firestore.dart';
import '../data/firestore/incienso_firestore.dart';
import '../data/implementations/chamber_practice_store.dart';
import '../data/implementations/incienso_draft_store.dart';
import '../data/implementations/incienso_playback.dart';
import '../data/implementations/incienso_portable_file.dart';
import '../data/implementations/incienso_recorder.dart';
import '../data/implementations/incienso_tracker.dart';
import '../data/incienso_catalog.dart';
import '../domain/models/incienso.dart';
import '../domain/models/incienso_audio_state.dart';
import '../domain/models/incienso_review.dart';
import '../domain/models/incienso_session.dart';
import '../domain/use_cases/neom_generator_service.dart';
import '../engine/audio/neom_voice_capture.dart';
import '../engine/audio/neom_voice_pitch_measurement.dart' show decodeMonoPcm16;
import '../engine/incienso_synthesis_state.dart';
import '../engine/neom_breath_engine.dart';
import '../engine/neom_frequency_painter_engine.dart';
import '../engine/neom_modulator_engine.dart';
import '../engine/neom_sine_engine.dart';
import '../engine/visual_frame_timing.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/enums/neom_frequency_target.dart';
import '../utils/enums/neom_numeric_target.dart';
import '../utils/enums/neom_spatial_mode.dart';
import '../utils/enums/neom_visual_mode.dart';
import 'widgets/incienso_review_modal.dart';

class _PracticeLibrary {
  final List<String> favorites = [];
  final List<String> recent = [];
  final Map<String, Incienso> sessions = {};

  _PracticeLibrary();

  factory _PracticeLibrary.fromJson(Map<String, dynamic> value) {
    final library = _PracticeLibrary();
    library.favorites.addAll(
      (value['favorites'] as List? ?? []).whereType<String>().take(50),
    );
    library.recent.addAll(
      (value['recent'] as List? ?? []).whereType<String>().take(20),
    );
    for (final raw in (value['sessions'] as List? ?? []).take(70)) {
      try {
        final session = Incienso.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        library.sessions[session.id] = session;
      } catch (_) {
        /* One stale cache entry must not hide all shortcuts. */
      }
    }
    return library;
  }

  Map<String, dynamic> toJson() => {
    'favorites': List<String>.of(favorites),
    'recent': List<String>.of(recent),
    'sessions': sessions.values.map((s) => s.toJson()).toList(),
  };
}

class NeomGeneratorController extends SintController
    with WidgetsBindingObserver
    implements NeomGeneratorService {
  NeomGeneratorController({
    NeomSineEngine? sineEngine,
    ChamberRepository? chamberRepository,
    InciensoFirestore? inciensoFirestore,
    InciensoDraftStore? draftStore,
    InciensoRecorder? inciensoRecorder,
    NeomVoiceCapture? voiceCapture,
    ChamberPracticeStore? practiceStore,
    InciensoPortableFile? portableFile,
    NeomSineEngine? channelCheckEngine,
  }) : _sineEngine = sineEngine ?? NeomSineEngine(),
       chamberRepository = chamberRepository ?? ChamberFirestore(),
       _inciensoFirestore = inciensoFirestore ?? InciensoFirestore(),
       _draftStore = draftStore ?? InciensoDraftStore(),
       inciensoRecorder = inciensoRecorder ?? InciensoRecorder(),
       _voiceCapture = voiceCapture ?? createNeomVoiceCapture(),
       _practiceStore = practiceStore ?? ChamberPracticeStore(),
       _portableFile = portableFile ?? InciensoPortableFile(),
       _channelCheckEngine = channelCheckEngine,
       _usesVoiceAdapter = kIsWeb || voiceCapture != null;

  UserService? userServiceImpl;
  FrequencyService? frequencyServiceImpl;
  final ChamberRepository chamberRepository;

  final NeomSineEngine _sineEngine;
  final NeomFrequencyPainterEngine painterEngine = NeomFrequencyPainterEngine();

  final RxBool isIsochronicEnabled = false.obs;
  final RxDouble isochronicFreq = 4.0.obs; // Hz
  final RxDouble isochronicDuty = 0.5.obs;

  final RxBool isModulationEnabled = false.obs;

  final Rx<NeomModulationType> modulationType = NeomModulationType.none.obs;

  final RxDouble modulationFreq = 0.5.obs; // Hz
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
  final VisualFrameTiming _visualFrameTiming = VisualFrameTiming();
  bool _visualsResumed = false;
  final RxDouble wavePhase = 0.0.obs; // Controla el movimiento de la onda

  AppProfile? profile;
  NeomChamberPreset chamberPreset = NeomChamberPreset();

  RxBool isPlaying = false.obs;
  final RxBool playbackRequested = false.obs;
  final RxBool isPlaybackTransitioning = false.obs;
  final RxString playbackError = ''.obs;
  final RxString recordingSaveError = ''.obs;
  int _playbackRequest = 0;
  int _loadRequest = 0;
  bool _sessionPrepared = false;
  int _lastTrackedFrame = 0;
  int _lastBreathCycles = 0;
  InciensoPlayback? _playback;
  InciensoAudioState? _loadedInitialState;
  final List<Incienso> _pendingRecordings = [];
  final InciensoDraftStore _draftStore;
  bool _savingRecordings = false;
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
  final NeomVoiceCapture _voiceCapture;
  final bool _usesVoiceAdapter;
  Timer? _voiceTimer;
  int _voiceRequest = 0;
  bool _recorderOpened = false;
  bool _voiceStarting = false;
  bool _voiceStopping = false;
  bool _voicePlaybackReady = false;
  int _voicePlaybackRequest = 0;
  RxBool isRecording = false.obs;
  RxDouble detectedFrequency = 0.0.obs;
  StreamController<Uint8List>? _audioStreamController;
  final List<int> _accumulatedData = [];
  List<double> detectedPitches = [];

  bool _isDisposed = false;
  bool isAdmin = false;

  // Both capture paths deliver mono PCM16; web reports its actual context rate.
  double _captureSampleRate = NeomGeneratorConstants.sampleRate.toDouble();

  // ── Incienso tracking & recording ──
  final InciensoTracker inciensoTracker = InciensoTracker();
  final InciensoRecorder inciensoRecorder;
  final InciensoFirestore _inciensoFirestore;
  DateTime? _sessionStartedAt;
  String? _sessionCreatorId;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  Duration get sessionElapsed => Duration(
    microseconds:
        ((_hasSessionClock ? _sineEngine.playedFrames : 0) *
                1000000 /
                NeomGeneratorConstants.sampleRate)
            .round(),
  );

  /// The actively loaded incienso preset (null if free exploration).
  Incienso? _activeIncienso;
  Incienso? get activeIncienso => _activeIncienso;

  final RxInt freeSessionMinutes = 0.obs;
  final RxBool focusMode = false.obs;
  final RxBool softTransitions = true.obs;
  final RxList<String> favoriteSessionIds = <String>[].obs;
  final RxBool channelCheckRunning = false.obs;
  final RxBool canReflectSession = false.obs;
  final RxString reflectionBeforeFeeling = ''.obs;
  final ChamberPracticeStore _practiceStore;
  final InciensoPortableFile _portableFile;
  final Map<String, Future<_PracticeLibrary>> _practiceLibraries = {};
  Future<void> _practiceSaveTail = Future<void>.value();
  NeomSineEngine? _channelCheckEngine;
  int _channelCheckRequest = 0;
  InciensoAudioState? _sessionInitialState;
  InciensoPracticeDraft? _completedPractice;
  String? _reflectionOwner;
  String _sessionBeforeFeeling = '';
  bool _hasSessionClock = false;

  String get _practiceScope =>
      '${AppProperties.getAppName()}:${userServiceImpl?.profile.id ?? ''}';

  Duration? get sessionRemaining {
    final total = _hasSessionClock
        ? _sineEngine.frameLimit
        : (_activeIncienso != null
              ? (_activeIncienso!.effectiveDuration.inMicroseconds *
                        44100 /
                        1000000)
                    .round()
              : (freeSessionMinutes.value > 0
                    ? freeSessionMinutes.value * 60 * 44100
                    : null));
    if (total == null) return null;
    final frames = max(
      0,
      total - (_hasSessionClock ? _sineEngine.playedFrames : 0),
    );
    return Duration(microseconds: (frames * 1000000 / 44100).round());
  }

  void setFreeSessionMinutes(int minutes) {
    if (playbackRequested.value || channelCheckRunning.value) return;
    if ([0, 5, 10, 20, 30, 60].contains(minutes)) {
      freeSessionMinutes.value = minutes;
      _hasSessionClock = false;
    }
  }

  void setFocusMode(bool enabled) => focusMode.value = enabled;
  void setSoftTransitions(bool enabled) {
    if (!playbackRequested.value) softTransitions.value = enabled;
  }

  Future<void> startFreeSession() async {
    final request = ++_loadRequest;
    await _playStopPreview(stop: true);
    if (_isDisposed || request != _loadRequest) return;
    _activeIncienso = null;
    _playback = null;
    _loadedInitialState = null;
    _hasSessionClock = false;
    _sessionInitialState = _captureAudioState();
    update([AppPageIdConstants.generator]);
  }

  Future<void> resetSessionSettings() async {
    final request = ++_loadRequest;
    await _playStopPreview(stop: true);
    if (_isDisposed || request != _loadRequest) return;
    final baseline = _loadedInitialState ?? _sessionInitialState;
    _applyRecordedState(
      baseline ??
          InciensoAudioState(
            parameters: const {'carrierHz': 432, 'volume': .5},
          ),
    );
    _hasSessionClock = false;
    update([AppPageIdConstants.generator]);
  }

  Future<_PracticeLibrary> _practiceLibrary(
    String scope,
  ) => _practiceLibraries.putIfAbsent(scope, () async {
    try {
      final library = _PracticeLibrary.fromJson(
        await _practiceStore.load(scope),
      );
      if (!_isDisposed && scope == _practiceScope) {
        favoriteSessionIds.assignAll(library.favorites);
      }
      return library;
    } catch (e, st) {
      _practiceStorageError(e, st);
      return _PracticeLibrary(); // Memory still works if device storage fails.
    }
  });

  void _practiceStorageError(Object error, StackTrace stack) {
    if (!_isDisposed) {
      recordingSaveError.value =
          GeneratorTranslationConstants.recordingSaveFailed.tr;
    }
    NeomErrorLogger.recordError(
      error,
      stack,
      module: 'neom_generator',
      operation: 'practiceLibrary',
    );
  }

  Future<void> _savePracticeLibrary(String scope, _PracticeLibrary library) {
    final snapshot = library.toJson();
    final save = _practiceSaveTail.then(
      (_) => _practiceStore.save(scope, snapshot),
    );
    _practiceSaveTail = save.catchError(
      (Object e, StackTrace st) => _practiceStorageError(e, st),
    );
    return _practiceSaveTail;
  }

  Future<void> _rememberIncienso(Incienso session, String scope) async {
    final library = await _practiceLibrary(scope);
    library.sessions[session.id] = session;
    library.recent.remove(session.id);
    library.recent.insert(0, session.id);
    if (library.recent.length > 20) {
      library.recent.removeRange(20, library.recent.length);
    }
    library.sessions.removeWhere(
      (id, _) =>
          !library.recent.contains(id) && !library.favorites.contains(id),
    );
    await _savePracticeLibrary(scope, library);
  }

  bool isFavorite(String id) => favoriteSessionIds.contains(id);

  Future<void> toggleFavorite(String id) async {
    final scope = _practiceScope;
    final library = await _practiceLibrary(scope);
    if (library.favorites.contains(id)) {
      library.favorites.remove(id);
    } else {
      Incienso? session = library.sessions[id];
      if (_activeIncienso?.id == id) session = _activeIncienso;
      session ??= (await recordedSessions())
          .where((s) => s.id == id)
          .firstOrNull;
      if (session == null || scope != _practiceScope) return;
      library.sessions[id] = session;
      if (library.favorites.length >= 50) library.favorites.removeAt(0);
      library.favorites.add(id);
    }
    if (!_isDisposed && scope == _practiceScope) {
      favoriteSessionIds.assignAll(library.favorites);
    }
    await _savePracticeLibrary(scope, library);
  }

  Future<List<Incienso>> quickSessions() async {
    final scope = _practiceScope;
    final library = await _practiceLibrary(scope);
    if (scope != _practiceScope || _isDisposed) return [];
    favoriteSessionIds.assignAll(library.favorites);
    return [
      for (final id in {...library.favorites.reversed, ...library.recent})
        if (library.sessions[id] != null) library.sessions[id]!,
    ];
  }

  Future<void> stopChannelCheck() async {
    ++_channelCheckRequest;
    channelCheckRunning.value = false;
    try {
      await _channelCheckEngine?.stop();
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'stopChannelCheck',
      );
    }
  }

  Future<void> playChannelCheck(bool left) async {
    if (_isDisposed ||
        isRecording.value ||
        playbackRequested.value ||
        isPlaybackTransitioning.value) {
      return;
    }
    final request = ++_channelCheckRequest;
    playbackError.value = '';
    final engine = _channelCheckEngine ??= NeomSineEngine.isolated();
    // Interrupt the previous channel before resetting it; a rapid L/R click
    // must start a fresh one-second check, not reuse the previous clock.
    final stopped = engine.stop().catchError((Object e, StackTrace st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'restartChannelCheck',
      );
    });
    channelCheckRunning.value = true;
    engine.onPlaybackComplete = () {
      if (!_isDisposed && request == _channelCheckRequest) {
        channelCheckRunning.value = false;
      }
    };
    engine.onError = (e, st) {
      if (!_isDisposed && request == _channelCheckRequest) {
        channelCheckRunning.value = false;
        playbackError.value =
            GeneratorTranslationConstants.practiceChannelCheckFailed.tr;
      }
    };
    engine.applyAudioState(InciensoAudioState(parameters: const {}));
    engine.multiFrequencyMode = true;
    engine.frequencyL = left ? 440 : 0;
    engine.frequencyR = left ? 0 : 440;
    engine.frequencySub = 0;
    engine.subMixLevel = 0;
    engine.volume = .08;
    engine.fadeInSeconds = .08;
    engine.fadeOutSeconds = .12;
    engine.frameLimit = 44100;
    engine.fadeOutEndFrame = 44100;
    try {
      await engine.start(); // Preserve the web audio gesture, no earlier await.
      await stopped;
    } catch (e, st) {
      if (request == _channelCheckRequest && !_isDisposed) {
        channelCheckRunning.value = false;
        playbackError.value =
            GeneratorTranslationConstants.practiceChannelCheckFailed.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'channelCheck',
      );
    }
  }

  Future<void> importSession() async {
    final request = ++_loadRequest;
    playbackError.value = '';
    try {
      final bytes = await _portableFile.pick();
      if (bytes == null || _isDisposed || request != _loadRequest) return;
      final id = InciensoPortableFile.decode(bytes);
      await _openPublicIncienso(id, request: request);
    } catch (e, st) {
      if (!_isDisposed && request == _loadRequest) {
        playbackError.value =
            GeneratorTranslationConstants.practiceImportInvalid.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'importInciensoReference',
      );
    }
  }

  Future<void> _openPublicIncienso(String id, {int? request}) async {
    final load = request ?? ++_loadRequest;
    // Reuse strict ID validation; a file or blog post cannot inject a path.
    InciensoPortableFile.encode(id);
    final builtin = InciensoCatalog.free.where((s) => s.id == id).firstOrNull;
    final session = builtin ?? await _inciensoFirestore.retrieve(id);
    if (_isDisposed || load != _loadRequest) return;
    if (session == null || (builtin == null && !session.isPublic)) {
      playbackError.value =
          GeneratorTranslationConstants.practiceSharePublicOnly.tr;
      return;
    }
    if (!_isDisposed) await loadIncienso(session);
  }

  bool canShareIncienso(Incienso session) =>
      session.isPublic || InciensoCatalog.free.any((s) => s.id == session.id);

  Future<void> exportSession(Incienso session) async {
    playbackError.value = '';
    try {
      final builtin = InciensoCatalog.free
          .where((s) => s.id == session.id)
          .firstOrNull;
      final current =
          builtin ??
          (session.isPublic
              ? await _inciensoFirestore.retrieve(session.id)
              : null);
      if (_isDisposed) return;
      if (current == null || (builtin == null && !current.isPublic)) {
        playbackError.value =
            GeneratorTranslationConstants.practiceSharePublicOnly.tr;
        return;
      }
      await _portableFile.export(current.id);
    } catch (e, st) {
      if (!_isDisposed) {
        playbackError.value =
            GeneratorTranslationConstants.practiceExportFailed.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'exportInciensoReference',
      );
    }
  }

  Future<void> openSessionReflection() async {
    final draft = _completedPractice;
    if (draft == null || _reflectionOwner != _practiceScope) {
      canReflectSession.value = false;
      return;
    }
    await Sint.toNamed(AppRouteConstants.blogEditor, arguments: [draft]);
  }

  @override
  void onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _visualsResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    painterEngine.frameDrivenVisuals = true;
    painterEngine.visualUpdatesEnabled = _visualsResumed;
    if (!Sint.isRegistered<NeomAudioVisualSignal>()) {
      Sint.put<NeomAudioVisualSignal>(painterEngine, permanent: true);
    }
    _sineEngine.painterEngine = painterEngine;
    _sineEngine.beforeBuffer = _beforeAudioBuffer;
    _sineEngine.afterBuffer = _afterAudioBuffer;
    _sineEngine.onPlayingChanged = (playing) {
      if (!_isDisposed) isPlaying.value = playing;
    };
    _sineEngine.onPlaybackComplete = () {
      _finishAudioSession(endFrame: _sineEngine.generatedFrames);
      playbackRequested.value = false;
      isPlaying.value = false;
      isPlaybackTransitioning.value = false;
    };
    _sineEngine.onError = (error, stack) {
      _finishAudioSession(endFrame: _sineEngine.playedFrames);
      playbackRequested.value = false;
      isPlaying.value = false;
      playbackError.value = GeneratorTranslationConstants.playbackFailed.tr;
      NeomErrorLogger.recordError(
        error,
        stack,
        module: 'neom_generator',
        operation: 'audioOutput',
      );
    };
    try {
      if (Sint.isRegistered<UserService>()) {
        userServiceImpl = Sint.find<UserService>();
      }
      if (Sint.isRegistered<FrequencyService>()) {
        frequencyServiceImpl = Sint.find<FrequencyService>();
      }

      profile = userServiceImpl?.profile;
      isAdmin =
          (userServiceImpl?.user.userRole.value ?? UserRole.subscriber.value) <=
          UserRole.admin.value;
      chambers.value = profile?.chambers ?? {};

      chamberPreset.mainFrequency ??= NeomFrequency();
      chamberPreset.neomParameter ??= NeomParameter();
      // Inicializar valores locales desde el preset
      currentFreq.value =
          chamberPreset.mainFrequency?.frequency ??
          NeomGeneratorConstants.defaultFrequency;
      currentVol.value = chamberPreset.neomParameter?.volume ?? 0.5;

      // Ahora verificamos directamente la propiedad binauralFrequency
      if (chamberPreset.binauralFrequency != null) {
        double bFreq = chamberPreset.binauralFrequency!.frequency;
        currentBeat.value = (bFreq - currentFreq.value).abs();
      } else {
        currentBeat.value = 0;
      }

      // Audio is activated by a gesture; microphone permission is requested
      // only when voice detection is explicitly selected.

      // Inicializar Ticker para animación
      _waveTicker = Ticker((elapsed) {
        if (!isPlaying.value) return;

        final frame = _visualFrameTiming.advance(
          elapsed,
          visualEnabled: _visualsResumed,
        );
        final visualDt = frame.visualDeltaSeconds;
        if (visualDt != null) {
          wavePhase.value =
              (wavePhase.value + visualDt * currentFreq.value * 0.02) %
              (2 * pi);

          painterEngine.updateFromAudio(
            phase: wavePhase.value,
            amplitude: currentVol.value,
            pan: posX.value,
            breath: breathDepth.value,
            modulation: modulationDepth.value,
            neuro: neuroState.value.index / NeomNeuroState.values.length,
            frequency: currentFreq.value,
            isVisualFrame: true,
          );
        }

        // Session capture and replay are driven by audio buffers, never UI.
      });
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'onInit',
      );
    }
  }

  @override
  void onReady() async {
    super.onReady();
    try {
      if (chambers.isEmpty) {
        noChambers = true;
      } else {
        existsInChamber.value = frequencyAlreadyInItemlist();
        if (chamber.value.id.isEmpty) {
          chamber.value = chambers.values.first;
        }
      }

      frequencyDescription.value = chamberPreset.description.isNotEmpty
          ? chamberPreset.description
          : chamberPreset.mainFrequency?.description ?? '';
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'onReady',
      );
    }

    isLoading.value = false;
    update([AppPageIdConstants.generator]);
    unawaited(_restoreRecordedDrafts());
    unawaited(_practiceLibrary(_practiceScope));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visualsResumed = state == AppLifecycleState.resumed;
    painterEngine.visualUpdatesEnabled = _visualsResumed;
    _visualFrameTiming.resetVisual();
    // Audio clock is independent; visual suspension cannot alter recordings.
  }

  @override
  void onClose() {
    ++_playbackRequest;
    ++_loadRequest;
    final stopping = _sineEngine.stop();
    _finishAudioSession(endFrame: _sineEngine.playedFrames);
    unawaited(
      stopping.catchError((Object e, StackTrace st) {
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_generator',
          operation: 'closeChamber',
        );
      }),
    );
    _isDisposed = true;
    ++_channelCheckRequest;
    unawaited(
      _channelCheckEngine?.dispose().catchError((Object e, StackTrace st) {
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_generator',
          operation: 'disposeChannelCheck',
        );
      }),
    );
    _voiceRequest++;
    _voiceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    painterEngine.visualUpdatesEnabled = false;
    if (Sint.isRegistered<NeomAudioVisualSignal>() &&
        identical(Sint.find<NeomAudioVisualSignal>(), painterEngine)) {
      Sint.delete<NeomAudioVisualSignal>(force: true);
    }
    if (_waveTicker?.isActive ?? false) _waveTicker?.stop();
    _waveTicker?.dispose();

    if (_recorderOpened) unawaited(_recorder.closeRecorder());
    unawaited(_voiceCapture.dispose());
    // The engine singleton stays reusable. Navigation keeps this controller
    // alive; actual controller teardown stops its output and pending work.

    _audioStreamController?.close();

    _sineEngine.beforeBuffer = null;
    _sineEngine.afterBuffer = null;
    if (identical(_sineEngine.painterEngine, painterEngine)) {
      _sineEngine.painterEngine = null;
    }
    _sineEngine.onPlayingChanged = null;
    _sineEngine.onPlaybackComplete = null;
    _sineEngine.onError = null;
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
    if (existsInChamber.value) isUpdate.value = true;
  }

  Future<void> playStopPreview({bool stop = false}) {
    // Detect owns the microphone until shutdown completes. A second Play
    // gesture must not route speaker audio back into the measurement.
    if (!stop && (_voiceStarting || _voiceStopping || isRecording.value)) {
      return Future<void>.value();
    }
    if (stop) ++_loadRequest; // Stop cancels pending selection/autostart, too.
    return _playStopPreview(stop: stop);
  }

  Future<void> _playStopPreview({bool stop = false}) async {
    if (_isDisposed) return;
    // Cancel the separate output synchronously, retaining the Play gesture.
    unawaited(stopChannelCheck());
    final requested = !stop && !playbackRequested.value;
    playbackRequested.value = requested;
    isPlaybackTransitioning.value = true;
    playbackError.value = '';
    final request = ++_playbackRequest;
    try {
      if (!requested) {
        final stopping = _sineEngine.stop();
        _finishAudioSession(endFrame: _sineEngine.playedFrames);
        await stopping;
      } else {
        ++_loadRequest; // Explicit Play supersedes pending navigation/reset.
        if (_loadedInitialState != null) {
          _applyRecordedState(_loadedInitialState!);
        }
        _playback?.reset();
        _syncParams();
        _sineEngine.frameLimit = _activeIncienso == null
            ? (freeSessionMinutes.value > 0
                  ? freeSessionMinutes.value * 60 * 44100
                  : null)
            : (_activeIncienso!.effectiveDuration.inMicroseconds *
                      NeomGeneratorConstants.sampleRate /
                      1000000)
                  .round();
        // Recorded sessions retain their original envelope, even if the
        // listener selected different defaults for NEW practices.
        if (!(_activeIncienso?.isRecorded ?? false)) {
          _sineEngine.fadeInSeconds = softTransitions.value ? 2 : 0;
          _sineEngine.fadeOutSeconds = softTransitions.value ? 5 : 0;
          _sineEngine.fadeOutEndFrame = softTransitions.value
              ? _sineEngine.frameLimit
              : null;
        }
        _sessionInitialState = _captureAudioState();
        _sessionPrepared = true;
        _hasSessionClock = true;
        _sessionStartedAt = DateTime.now();
        _sessionCreatorId = userServiceImpl?.profile.id;
        _sessionBeforeFeeling = switch (reflectionBeforeFeeling.value) {
          'neutral' => GeneratorTranslationConstants.practiceFeelingNeutral.tr,
          'calm' => GeneratorTranslationConstants.practiceFeelingCalm.tr,
          'tense' => GeneratorTranslationConstants.practiceFeelingTense.tr,
          'tired' => GeneratorTranslationConstants.practiceFeelingTired.tr,
          'energized' =>
            GeneratorTranslationConstants.practiceFeelingEnergized.tr,
          _ => '',
        };
        _lastTrackedFrame = 0;
        _lastBreathCycles = _sineEngine.breathEngine.completedCycles;
        inciensoTracker.start();
        inciensoTracker.onStateChanged(neuroState.value);
        inciensoRecorder.startRecording(
          initialState: _captureAudioState(),
          audioClock: true,
        );
        // No await before start: browsers require activation in this gesture.
        await _sineEngine.start();
        if (_isDisposed ||
            request != _playbackRequest ||
            !playbackRequested.value) {
          return;
        }
        if (!_sineEngine.isPlaying) throw StateError('Audio did not start');
        NeomStopwatch().start(ref: chamberPreset.id);
        if (!(_waveTicker?.isActive ?? false)) {
          _visualFrameTiming.reset();
          _waveTicker?.start();
        }
      }
    } catch (e, st) {
      if (!_isDisposed && request == _playbackRequest) {
        _finishAudioSession(endFrame: _sineEngine.playedFrames);
        playbackRequested.value = false;
        playbackError.value = GeneratorTranslationConstants.playbackFailed.tr;
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_generator',
          operation: 'playStopPreview',
        );
      }
    } finally {
      if (request == _playbackRequest && !_isDisposed) {
        isPlaying.value = _sineEngine.isPlaying;
        isPlaybackTransitioning.value = false;
        update([AppPageIdConstants.generator, 'miniNeomPlayer']);
      }
    }
  }

  InciensoAudioState _captureAudioState() => _sineEngine.captureAudioState(
    baseHz: currentFreq.value,
    octave: currentOctave.value,
    neuroState: neuroState.value.name,
    visualMode: visualMode.value.name,
    visualExperience: _activeIncienso?.defaultVisual?.name,
  );

  void _beforeAudioBuffer(int frame) {
    if (!_sessionPrepared || _isDisposed) return;
    final active = _activeIncienso;
    if (_playback != null) {
      _playback!.applyAt(
        frame,
        applyState: _applyRecordedState,
        applyLegacy: _applyLegacyFrame,
      );
    } else if (active != null && active.phases.isNotEmpty) {
      final seconds = frame / NeomGeneratorConstants.sampleRate;
      final phase = active.phases.lastWhere(
        (p) => p.startAt.inMicroseconds / 1000000 <= seconds,
        orElse: () => active.phases.first,
      );
      final duration = phase.duration.inMicroseconds / 1000000;
      final progress = duration <= 0
          ? 1.0
          : ((seconds - phase.startAt.inMicroseconds / 1000000) / duration)
                .clamp(0.0, 1.0);
      setBinauralBeat(
        beat:
            phase.startBeatHz +
            (phase.endBeatHz - phase.startBeatHz) * progress,
      );
    }
    inciensoRecorder.captureAudioFrame(
      _captureAudioState(),
      frame,
      coherence: painterEngine.hemisphericCoherence,
      breathPhase: _sineEngine.breathEngine.currentValue,
    );
  }

  void _afterAudioBuffer(int frame) {
    if (!_sessionPrepared || _isDisposed) return;
    inciensoRecorder.advanceAudioClock(frame);
    final breath = _sineEngine.breathEngine;
    final cycles = breath.completedCycles;
    if (cycles < _lastBreathCycles) _lastBreathCycles = cycles;
    while (_lastBreathCycles < cycles) {
      inciensoTracker.onBreathCycle(
        coherence: painterEngine.hemisphericCoherence,
      );
      _lastBreathCycles++;
    }
    if (frame - _lastTrackedFrame >= NeomGeneratorConstants.sampleRate) {
      inciensoTracker.onCoherenceReading(painterEngine.hemisphericCoherence);
      _lastTrackedFrame = frame;
    }
  }

  void _finishAudioSession({required int endFrame}) {
    if (!_sessionPrepared) return;
    _sessionPrepared = false;
    NeomStopwatch().pause(ref: chamberPreset.id);
    if (_waveTicker?.isActive ?? false) _waveTicker?.stop();
    inciensoTracker.stop();
    final ownerScope =
        '${AppProperties.getAppName()}:${_sessionCreatorId ?? ''}';
    if (endFrame >= 44100) {
      _completedPractice = InciensoPracticeDraft(
        sessionId:
            'practice_${_sessionStartedAt?.microsecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}',
        inciensoName:
            _activeIncienso?.getName(Sint.locale?.languageCode ?? 'es') ??
            _autoSessionName(),
        publicInciensoId:
            (_activeIncienso != null && canShareIncienso(_activeIncienso!))
            ? _activeIncienso!.id
            : '',
        feelingBefore: _sessionBeforeFeeling,
      );
      _reflectionOwner = ownerScope;
      if (!_isDisposed) canReflectSession.value = ownerScope == _practiceScope;
    }
    if (_activeIncienso?.isRecorded ?? false) {
      inciensoRecorder.cancel();
    } else {
      // Detach the immutable recording before any async persistence. An old
      // save must never cancel or mutate the next session's recorder.
      final recording = inciensoRecorder.stopAndBuild(
        name: _autoSessionName(),
        creatorId: _sessionCreatorId,
        endFrame: endFrame,
      );
      inciensoRecorder.cancel();
      if (recording != null) {
        _pendingRecordings.add(recording);
        unawaited(_retainRecording(recording));
        unawaited(_rememberIncienso(recording, ownerScope));
      }
    }
  }

  /// Effective frequency sent to the audio engine (base * 2^octave).
  /// Positive octaves multiply (2x, 4x, 8x, 16x).
  /// Negative octaves divide (/2, /4, /8, /16).
  double get effectiveFrequency {
    final oct = currentOctave.value;
    if (oct >= 0) {
      return (currentFreq.value * (1 << oct)).clamp(0, 22000);
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
    _sineEngine.beat = clampedBeat;

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

  // --- MULTI-FREQUENCY (Levitation) ---

  /// Load frequencies from a Map (sent by levitation or other modules).
  ///
  /// Supported keys:
  ///   'frequency' → main / sub frequency
  ///   'frequencyL' → left channel frequency
  ///   'frequencyR' → right channel frequency
  ///   'mode' → 'multi' enables 3-oscillator mode
  void _loadFromMapArguments(Map<String, dynamic> args) {
    final freq = (args['frequency'] as num?)?.toDouble();
    final freqL = (args['frequencyL'] as num?)?.toDouble();
    final freqR = (args['frequencyR'] as num?)?.toDouble();
    final mode = args['mode'] as String?;

    if (mode == 'multi' && freq != null && freqL != null && freqR != null) {
      // Multi-frequency: Sub + L + R
      _sineEngine.multiFrequencyMode = true;
      _sineEngine.frequencySub = freq;
      _sineEngine.frequencyL = freqL;
      _sineEngine.frequencyR = freqR;
      currentFreq.value = freq;
    } else if (freq != null) {
      // Single frequency from levitation
      chamberPreset.mainFrequency ??= NeomFrequency();
      chamberPreset.mainFrequency!.frequency = freq;
      currentFreq.value = freq;
    }
  }

  /// Update the main frequency directly (for controller-to-controller calls).
  ///
  /// Used by levitation's playFrequency() when the generator is already running.
  void updateFrequency(double freq) {
    if (_sineEngine.multiFrequencyMode) {
      _sineEngine.frequencySub = freq;
    } else {
      currentFreq.value = freq;
      _applyEffectiveFrequency();
    }
  }

  /// Set multi-frequency mode with 3 independent oscillators.
  ///
  /// [subHz]: frequency for subwoofer (mixed to both L+R channels)
  /// [leftHz]: frequency for left speaker only
  /// [rightHz]: frequency for right speaker only
  void setMultiFrequency({
    required double subHz,
    required double leftHz,
    required double rightHz,
  }) {
    _sineEngine.multiFrequencyMode = true;
    _sineEngine.frequencySub = subHz;
    _sineEngine.frequencyL = leftHz;
    _sineEngine.frequencyR = rightHz;
    currentFreq.value = subHz;
    update([AppPageIdConstants.generator]);
  }

  /// Disable multi-frequency mode and return to standard binaural.
  void disableMultiFrequency() {
    _sineEngine.multiFrequencyMode = false;
    _applyEffectiveFrequency();
    update([AppPageIdConstants.generator]);
  }

  // --- HELPERS ---
  void updateDescriptionForFrequency(double frequency) {
    frequencyDescription.value = "";
    if (frequencyServiceImpl != null) {
      for (NeomFrequency neomFreq in frequencyServiceImpl!.frequencies.values) {
        if (neomFreq.frequency.ceilToDouble() == frequency.ceilToDouble()) {
          frequencyDescription.value = neomFreq.description;
          break;
        }
      }
    }
  }

  void setFrequencyState(AppItemState newState) {
    AppConfig.logger.d("Setting new appItem $newState");
    frequencyState.value = newState.value;
    chamberPreset.state = newState.value;
    update([AppPageIdConstants.generator]);
  }

  void setSelectedItemlist(String selectedItemlist) {
    AppConfig.logger.d("Setting selectedItemlist $selectedItemlist");
    chamber.value.id = selectedItemlist;
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

  Future<void> addPreset(
    BuildContext context, {
    int frequencyPracticeState = 0,
  }) async {
    if (!isButtonDisabled.value) {
      isButtonDisabled.value = true;
      isLoading.value = true;
      update([AppPageIdConstants.generator]);

      AppConfig.logger.i(
        "ChamberPreset would be added as $frequencyState for Itemlist ${chamber.value.id}",
      );

      if (frequencyPracticeState > 0) {
        frequencyState.value = frequencyPracticeState;
      }

      if (noChambers) {
        chamber.value.name = CommonTranslationConstants.myFavItemlistName.tr;
        chamber.value.description =
            CommonTranslationConstants.myFavItemlistDesc.tr;
        chamber.value.imgUrl = AppProperties.getAppLogoUrl();
        chamber.value.ownerId = profile?.id ?? '';
        chamber.value.id = await chamberRepository.insert(chamber.value);
      } else {
        if (chamber.value.id.isEmpty) {
          chamber.value.id = chambers.values.first.id;
        }
      }

      if (chamber.value.id.isNotEmpty) {
        try {
          chamberPreset.id =
              "${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()}_${chamberPreset.neomParameter!.volume.toString()}"
              "_${chamberPreset.neomParameter!.x.toString()}_${chamberPreset.neomParameter!.y.toString()}_${chamberPreset.neomParameter!.z.toString()}";
          chamberPreset.name =
              "${AppTranslationConstants.frequency.tr} ${chamberPreset.mainFrequency?.frequency.ceilToDouble().toString()} Hz";
          chamberPreset.imgUrl = AppProperties.getAppLogoUrl();
          chamberPreset.ownerId = profile?.id ?? '';
          chamberPreset.mainFrequency!.description = frequencyDescription.value;
          if (await chamberRepository.addPreset(
            chamber.value.id,
            chamberPreset,
          )) {
            await ProfileFirestore().addChamberPreset(
              profileId: profile?.id ?? '',
              chamberPresetId: chamberPreset.id,
            );
            await userServiceImpl?.reloadProfileItemlists();
            await userServiceImpl?.loadProfileChambers();
            userServiceImpl?.profile.chamberPresets?.add(chamberPreset.id);
            AppConfig.logger.d("Preset added to Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not added to Neom NeomChamber");
          }
        } catch (e, st) {
          NeomErrorLogger.recordError(
            e,
            st,
            module: 'neom_generator',
            operation: 'addPreset',
          );
          AppUtilities.showSnackBar(
            title: AppTranslationConstants.generator.tr,
            message: GeneratorTranslationConstants.presetAddError.tr,
          );
        }

        AppUtilities.showSnackBar(
          title: AppTranslationConstants.generator.tr,
          message:
              '${GeneratorTranslationConstants.presetAddedMsg.tr}'
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
    if (!isButtonDisabled.value) {
      isButtonDisabled.value = true;
      isLoading.value = true;
      update([AppPageIdConstants.generator]);

      AppConfig.logger.i(
        "ChamberPreset would be removed for Itemlist ${chamber.value.id}",
      );

      if (chamber.value.id.isEmpty) chamber.value.id = chambers.values.first.id;

      if (chamber.value.id.isNotEmpty) {
        try {
          if (await chamberRepository.deletePreset(
            chamber.value.id,
            chamberPreset,
          )) {
            await userServiceImpl?.reloadProfileItemlists();
            chambers.value = userServiceImpl?.profile.chambers ?? {};
            AppConfig.logger.d("Preset removed from Neom NeomChamber");
          } else {
            AppConfig.logger.d("Preset not removed from Neom NeomChamber");
          }
        } catch (e, st) {
          NeomErrorLogger.recordError(
            e,
            st,
            module: 'neom_generator',
            operation: 'removePreset',
          );
          AppUtilities.showSnackBar(
            title: GeneratorTranslationConstants.neomChamber.tr,
            message: GeneratorTranslationConstants.presetRemoveError.tr,
          );
        }

        AppUtilities.showSnackBar(
          title: GeneratorTranslationConstants.neomChamber.tr,
          message:
              '${GeneratorTranslationConstants.presetRemovedMsg.tr}'
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
  void setParameterPosition({
    required double x,
    required double y,
    required double z,
  }) {
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
    if (existsInChamber.value) isUpdate.value = true;
    // update(); // No necesario si usamos Obx en UI para sliders
  }

  Future<void> increaseFrequency({double step = 1}) async {
    double newFreq = currentFreq.value + step;
    await setFrequency(newFreq);
  }

  Future<void> decreaseFrequency({double step = 1}) async {
    double newFreq = currentFreq.value - step;
    if (newFreq > 0) await setFrequency(newFreq);
  }

  Future<void> increaseActiveValue({double step = 1}) async {
    switch (activeNumericTarget.value) {
      case NeomNumericTarget.rootFrequency:
        await increaseFrequency(step: step);
        break;

      case NeomNumericTarget.binauralBeat:
        setBinauralBeat(beat: currentBeat.value + step);
        break;
    }
  }

  Future<void> decreaseActiveValue({double step = 1}) async {
    switch (activeNumericTarget.value) {
      case NeomNumericTarget.rootFrequency:
        await decreaseFrequency(step: step);
        break;

      case NeomNumericTarget.binauralBeat:
        setBinauralBeat(beat: currentBeat.value - step);
        break;
    }
  }

  RxBool longPressed = false.obs;
  RxInt timerDuration = NeomGeneratorConstants.recursiveCallTimerDuration.obs;

  void increaseOnLongPress() {
    if (longPressed.value) {
      if (timerDuration >
          NeomGeneratorConstants.recursiveCallTimerDurationMin) {
        timerDuration--;
      }
      increaseActiveValue();
      Timer(Duration(milliseconds: timerDuration.value), increaseOnLongPress);
    }
  }

  void decreaseOnLongPress() {
    if (longPressed.value) {
      if (timerDuration >
          NeomGeneratorConstants.recursiveCallTimerDurationMin) {
        timerDuration--;
      }
      decreaseActiveValue();
      Timer(Duration(milliseconds: timerDuration.value), decreaseOnLongPress);
    }
  }

  Future<void> initializeRecorder() async {
    if (_usesVoiceAdapter) return;
    if (!kIsWeb) {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw StateError('Microphone permission denied');
      }
    }
    if (!_recorderOpened) {
      await _recorder.openRecorder();
      _recorderOpened = true;
    }
  }

  void initializeStreamController() {
    _audioStreamController = StreamController<Uint8List>(sync: true);
    _audioStreamController!.stream.listen((audioData) async {
      if (_isDisposed || !isRecording.value) return;
      final voiceRequest = _voiceRequest;

      // Feed real-time waveform visualization
      _pushMicAmplitude(audioData);

      double freqPitch = await getPitchFromAudioData(audioData);
      if (_isDisposed || !isRecording.value || voiceRequest != _voiceRequest) {
        return;
      }
      if (freqPitch > NeomGeneratorConstants.frequencyMin &&
          freqPitch <
              (isAdmin
                  ? NeomGeneratorConstants.frequencyMax
                  : NeomGeneratorConstants.frequencyLimit)) {
        AppConfig.logger.d("Pitch: $freqPitch Hz");
        detectedFrequency.value = freqPitch;
        detectedPitches.add(freqPitch);
      }

      update([AppPageIdConstants.generator]);
    });
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
    if (_voiceStarting || _voiceStopping || isRecording.value || _isDisposed) {
      return;
    }
    final request = ++_voiceRequest;
    _voiceStarting = true;
    _voicePlaybackReady = false;
    isRecording.value = true; // Allows cancelling a pending permission prompt.
    playbackError.value = '';
    unawaited(stopChannelCheck());
    try {
      final stopAudio = playbackRequested.value || isPlaying.value
          ? playStopPreview(stop: true)
          : Future<void>.value();
      _voicePlaybackRequest = _playbackRequest;
      detectedFrequency.value = 0;
      detectedPitches.clear();
      micWaveform.clear();
      _captureSampleRate = NeomGeneratorConstants.sampleRate.toDouble();
      _accumulatedData.clear();
      if (_audioStreamController == null) initializeStreamController();
      // Both activations originate in Detect's gesture. Preparing output emits
      // no sound, and observes errors immediately while permission is pending.
      final Future<({Object? error, StackTrace? stack})> outputPreparation =
          _sineEngine.preparePlayback().then(
            (_) => (error: null, stack: null),
            onError: (Object error, StackTrace stack) =>
                (error: error, stack: stack),
          );
      if (_usesVoiceAdapter) {
        // Activate from this gesture, without awaiting shutdown/permission first.
        await _voiceCapture.start((pcm) {
          if (request != _voiceRequest || _isDisposed || !isRecording.value) {
            return;
          }
          _captureSampleRate = _voiceCapture.sampleRate.toDouble();
          if (_captureSampleRate > 0) _audioStreamController?.add(pcm);
        });
        await stopAudio;
      } else {
        await stopAudio;
        await initializeRecorder();
        if (request != _voiceRequest || _isDisposed) return;
        await _recorder.startRecorder(
          codec: Codec.pcm16,
          sampleRate: NeomGeneratorConstants.sampleRate,
          numChannels: 1,
          toStream: _audioStreamController?.sink,
        );
      }
      final output = await outputPreparation;
      if (output.error != null) {
        Error.throwWithStackTrace(output.error!, output.stack!);
      }
      if (request != _voiceRequest || _isDisposed) {
        if (_usesVoiceAdapter) {
          await _voiceCapture.stop();
        } else {
          await _recorder.stopRecorder();
        }
        return;
      }
      _voicePlaybackReady = true;
      _voiceTimer?.cancel();
      _voiceTimer = Timer(
        Duration(seconds: NeomGeneratorConstants.sampleDuration),
        () {
          if (request == _voiceRequest && !_isDisposed) {
            unawaited(stopRecording());
          }
        },
      );
    } catch (e, st) {
      if (request == _voiceRequest) {
        isRecording.value = false;
        _voicePlaybackReady = false;
        ++_voiceRequest;
        try {
          if (_usesVoiceAdapter) {
            await _voiceCapture.stop();
          } else if (_recorderOpened) {
            await _recorder.stopRecorder();
          }
        } catch (_) {
          // Keep the original startup error; never start output after failure.
        }
        playbackError.value = GeneratorTranslationConstants.microphoneFailed.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'startRecording',
      );
    } finally {
      _voiceStarting = false;
      if (!_isDisposed) update([AppPageIdConstants.generator]);
    }
  }

  Future<void> stopRecording({bool applyDetectedFrequency = true}) async {
    final request = ++_voiceRequest;
    final wasRecording = isRecording.value;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    isRecording.value = false;
    // Repeated Stop/Cancel invalidates the older completion without opening a
    // second teardown, or allowing a new capture to race the same microphone.
    if (_voiceStopping) return;
    _voiceStopping = true;
    final playbackRequest = _playbackRequest;
    try {
      if (_usesVoiceAdapter) {
        await _voiceCapture.stop();
      } else if (_recorderOpened) {
        await _recorder.stopRecorder();
      }
      if (!wasRecording ||
          !applyDetectedFrequency ||
          !_voicePlaybackReady ||
          _isDisposed ||
          request != _voiceRequest ||
          _voicePlaybackRequest != _playbackRequest ||
          playbackRequest != _playbackRequest) {
        return;
      }
      final frequency = getMostFrequentPitch();
      if (!frequency.isFinite ||
          frequency <= NeomGeneratorConstants.frequencyMin ||
          frequency >=
              (isAdmin
                  ? NeomGeneratorConstants.frequencyMax
                  : NeomGeneratorConstants.frequencyLimit)) {
        detectedFrequency.value = 0;
        return;
      }
      detectedFrequency.value = frequency;
      // Voice detection starts a new free practice. A loaded replay must not
      // overwrite the detected root at frame zero or at its next keyframe.
      ++_loadRequest;
      _activeIncienso = null;
      _playback = null;
      _loadedInitialState = null;
      _hasSessionClock = false;
      _sineEngine.multiFrequencyMode = false;
      currentOctave.value = 0;
      await setFrequency(frequency);
      if (_isDisposed ||
          request != _voiceRequest ||
          playbackRequest != _playbackRequest) {
        return;
      }
      // Capture has fully released the microphone before speakers can start.
      // Never toggle a newer user-started playback back off.
      if (!playbackRequested.value && !isPlaying.value) {
        await _playStopPreview();
      }
    } catch (e, st) {
      if (!_isDisposed && request == _voiceRequest) {
        playbackError.value = GeneratorTranslationConstants.microphoneFailed.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'stopRecording',
      );
    } finally {
      _voiceStopping = false;
      _voicePlaybackReady = false;
      if (!_isDisposed) update([AppPageIdConstants.generator]);
    }
  }

  Future<double> getPitchFromAudioData(Uint8List audioData) async {
    final voiceRequest = _voiceRequest;
    _accumulatedData.addAll(audioData);

    const int bytesPerSample = 2;
    double pitch = 0;
    int neededBytes = NeomGeneratorConstants.neededSamples * bytesPerSample;

    final double effectiveSampleRate = _captureSampleRate;

    while (voiceRequest == _voiceRequest &&
        _accumulatedData.length >= neededBytes) {
      final chunk = _accumulatedData.sublist(0, neededBytes);
      _accumulatedData.removeRange(0, neededBytes);

      final pitchDetectorDart = PitchDetector(
        audioSampleRate: effectiveSampleRate,
        bufferSize: NeomGeneratorConstants.neededSamples,
      );

      try {
        final chunkAsUint8List = Uint8List.fromList(chunk);

        PitchDetectorResult pitchResult = await pitchDetectorDart
            .getPitchFromFloatBuffer(decodeMonoPcm16(chunkAsUint8List));
        if (pitchResult.pitched && pitchResult.probability >= .9) {
          pitch = pitchResult.pitch.roundToDouble();
        }
      } catch (e, st) {
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_generator',
          operation: 'getPitchFromAudioData',
        );
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

    final mostFrequentEntry = frequencyMap.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

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

  final Rx<NeomSpatialMode> spatialMode = NeomSpatialMode.softPan.obs;

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

  final Rx<NeomBreathMode> breathMode = NeomBreathMode.off.obs;

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

  final Rx<NeomNeuroState> neuroState = NeomNeuroState.neutral.obs;

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
    _syncUiFromEngine();
  }

  void setVisualAmplitude(double v) {
    painterEngine.visualAmplitudeBase = v;
    painterEngine.notifyVisualUpdate();
  }

  final Rx<NeomVisualMode> visualMode = NeomVisualMode.scientific.obs;

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
    frequencyEditCtrl.text = currentFreq.value.toString();
    isEditingFrequency.value = true;
  }

  void finishEditFrequency() {
    setFrequencyFromText(frequencyEditCtrl.text);
    isEditingFrequency.value = false;
  }

  void setFrequencyFromText(String value) {
    if (value.isEmpty) return;

    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return;

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
    beatEditCtrl.text = currentBeat.value.toString();
    isEditingBeat.value = true;
  }

  void finishEditBeat() {
    final v = double.tryParse(beatEditCtrl.text.replaceAll(',', '.'));
    if (v != null && v.isFinite) {
      final clamped = v.clamp(
        -NeomGeneratorConstants.binauralBeatMax,
        NeomGeneratorConstants.binauralBeatMax,
      );
      setBinauralBeat(beat: clamped);
    }
    isEditingBeat.value = false;
  }

  final Rx<NeomFrequencyTarget> selectedTarget = NeomFrequencyTarget.root.obs;

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

  // ── Incienso loading ──

  /// Load an [Incienso] preset into the generator, configuring all parameters
  /// (frequencies, binaural beat, isochronic, visual, breathing) and optionally
  /// auto-starting playback.
  ///
  /// For multi-phase inciensos, starts a timer-driven phase runner that
  /// transitions between phases at the scheduled times.
  Future<void> loadIncienso(Incienso incienso, {bool autoStart = false}) async {
    final load = ++_loadRequest;
    try {
      final playback = incienso.isRecorded ? InciensoPlayback(incienso) : null;
      await _playStopPreview(stop: true);
      if (load != _loadRequest || _isDisposed) return;
      _activeIncienso = incienso;
      _hasSessionClock = false;
      _playback = playback;
      currentOctave.value = 0;
      // Deterministic defaults: never inherit another session's spatial,
      // multi-channel, breathing or modulation configuration.
      _sineEngine.applyAudioState(
        InciensoAudioState(
          parameters: {
            'carrierHz': incienso.leftFrequencyHz,
            'beatHz': incienso.rightFrequencyHz - incienso.leftFrequencyHz,
            'volume': incienso.timeline.isNotEmpty
                ? incienso.timeline.first.volume
                : .5,
          },
        ),
      );
      neuroState.value = NeomNeuroState.neutral;
      if (playback != null) {
        playback.applyAt(
          0,
          applyState: _applyRecordedState,
          applyLegacy: _applyLegacyFrame,
        );
      } else {
        setNeuroState(incienso.targetState);
        setIsochronicFrequency(
          incienso.pulseFrequencyHz > 0 ? incienso.pulseFrequencyHz : 4,
        );
        await setIsochronicEnabled(incienso.pulseFrequencyHz > 0);
        if (_isDisposed || load != _loadRequest) return;
        if (incienso.phases.isNotEmpty) {
          setBinauralBeat(beat: incienso.phases.first.startBeatHz);
        }
      }
      _syncUiFromEngine();
      currentFreq.value =
          incienso.timeline.firstOrNull?.audioState?.number(
            'baseHz',
            _sineEngine.frequency,
          ) ??
          _sineEngine.frequency;
      chamberPreset.mainFrequency ??= NeomFrequency();
      chamberPreset.mainFrequency!.frequency = currentFreq.value;
      _loadedInitialState = _captureAudioState();
      _sessionInitialState = _loadedInitialState;
      unawaited(_rememberIncienso(incienso, _practiceScope));
      if (autoStart) await playStopPreview();
      update([AppPageIdConstants.generator]);
    } catch (e, st) {
      if (!_isDisposed && load == _loadRequest) {
        playbackError.value = GeneratorTranslationConstants.playbackFailed.tr;
      }
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'loadIncienso',
      );
    }
  }

  void _applyRecordedState(InciensoAudioState state) {
    _sineEngine.applyAudioState(state);
    currentFreq.value = state.number('baseHz', _sineEngine.frequency);
    currentOctave.value = state.number('octave', 0).toInt().clamp(-4, 4);
    neuroState.value = NeomNeuroState.values.firstWhere(
      (v) => v.name == state.text('neuroState', 'neutral'),
      orElse: () => NeomNeuroState.neutral,
    );
    visualMode.value = NeomVisualMode.values.firstWhere(
      (v) => v.name == state.text('visualMode', 'scientific'),
      orElse: () => NeomVisualMode.scientific,
    );
    _syncUiFromEngine();
  }

  void _applyLegacyFrame(InciensoKeyframe frame) {
    _sineEngine.frequency = frame.leftHz.clamp(0, 22000);
    _sineEngine.beat = (frame.rightHz - frame.leftHz).clamp(-250, 250);
    _sineEngine.volume = frame.volume.clamp(0, 1);
    currentFreq.value = _sineEngine.frequency;
    currentOctave.value = 0;
    currentBeat.value = _sineEngine.beat;
    currentVol.value = _sineEngine.volume;
    neuroState.value = NeomNeuroState.values.firstWhere(
      (v) => v.name == frame.neuroState,
      orElse: () => NeomNeuroState.neutral,
    );
  }

  void _syncUiFromEngine() {
    currentBeat.value = _sineEngine.beat;
    currentVol.value = _sineEngine.volume;
    posX.value = _sineEngine.posX * NeomGeneratorConstants.positionMax;
    posY.value = _sineEngine.posY * NeomGeneratorConstants.positionMax;
    posZ.value = _sineEngine.posZ * NeomGeneratorConstants.positionMax;
    isIsochronicEnabled.value = _sineEngine.isochronic.enabled;
    isochronicFreq.value = _sineEngine.isochronic.pulseFrequency;
    isochronicDuty.value = _sineEngine.isochronic.dutyCycle;
    isModulationEnabled.value = _sineEngine.modulator.enabled;
    modulationType.value = _sineEngine.modulator.type;
    modulationFreq.value = _sineEngine.modulator.modFrequency;
    modulationDepth.value = _sineEngine.modulator.depth;
    spatialMode.value = _sineEngine.spatialMode;
    spatialIntensity.value = _sineEngine.spatialIntensity;
    orbitSpeed.value = _sineEngine.orbitSpeed;
    orbitDirection.value = _sineEngine.orbitDirection;
    breathMode.value = _sineEngine.breathEngine.mode;
    breathRate.value = _sineEngine.breathEngine.breathsPerMinute;
    breathDepth.value = _sineEngine.breathEngine.depth;
  }

  /// Called once for each generator route entry, not once per permanent
  /// controller lifetime. Selecting A then B must actually load B.
  Future<void> loadRouteArguments(Object? arguments) async {
    final value = arguments is List && arguments.isNotEmpty
        ? arguments.first
        : arguments;
    if (value is Incienso) {
      await loadIncienso(value, autoStart: false);
    } else if (value is InciensoPracticeReference && value.canOpen) {
      final request = ++_loadRequest;
      try {
        await _openPublicIncienso(value.publicInciensoId, request: request);
      } catch (e, st) {
        if (!_isDisposed && request == _loadRequest) {
          playbackError.value =
              GeneratorTranslationConstants.practiceImportFailed.tr;
        }
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_generator',
          operation: 'openPracticeReference',
        );
      }
    } else if (value is NeomChamberPreset ||
        value is NeomFrequency ||
        value is Map<String, dynamic>) {
      final request = ++_loadRequest;
      await _playStopPreview(stop: true);
      if (_isDisposed || request != _loadRequest) return;
      _activeIncienso = null;
      _hasSessionClock = false;
      _playback = null;
      _loadedInitialState = null;
      _sineEngine.applyAudioState(InciensoAudioState(parameters: const {}));
      currentOctave.value = 0;
      if (value is NeomChamberPreset) {
        chamberPreset = value.clone();
        _sineEngine.frequency = value.mainFrequency?.frequency ?? 432;
        _sineEngine.beat =
            (value.binauralFrequency?.frequency ?? _sineEngine.frequency) -
            _sineEngine.frequency;
        _sineEngine.volume = value.neomParameter?.volume ?? .5;
        _sineEngine.posX =
            (value.neomParameter?.x ?? 0) / NeomGeneratorConstants.positionMax;
        _sineEngine.posY =
            (value.neomParameter?.y ?? 0) / NeomGeneratorConstants.positionMax;
        _sineEngine.posZ =
            (value.neomParameter?.z ?? 0) / NeomGeneratorConstants.positionMax;
      } else if (value is NeomFrequency) {
        _sineEngine.frequency = value.frequency;
      } else {
        _loadFromMapArguments(value as Map<String, dynamic>);
        _sineEngine.frequency = currentFreq.value;
      }
      currentFreq.value = _sineEngine.frequency;
      _syncUiFromEngine();
      _sessionInitialState = _captureAudioState();
      update([AppPageIdConstants.generator]);
    }
  }

  // ── Visual experience navigation ──

  /// Navigate to the fullscreen visual experience matching the active incienso.
  /// Falls back to photonicPulse behavior (no navigation) if no visual is set.
  void launchVisualExperience() {
    final visual = _activeIncienso?.defaultVisual;
    if (visual == null) return;

    final route = _visualRoute(visual);
    if (route != null) {
      Sint.toNamed(route, arguments: painterEngine);
    }
  }

  String? _visualRoute(InciensoVisual visual) {
    switch (visual) {
      case InciensoVisual.flocking:
        return AppRouteConstants.flockingFullscreen;
      case InciensoVisual.breathing:
        return AppRouteConstants.breathingFullscreen;
      case InciensoVisual.fractals:
        return AppRouteConstants.fractalFullscreen;
      case InciensoVisual.neomatics:
        return AppRouteConstants.neomaticsFullscreen;
      case InciensoVisual.neuroMandala:
        return AppRouteConstants.neuromandalaFullscreen;
      case InciensoVisual.photonicPulse:
        return null; // Handled inline
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
      creatorId: _sessionCreatorId,
      endFrame: _sineEngine.playedFrames,
    );
  }

  /// Summary of the session that just ended, or null when there was nothing
  /// worth reviewing.
  ///
  /// The review modal needs a BuildContext, so the page asks for this after
  /// stopping rather than the controller pushing UI.
  InciensoSessionSummary? pendingSessionSummary() {
    if (inciensoTracker.inciensoCount <= 0) return null;
    return InciensoSessionSummary.fromSession(
      buildInciensoSession(
        inciensoId: _activeIncienso?.id ?? '',
        source: _activeIncienso?.source ?? InciensoSource.userCreated,
      ),
    );
  }

  /// Stores how the session felt. Silent on failure — a review is optional and
  /// must not interrupt the practice flow.
  Future<void> saveSessionReview(InciensoReview review) async {
    try {
      await _inciensoFirestore.insertReview(review);
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'saveSessionReview',
      );
    }
  }

  /// Keeps a private copy of the session the user just practised.
  ///
  /// Runs on every stop, so it stays silent unless there is something worth
  /// keeping: sessions under [InciensoRecorder.minDuration] or with too few
  /// keyframes are dropped by the recorder itself.
  ///
  /// Saved as private — the recording is the user's own practice. Sharing it
  /// with the community is a separate, explicit decision
  /// (`InciensoFirestore.setPublic`).
  ///
  /// Skipped while following someone else's recording: that session already
  /// exists, and re-saving it would fill the catalogue with copies attributed
  /// to whoever played it.
  int get pendingRecordingCount => _pendingRecordings.length;

  /// Private sessions plus recoverable local drafts. Guest drafts stay local
  /// and are never silently attributed to a subsequently signed-in account.
  Future<List<Incienso>> recordedSessions() async {
    final owner = userServiceImpl?.profile.id ?? '';
    bool visible(Incienso value) => owner.isEmpty
        ? (value.creatorId == null || value.creatorId!.isEmpty)
        : value.creatorId == owner;
    final sessions = <String, Incienso>{};
    if (owner.isNotEmpty) {
      for (final value in await _inciensoFirestore.fetchByCreator(owner)) {
        if (visible(value)) sessions[value.id] = value;
      }
    }
    for (final value in await _draftStore.load()) {
      if (visible(value)) sessions[value.id] = value;
    }
    for (final value in _pendingRecordings) {
      if (visible(value)) sessions[value.id] = value;
    }
    return sessions.values.toList().reversed.toList();
  }

  Future<void> _retainRecording(Incienso recording) async {
    try {
      await _draftStore.save(recording);
      await retryPendingRecordings();
    } catch (e, st) {
      recordingSaveError.value =
          GeneratorTranslationConstants.recordingSaveFailed.tr;
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'retainRecording',
      );
    }
  }

  Future<void> _restoreRecordedDrafts() async {
    try {
      for (final draft in await _draftStore.load()) {
        if (!_pendingRecordings.any((p) => p.id == draft.id)) {
          _pendingRecordings.add(draft);
        }
      }
      await retryPendingRecordings();
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'restoreRecordingDrafts',
      );
    }
  }

  Future<void> retryPendingRecordings() async {
    if (_savingRecordings) return;
    final owner = userServiceImpl?.profile.id ?? '';
    if (owner.isEmpty) {
      return; // Guests retain local drafts; never assign them to another account.
    }
    _savingRecordings = true;
    var failed = false;
    final attempted = <String>{};
    try {
      while (userServiceImpl?.profile.id == owner) {
        final recording = _pendingRecordings
            .where((r) => r.creatorId == owner && !attempted.contains(r.id))
            .firstOrNull;
        if (recording == null) break;
        attempted.add(recording.id);
        try {
          final id = await _inciensoFirestore.insert(recording);
          if (id.isEmpty) {
            failed = true;
            continue; // One invalid/oversized session must not block later ones.
          }
          await _draftStore.remove(recording.id);
          _pendingRecordings.removeWhere((r) => r.id == recording.id);
        } catch (e, st) {
          failed = true;
          NeomErrorLogger.recordError(
            e,
            st,
            module: 'neom_generator',
            operation: 'retryRecordingSave',
          );
        }
      }
      recordingSaveError.value = failed
          ? GeneratorTranslationConstants.recordingSaveFailed.tr
          : '';
    } finally {
      _savingRecordings = false;
    }
  }

  /// "Sesión grabada · 14/03 20:35" — enough to tell two apart in a list.
  String _autoSessionName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${GeneratorTranslationConstants.recordedSession.tr} · '
        '${two(now.day)}/${two(now.month)} ${two(now.hour)}:${two(now.minute)}';
  }

  /// Whether the session recorded so far is long enough to be saved.
  ///
  /// Mirrors the guard inside [InciensoRecorder.stopAndBuild] (30s and five
  /// keyframes), so the UI can offer saving only when it would succeed.
  bool get canSaveRecordedSession => inciensoRecorder.hasEnoughToBuild;

  /// Stores the recorded session so it can be practised again.
  ///
  /// [isPublic] decides whether the community can find it. It defaults to
  /// false: a recording captures how someone's own practice unfolded, and that
  /// stays theirs until they choose to share it.
  ///
  /// Returns null when the session was too short to be worth keeping.
  Future<Incienso?> publishRecordedIncienso(
    String name, {
    String? description,
    List<String> tags = const [],
    bool isPublic = false,
  }) async {
    final recorded = inciensoRecorder.stopAndBuild(
      name: name,
      description: description,
      creatorId: _sessionCreatorId,
      tags: tags,
      endFrame: _sineEngine.playedFrames,
    );
    if (recorded == null) return null;

    final incienso = recorded.copyWithVisibility(isPublic: isPublic);
    _pendingRecordings.add(incienso);
    await _retainRecording(incienso);
    return _pendingRecordings.any((r) => r.id == incienso.id) ? null : incienso;
  }
}

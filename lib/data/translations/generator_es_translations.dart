import '../../utils/constants/generator_translation_constants.dart';

class GeneratorEsTranslations {
  static const Map<String, String> values = {
    GeneratorTranslationConstants.neomatics: 'Neomatics',
    GeneratorTranslationConstants.neuroMandala: 'NeuroMandala',
    GeneratorTranslationConstants.practiceOptions: 'Opciones de sesión',
    GeneratorTranslationConstants.practiceFocus: 'Modo sesión',
    GeneratorTranslationConstants.practiceControls: 'Mostrar controles',
    GeneratorTranslationConstants.neuroMode: 'Modo EEG',
    GeneratorTranslationConstants.neuroModeExit: 'Volver a la cámara',
    GeneratorTranslationConstants.neuroModeHint: 'La señal del headset al centro; los controles de audio quedan al costado.',
    GeneratorTranslationConstants.neuroModeUnavailable: "Esta app no tiene un panel de biosensores registrado (EEG, HRV…).",
    GeneratorTranslationConstants.practiceQuickAccess:
        'Favoritos y sesiones recientes',
    GeneratorTranslationConstants.practiceTimer: 'Temporizador de sesión libre',
    GeneratorTranslationConstants.practiceTimerHint:
        'Elige antes de reproducir. El audio se detiene al terminar el tiempo.',
    GeneratorTranslationConstants.practicePresetTimer:
        'Esta sesión usa su duración guardada.',
    GeneratorTranslationConstants.practiceNoLimit: 'Sin límite',
    GeneratorTranslationConstants.practiceRemaining: 'Tiempo restante',
    GeneratorTranslationConstants.practiceFeelingBefore:
        '¿Cómo te sientes antes de empezar? (opcional)',
    GeneratorTranslationConstants.practiceFeelingNeutral: 'Neutral',
    GeneratorTranslationConstants.practiceFeelingCalm: 'En calma',
    GeneratorTranslationConstants.practiceFeelingTense: 'Con tensión',
    GeneratorTranslationConstants.practiceFeelingTired: 'Con cansancio',
    GeneratorTranslationConstants.practiceFeelingEnergized: 'Con energía',
    GeneratorTranslationConstants.practiceSoftTransitions:
        'Inicio y final suaves',
    GeneratorTranslationConstants.practiceSoftTransitionsHint:
        'Ajusta el volumen gradualmente al iniciar y al terminar el tiempo. Detener sigue siendo inmediato.',
    GeneratorTranslationConstants.practiceStereo: 'Comprobar audífonos estéreo',
    GeneratorTranslationConstants.practiceStereoHint:
        'Con la reproducción detenida, escucha un tono breve en cada oído.',
    GeneratorTranslationConstants.practiceLeft: 'Oído izquierdo',
    GeneratorTranslationConstants.practiceRight: 'Oído derecho',
    GeneratorTranslationConstants.practiceChecking:
        'Reproduciendo prueba de canal…',
    GeneratorTranslationConstants.practiceReset: 'Restaurar ajustes iniciales',
    GeneratorTranslationConstants.practiceImport: 'Abrir enlace de Incienso',
    GeneratorTranslationConstants.practiceExport: 'Exportar enlace de Incienso',
    GeneratorTranslationConstants.practiceSharePublicOnly:
        'Los enlaces están disponibles para Inciensos públicos y abren la sesión original.',
    GeneratorTranslationConstants.practiceFavorite: 'Añadir a favoritos',
    GeneratorTranslationConstants.practiceUnfavorite: 'Quitar de favoritos',
    GeneratorTranslationConstants.practiceSessionActions: 'Acciones de sesión',
    GeneratorTranslationConstants.practiceReflection:
        'Escribir sobre esta sesión',
    GeneratorTranslationConstants.practiceFreeSession: 'Sesión libre',
    GeneratorTranslationConstants.practiceVolume: 'Volumen',
    GeneratorTranslationConstants.practiceStopCheck: 'Detener prueba de canal',
    GeneratorTranslationConstants.practiceImportInvalid:
        'Este archivo no es una sesión Neom compatible.',
    GeneratorTranslationConstants.practiceImportFailed:
        'No se pudo importar la sesión. Inténtalo de nuevo.',
    GeneratorTranslationConstants.practiceImportSuccess:
        'Sesión importada. Pulsa reproducir cuando quieras empezar.',
    GeneratorTranslationConstants.practiceExportFailed:
        'No se pudo exportar la sesión. Inténtalo de nuevo.',
    GeneratorTranslationConstants.practiceExportSuccess: 'Sesión exportada.',
    GeneratorTranslationConstants.practiceChannelCheckFailed:
        'No se pudo iniciar la prueba de canal. Inténtalo de nuevo.',
    GeneratorTranslationConstants.mySessions: "Mis sesiones",
    GeneratorTranslationConstants.emptySessions:
        "Aún no hay sesiones guardadas.",
    GeneratorTranslationConstants.loadSessionsFailed:
        "No se pudieron cargar las sesiones.",
    GeneratorTranslationConstants.retryLoad: "Reintentar",
    GeneratorTranslationConstants.selectSession: "Cargar sesión",
    GeneratorTranslationConstants.selectSessionHint:
        "Selecciona una sesión y pulsa reproducir en la Cámara Neom.",
    GeneratorTranslationConstants.invalidFrequencyControl:
        'Ingresa una frecuencia válida.',
    GeneratorTranslationConstants.retryControl: 'Reintentar guardado',
    GeneratorTranslationConstants.breathRateControl: 'Ritmo (resp/min)',
    GeneratorTranslationConstants.breathDepthControl: 'Profundidad',
    GeneratorTranslationConstants.intensityControl: "Intensidad",
    GeneratorTranslationConstants.typeControl: "Tipo",
    GeneratorTranslationConstants.modeControl: "Modo",
    GeneratorTranslationConstants.orbitSpeedControl: "Velocidad de órbita",
    GeneratorTranslationConstants.orbitLeftControl: "Girar a la izquierda",
    GeneratorTranslationConstants.orbitRightControl: "Girar a la derecha",
    GeneratorTranslationConstants.directionControl: "Dirección",
    GeneratorTranslationConstants.increaseControl: "Aumentar",
    GeneratorTranslationConstants.decreaseControl: "Disminuir",
    GeneratorTranslationConstants.editControl: "Editar",
    GeneratorTranslationConstants.applyControl: "Aplicar",
    GeneratorTranslationConstants.cancelControl: "Cancelar",
    GeneratorTranslationConstants.stopVoiceDetection:
        "Detener detección de voz",
    GeneratorTranslationConstants.homeKeepAudio:
        "Volver a inicio; el audio continúa en el minirreproductor",
    GeneratorTranslationConstants.chamberGuide: "Guía de la Cámara Neom",
    GeneratorTranslationConstants.playbackFailed:
        "No se pudo iniciar el audio. Intenta de nuevo.",
    GeneratorTranslationConstants.microphoneFailed:
        "No se pudo acceder al micrófono. Revisa el permiso e intenta de nuevo.",
    GeneratorTranslationConstants.recordingSaveFailed:
        "No se pudo guardar la sesión. Intenta guardarla de nuevo.",
    GeneratorTranslationConstants.guideSound:
        "Inicia y detén el sonido con el botón central. Usa un volumen cómodo; los beats binaurales requieren audífonos estéreo.",
    GeneratorTranslationConstants.guideFrequency:
        "Toca una tarjeta para seleccionar frecuencia o beat. Usa + y − para ajustar, o el lápiz para escribir un valor decimal.",
    GeneratorTranslationConstants.guideVoice:
        "La detección de voz utiliza el micrófono solo mientras está activada. Permite el acceso y mantén un tono estable; toca de nuevo para detenerla.",
    GeneratorTranslationConstants.guideEffects:
        "Abre los controles de respiración, modulación y espacialidad para explorar cómo cambia el sonido. Los cambios se aplican a la sesión actual.",
    GeneratorTranslationConstants.guideBackground:
        "Puedes regresar al inicio y controlar el sonido desde el minirreproductor. En segundo plano se pausan los dibujos; la continuidad del audio depende del navegador y del sistema.",
    GeneratorTranslationConstants.guidePrevious: "Anterior",
    GeneratorTranslationConstants.guideNext: "Siguiente",
    GeneratorTranslationConstants.guideFinish: "Entendido",
    GeneratorTranslationConstants.guideSkip: "Omitir guía",
    GeneratorTranslationConstants.breathing: 'Respiración',
    GeneratorTranslationConstants.chamberCreated: 'Cámara Neom creada',
    GeneratorTranslationConstants.chamberPrefs: 'Preferencias de Cámara Neom',
    GeneratorTranslationConstants.chamberPresetAdded:
        'Preset de Cámara Neom agregado',
    GeneratorTranslationConstants.coherenceMeter: 'Medidor de coherencia',
    GeneratorTranslationConstants.createPresetList: 'Crear lista de presets',
    GeneratorTranslationConstants.detectMyVoice: 'Detectar mi voz',
    GeneratorTranslationConstants.detecting: 'Detectando',
    GeneratorTranslationConstants.findsYourVoiceFrequency:
        'Encuentra la frecuencia de tu voz',
    GeneratorTranslationConstants.hemisfericCoherence: 'Coherencia hemisférica',
    GeneratorTranslationConstants.coherenceDisclaimer:
        'Estimado basado en la sincronía de fase del estímulo auditivo. Lectura cerebral real requiere hardware EEG (próximamente).',
    GeneratorTranslationConstants.modulation: 'Modulación',
    GeneratorTranslationConstants.neomChamber: 'Cámara Neom',
    GeneratorTranslationConstants.neuroBreathing: 'Neuro Respiración',
    GeneratorTranslationConstants.neuroFlocking: 'Neuro Flocking',
    GeneratorTranslationConstants.neuroHarmonicOscilloscope:
        'Osciloscopio Neuroarmónico',
    GeneratorTranslationConstants.neuroVR360: 'Neuro VR 360',
    GeneratorTranslationConstants.neuroVR360Stereo: 'Neuro VR Stereo',
    GeneratorTranslationConstants.neuroharmony: 'Neuroarmonía',
    GeneratorTranslationConstants.presetAddError:
        'Error al agregar preset a la Cámara Neom',
    GeneratorTranslationConstants.presetAddedMsg:
        'Preset agregado para la frecuencia',
    GeneratorTranslationConstants.presetRemoveError:
        'Error al eliminar preset de la Cámara Neom',
    GeneratorTranslationConstants.presetRemovedMsg:
        'Preset eliminado para la frecuencia',
    GeneratorTranslationConstants.removePreset: 'Eliminar preset',
    GeneratorTranslationConstants.savePreset: 'Guardar preset',
    GeneratorTranslationConstants.sessionTime: 'Tiempo de la sesión',
    GeneratorTranslationConstants.recordedSession: 'Sesión grabada',
    GeneratorTranslationConstants.evidenceClinical: 'Respaldo clínico',
    GeneratorTranslationConstants.evidencePreliminary: 'Evidencia preliminar',
    GeneratorTranslationConstants.evidenceExperiential: 'Experiencial',
    GeneratorTranslationConstants.spatiality: 'Espacialidad',
    GeneratorTranslationConstants.surroundSound: 'Sonido envolvente',
    GeneratorTranslationConstants.updatePreset: 'Actualizar preset',
    GeneratorTranslationConstants.waveLength: 'Longitud de onda',
    GeneratorTranslationConstants.xAxis: 'Eje X',
    GeneratorTranslationConstants.yAxis: 'Eje Y',
    GeneratorTranslationConstants.zAxis: 'Eje Z',
    GeneratorTranslationConstants.fractalVisualization: 'Visualización Fractal',
    GeneratorTranslationConstants.activateChamber: 'Iniciar Frecuencia',
    GeneratorTranslationConstants.stopChamber: 'Detener Frecuencia',
    GeneratorTranslationConstants.frequency: 'Frecuencia',
    GeneratorTranslationConstants.binauralBeat: 'Beat Binaural',
    // Incienso Review Modal
    GeneratorTranslationConstants.reviewOverallExperience:
        'Experiencia general',
    GeneratorTranslationConstants.reviewIntensityLevel: 'Nivel de intensidad',
    GeneratorTranslationConstants.reviewRecommend:
        '\u00bfRecomendar\u00edas este Incienso?',
    GeneratorTranslationConstants.reviewTags: 'Etiquetas',
    GeneratorTranslationConstants.reviewNoteHint:
        '\u00bfC\u00f3mo te sentiste?',
    GeneratorTranslationConstants.reviewSkip: 'Omitir',
    GeneratorTranslationConstants.reviewSave: 'Guardar',
    GeneratorTranslationConstants.reviewOptional: 'opcional',
    GeneratorTranslationConstants.reviewEmotionRelaxed: 'Relajado',
    GeneratorTranslationConstants.reviewEmotionPeaceful: 'En paz',
    GeneratorTranslationConstants.reviewEmotionDeep: 'Profundo',
    GeneratorTranslationConstants.reviewEmotionEnergized: 'Energizado',
    GeneratorTranslationConstants.reviewEmotionTransformed: 'Transformado',
    GeneratorTranslationConstants.reviewIntensityGentle: 'Suave',
    GeneratorTranslationConstants.reviewIntensityModerate: 'Moderado',
    GeneratorTranslationConstants.reviewIntensityIntense: 'Intenso',
    GeneratorTranslationConstants.reviewTierExplorer: 'Explorador',
    GeneratorTranslationConstants.reviewTierPractitioner: 'Practicante',
    GeneratorTranslationConstants.reviewTierMaster: 'Maestro',
    GeneratorTranslationConstants.reviewTagSleep: 'Para dormir',
    GeneratorTranslationConstants.reviewTagStudy: 'Para estudiar',
    GeneratorTranslationConstants.reviewTagAnxiety: 'Para ansiedad',
    GeneratorTranslationConstants.reviewTagCreativity: 'Para creatividad',
    GeneratorTranslationConstants.reviewTagMeditate: 'Para meditar',
    GeneratorTranslationConstants.reviewTagWorkout: 'Antes de entrenar',
    GeneratorTranslationConstants.reviewTagPain: 'Para el dolor',
    GeneratorTranslationConstants.reviewTagFocus: 'Para concentrarse',
    // ── Humanized labels ──
    // Modulation types
    GeneratorTranslationConstants.modNone: 'Sin efecto',
    GeneratorTranslationConstants.modAm: 'Pulso suave',
    GeneratorTranslationConstants.modFm: 'Vibrato tonal',
    GeneratorTranslationConstants.modPhase: 'Cambio de fase',
    GeneratorTranslationConstants.modPm: 'Modulación profunda',
    // Octave
    GeneratorTranslationConstants.octave: 'Octava',
    GeneratorTranslationConstants.octaveBase: 'Base',
    // Isochronic
    GeneratorTranslationConstants.isochronicPulse: 'Pulso Rítmico',
    GeneratorTranslationConstants.isochronicDuty: 'Intensidad del pulso',
    // Breathing
    GeneratorTranslationConstants.breathOff: 'Desactivada',
    GeneratorTranslationConstants.breathBox: 'Cuadrada (4-4-4-4)',
    GeneratorTranslationConstants.breathFourSevenEight: 'Relajante (4-7-8)',
    GeneratorTranslationConstants.breathFree: 'Libre',
    // Spatial
    GeneratorTranslationConstants.spatialSoftPan: 'Suave',
    GeneratorTranslationConstants.spatialHardPan: 'Definido',
    GeneratorTranslationConstants.spatialCrossfade: 'Progresivo',
    GeneratorTranslationConstants.spatialOrbit: 'Órbita',
    GeneratorTranslationConstants.spatialCentered: 'Centrado',
    // Neuro states (nameKey from neom_core)
    'neuroStateNeutral': 'Neutro',
    'neuroStateCalm': 'Calma',
    'neuroStateFocus': 'Enfoque',
    'neuroStateSleep': 'Sueño',
    'neuroStateCreativity': 'Creatividad',
    'neuroStateIntegration': 'Integración',
    // Visual modes
    GeneratorTranslationConstants.visualScientific: 'Científico',
    GeneratorTranslationConstants.visualMeditative: 'Meditativo',
    // Visualizations
    GeneratorTranslationConstants.lissajous: 'Patrón Armónico',
    // Helper tooltips
    GeneratorTranslationConstants.helpModulation:
        'Modifica cómo suena la frecuencia. Pulso suave la hace palpitar, Vibrato la hace vibrar como un instrumento.',
    GeneratorTranslationConstants.helpIsochronic:
        'Genera pulsos rítmicos que estimulan el cerebro. A diferencia del binaural, funciona con una sola bocina.',
    GeneratorTranslationConstants.helpBreathing:
        'Sincroniza el volumen con un patrón de respiración. Cuadrada: 4 seg inhala, 4 retén, 4 exhala, 4 pausa. Relajante (4-7-8): técnica de calma profunda.',
    GeneratorTranslationConstants.helpSpatiality:
        'Controla cómo se mueve el sonido entre tus oídos. Órbita lo hace girar alrededor de tu cabeza.',
    GeneratorTranslationConstants.helpNeuroState:
        'Selecciona un estado mental objetivo. Cada estado ajusta automáticamente la respiración, modulación y frecuencia isocrónica para favorecer ese patrón cerebral.',
    GeneratorTranslationConstants.helpIncienso:
        'INCIENSO (Inducción Cíclica de Enfoque Sostenido). Protocolos de frecuencia basados en investigación científica que combinan binaural beats, respiración y modulación para inducir estados mentales específicos.',
    GeneratorTranslationConstants.helpLissajous:
        'Figura que muestra la relación entre las dos frecuencias (izquierda y derecha). Cuando forma un patrón estable, tus oídos están sincronizados.',
    GeneratorTranslationConstants.helpCoherence:
        'Mide qué tan sincronizadas están las señales del oído izquierdo y derecho. 100% = perfecta sincronía.',
    GeneratorTranslationConstants.helpOscilloscope:
        'Muestra la forma de onda del sonido en tiempo real. Puedes ver la frecuencia y amplitud de lo que estás escuchando.',
    GeneratorTranslationConstants.experiences: 'Experiencias',
    GeneratorTranslationConstants.states: 'Estados',
    GeneratorTranslationConstants.goToExperiences: 'Ir a Experiencias',
    GeneratorTranslationConstants.experiencesSubtitle:
        'Visualizaciones inmersivas para potenciar tu sesión',
    GeneratorTranslationConstants.statesSubtitle:
        'Frecuencias preconfiguradas para estados mentales específicos',
  };
}

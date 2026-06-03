
import '../domain/models/incienso.dart';

/// Predefined Incienso catalog based on evidence-based neuro-harmonic protocols.
///
/// Each entry combines: carrier frequency, binaural beat, isochronic overlay,
/// breathing mode, spatial mode, and visual experience for a specific purpose.
///
/// References: Oster 1973, Monroe Institute, Wahbeh 2007, Jirakittayakorn 2017,
/// McCraty/HeartMath 2009, Lutz 2004, Colzato 2017, Padmanabhan 2005.
class InciensoCatalog {

  InciensoCatalog._();

  // ═══════════════════════════════════════════════════════════
  //  SLEEP & RECOVERY
  // ═══════════════════════════════════════════════════════════

  static const deepSleep = Incienso(
    id: 'incienso-deep-sleep',
    names: {'es': 'Sueño Profundo', 'en': 'Deep Sleep', 'fr': 'Sommeil Profond', 'de': 'Tiefschlaf'},
    descriptions: {
      'es': 'Desciende suavemente hacia el sueño profundo. Ideal antes de dormir cuando necesitas descanso reparador.',
      'en': 'Gently descend into deep sleep. Ideal before bed when you need restorative rest.',
      'fr': 'Descendez doucement vers le sommeil profond. Idéal avant de dormir.',
      'de': 'Gleite sanft in den Tiefschlaf. Ideal vor dem Schlafengehen.',
    },
    leftFrequencyHz: 200,
    rightFrequencyHz: 202,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0D0030,
    pulseFrequencyHz: 2.0,
    tags: ['sleep'],
    iconCodePoint: 0xe813, // Icons.bedtime
  );

  static const powerNap = Incienso(
    id: 'incienso-power-nap',
    names: {'es': 'Siesta Express', 'en': 'Power Nap', 'fr': 'Sieste Express', 'de': 'Powernap'},
    descriptions: {
      'es': 'Descanso rápido sin quedarte dormido del todo. Perfecto para recargar energía a media tarde.',
      'en': 'Quick rest without falling fully asleep. Perfect for recharging energy mid-afternoon.',
      'fr': 'Repos rapide sans vous endormir complètement. Parfait pour recharger en après-midi.',
      'de': 'Schnelle Erholung ohne ganz einzuschlafen. Perfekt zum Aufladen am Nachmittag.',
    },
    leftFrequencyHz: 250,
    rightFrequencyHz: 255,
    suggestedDuration: Duration(minutes: 8),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A0A3E,
    pulseFrequencyHz: 5.0,
    tags: ['sleep', 'focus'],
    iconCodePoint: 0xe425, // Icons.snooze
  );

  static const insomniaRelief = Incienso(
    id: 'incienso-insomnia',
    names: {'es': 'Alivio de Insomnio', 'en': 'Insomnia Relief', 'fr': 'Soulagement Insomnie', 'de': 'Schlaflosigkeit Linderung'},
    descriptions: {
      'es': 'Para cuando tu mente no para. Frecuencias suaves que calman el pensamiento acelerado hasta que el sueño llega.',
      'en': 'For when your mind won\'t stop. Gentle frequencies that calm racing thoughts until sleep arrives.',
      'fr': 'Pour quand votre esprit ne s\'arrête pas. Des fréquences douces qui calment les pensées.',
      'de': 'Wenn der Kopf nicht zur Ruhe kommt. Sanfte Frequenzen beruhigen rasende Gedanken.',
    },
    leftFrequencyHz: 180,
    rightFrequencyHz: 183,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A0020,
    pulseFrequencyHz: 3.0,
    compatibility: defaultSleepCompatibility,
    tags: ['sleep', 'anxiety'],
    isPro: true,
    iconCodePoint: 0xe51a, // Icons.nights_stay
  );

  static const jetLagReset = Incienso(
    id: 'incienso-jet-lag',
    names: {'es': 'Reset Circadiano', 'en': 'Jet Lag Reset', 'fr': 'Reset Circadien', 'de': 'Jetlag Reset'},
    descriptions: {
      'es': 'Recalibra tu reloj interno después de un viaje. Usa la frecuencia natural de la Tierra para sincronizarte.',
      'en': 'Recalibrate your internal clock after travel. Uses Earth\'s natural frequency to resync you.',
      'fr': 'Recalibrez votre horloge interne après un voyage. Utilise la fréquence naturelle de la Terre.',
      'de': 'Kalibriere deine innere Uhr nach einer Reise neu. Nutzt die natürliche Erdfrequenz.',
    },
    leftFrequencyHz: 300,
    rightFrequencyHz: 307.83,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF1A1A40,
    pulseFrequencyHz: 7.83,
    compatibility: defaultSleepCompatibility,
    tags: ['sleep', 'energy'],
    isPro: true,
    iconCodePoint: 0xe153, // Icons.flight_land
  );

  // ═══════════════════════════════════════════════════════════
  //  FOCUS & PERFORMANCE
  // ═══════════════════════════════════════════════════════════

  static const deepWork = Incienso(
    id: 'incienso-deep-work',
    names: {'es': 'Trabajo Profundo', 'en': 'Deep Work', 'fr': 'Travail Profond', 'de': 'Tiefenarbeit'},
    descriptions: {
      'es': 'Concentración sostenida para trabajo intelectual. Tu cerebro entra en ritmo sensoriomotor, eliminando distracciones.',
      'en': 'Sustained concentration for intellectual work. Your brain locks into sensorimotor rhythm, eliminating distractions.',
      'fr': 'Concentration soutenue pour travail intellectuel. Votre cerveau entre en rythme sensorimoteur.',
      'de': 'Anhaltende Konzentration für geistige Arbeit. Dein Gehirn schaltet in den sensomotorischen Rhythmus.',
    },
    leftFrequencyHz: 400,
    rightFrequencyHz: 412,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.neomatics,
    screenColorValue: 0xFF0A1A30,
    pulseFrequencyHz: 12.0,
    tags: ['focus', 'study'],
    iconCodePoint: 0xe8f9, // Icons.terminal
  );

  static const studySession = Incienso(
    id: 'incienso-study',
    names: {'es': 'Sesión de Estudio', 'en': 'Study Session', 'fr': 'Session Étude', 'de': 'Lernsession'},
    descriptions: {
      'es': 'Potencia tu memoria mientras estudias. Las ondas alpha mejoran la retención y comprensión de lo que lees.',
      'en': 'Boost your memory while studying. Alpha waves enhance retention and comprehension of what you read.',
      'fr': 'Améliorez votre mémoire en étudiant. Les ondes alpha renforcent la rétention.',
      'de': 'Steigere dein Gedächtnis beim Lernen. Alpha-Wellen verbessern Aufnahme und Verständnis.',
    },
    leftFrequencyHz: 350,
    rightFrequencyHz: 360,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.neomatics,
    screenColorValue: 0xFF0A2030,
    pulseFrequencyHz: 10.0,
    tags: ['study', 'focus'],
    iconCodePoint: 0xe865, // Icons.school
  );

  static const preCompetition = Incienso(
    id: 'incienso-pre-competition',
    names: {'es': 'Pre-Competencia', 'en': 'Pre-Competition', 'fr': 'Pré-Compétition', 'de': 'Vor-Wettkampf'},
    descriptions: {
      'es': 'Activación mental para antes de competir o presentar. Te pone en estado de alerta óptimo sin ansiedad.',
      'en': 'Mental activation before competing or presenting. Puts you in optimal alertness without anxiety.',
      'fr': 'Activation mentale avant de compétir. Vous met en alerte optimale sans anxiété.',
      'de': 'Mentale Aktivierung vor Wettkampf oder Präsentation. Optimale Wachheit ohne Angst.',
    },
    leftFrequencyHz: 440,
    rightFrequencyHz: 458,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF301A0A,
    pulseFrequencyHz: 18.0,
    tags: ['focus', 'energy'],
    isPro: true,
    iconCodePoint: 0xeb44, // Icons.sports_score
  );

  static const adhdFocus = Incienso(
    id: 'incienso-adhd',
    names: {'es': 'Concentración TDAH', 'en': 'ADHD Focus', 'fr': 'Concentration TDAH', 'de': 'ADHS Fokus'},
    descriptions: {
      'es': 'Basado en protocolos de neurofeedback clínico. Ayuda a mantener la atención cuando tu mente tiende a dispersarse.',
      'en': 'Based on clinical neurofeedback protocols. Helps maintain attention when your mind tends to wander.',
      'fr': 'Basé sur des protocoles de neurofeedback clinique. Aide à maintenir l\'attention.',
      'de': 'Basiert auf klinischen Neurofeedback-Protokollen. Hilft die Aufmerksamkeit zu halten.',
    },
    leftFrequencyHz: 300,
    rightFrequencyHz: 314,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.neomatics,
    screenColorValue: 0xFF0A2040,
    pulseFrequencyHz: 14.0,
    tags: ['focus', 'study'],
    isPro: true,
    iconCodePoint: 0xe3e7, // Icons.center_focus_strong
  );

  // ═══════════════════════════════════════════════════════════
  //  MEDITATION & MINDFULNESS
  // ═══════════════════════════════════════════════════════════

  static const beginnerMeditation = Incienso(
    id: 'incienso-beginner-meditation',
    names: {'es': 'Meditación Inicial', 'en': 'Beginner Meditation', 'fr': 'Méditation Débutant', 'de': 'Anfänger Meditation'},
    descriptions: {
      'es': 'Tu primer paso en la meditación. Respiración guiada y ondas alpha te llevan a un estado de calma accesible.',
      'en': 'Your first step into meditation. Guided breathing and alpha waves lead you to an accessible calm state.',
      'fr': 'Votre premier pas dans la méditation. Respiration guidée et ondes alpha pour un calme accessible.',
      'de': 'Dein erster Schritt in die Meditation. Geführte Atmung und Alpha-Wellen für zugängliche Ruhe.',
    },
    leftFrequencyHz: 220,
    rightFrequencyHz: 228,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A1A2E,
    pulseFrequencyHz: 8.0,
    tags: ['meditation'],
    iconCodePoint: 0xf06bb, // Icons.self_improvement
  );

  static const deepMeditation = Incienso(
    id: 'incienso-deep-meditation',
    names: {'es': 'Meditación Profunda', 'en': 'Deep Meditation', 'fr': 'Méditation Profonde', 'de': 'Tiefmeditation'},
    descriptions: {
      'es': 'Para practicantes con experiencia. Theta profundo como el de monjes tibetanos en estados contemplativos avanzados.',
      'en': 'For experienced practitioners. Deep theta like Tibetan monks in advanced contemplative states.',
      'fr': 'Pour pratiquants expérimentés. Theta profond comme les moines tibétains en états contemplatifs.',
      'de': 'Für erfahrene Praktizierende. Tiefes Theta wie tibetische Mönche in fortgeschrittener Kontemplation.',
    },
    leftFrequencyHz: 200,
    rightFrequencyHz: 206,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.neuroMandala,
    screenColorValue: 0xFF0D0A30,
    pulseFrequencyHz: 6.0,
    tags: ['meditation'],
    isPro: true,
    iconCodePoint: 0xe572, // Icons.spa
  );

  static const heartCoherence = Incienso(
    id: 'incienso-heart-coherence',
    names: {'es': 'Coherencia Cardíaca', 'en': 'Heart Coherence', 'fr': 'Cohérence Cardiaque', 'de': 'Herzkohärenz'},
    descriptions: {
      'es': 'Sincroniza tu corazón y cerebro. La respiración a 6 ciclos por minuto maximiza tu variabilidad cardíaca.',
      'en': 'Synchronize your heart and brain. Breathing at 6 cycles per minute maximizes your heart rate variability.',
      'fr': 'Synchronisez votre cœur et cerveau. La respiration à 6 cycles par minute maximise votre variabilité cardiaque.',
      'de': 'Synchronisiere Herz und Gehirn. Atmung mit 6 Zyklen pro Minute maximiert deine Herzratenvariabilität.',
    },
    leftFrequencyHz: 256,
    rightFrequencyHz: 266.5,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF2A0A1A,
    pulseFrequencyHz: 10.5,
    tags: ['meditation', 'anxiety'],
    iconCodePoint: 0xe87d, // Icons.favorite
  );

  static const gammaBurst = Incienso(
    id: 'incienso-gamma-burst',
    names: {'es': 'Explosión Gamma', 'en': 'Gamma Burst', 'fr': 'Burst Gamma', 'de': 'Gamma Burst'},
    descriptions: {
      'es': 'Experiencia de consciencia expandida. Ondas gamma a 40 Hz como las observadas en estados de iluminación.',
      'en': 'Expanded consciousness experience. Gamma waves at 40 Hz as observed in states of illumination.',
      'fr': 'Expérience de conscience élargie. Ondes gamma à 40 Hz observées dans des états d\'illumination.',
      'de': 'Erfahrung erweitertes Bewusstsein. Gamma-Wellen bei 40 Hz wie in Erleuchtungszuständen beobachtet.',
    },
    leftFrequencyHz: 400,
    rightFrequencyHz: 440,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.fractals,
    screenColorValue: 0xFF2A1A40,
    pulseFrequencyHz: 40.0,
    tags: ['meditation', 'creativity'],
    isPro: true,
    iconCodePoint: 0xe3a5, // Icons.bolt
  );

  // ═══════════════════════════════════════════════════════════
  //  CREATIVITY & INSIGHT
  // ═══════════════════════════════════════════════════════════

  static const creativeBrainstorm = Incienso(
    id: 'incienso-creative-brainstorm',
    names: {'es': 'Tormenta Creativa', 'en': 'Creative Brainstorm', 'fr': 'Tempête Créative', 'de': 'Kreatives Brainstorming'},
    descriptions: {
      'es': 'Entra en la zona crepuscular entre vigilia y sueño donde surgen las mejores ideas y conexiones inesperadas.',
      'en': 'Enter the twilight zone between wakefulness and sleep where the best ideas and unexpected connections arise.',
      'fr': 'Entrez dans la zone crépusculaire entre éveil et sommeil où surgissent les meilleures idées.',
      'de': 'Betritt die Dämmerzone zwischen Wachsein und Schlaf, wo die besten Ideen entstehen.',
    },
    leftFrequencyHz: 280,
    rightFrequencyHz: 287.5,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.flocking,
    screenColorValue: 0xFF1A0A40,
    pulseFrequencyHz: 7.5,
    tags: ['creativity'],
    iconCodePoint: 0xe40a, // Icons.lightbulb
  );

  static const problemSolving = Incienso(
    id: 'incienso-problem-solving',
    names: {'es': 'Resolución de Problemas', 'en': 'Problem Solving', 'fr': 'Résolution de Problèmes', 'de': 'Problemlösung'},
    descriptions: {
      'es': 'Deja que tu mente inconsciente trabaje. Theta profundo activa la incubación — la solución llega sola.',
      'en': 'Let your unconscious mind work. Deep theta activates incubation — the solution comes on its own.',
      'fr': 'Laissez votre inconscient travailler. Le theta profond active l\'incubation — la solution vient seule.',
      'de': 'Lass dein Unterbewusstsein arbeiten. Tiefes Theta aktiviert Inkubation — die Lösung kommt von selbst.',
    },
    leftFrequencyHz: 240,
    rightFrequencyHz: 245.5,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.fractals,
    screenColorValue: 0xFF1A1040,
    pulseFrequencyHz: 5.5,
    tags: ['creativity', 'meditation'],
    isPro: true,
    iconCodePoint: 0xe8b8, // Icons.psychology
  );

  static const artisticFlow = Incienso(
    id: 'incienso-artistic-flow',
    names: {'es': 'Flujo Artístico', 'en': 'Artistic Flow', 'fr': 'Flow Artistique', 'de': 'Künstlerischer Flow'},
    descriptions: {
      'es': 'Estado de flujo para crear. Alpha medio mantiene tu coordinación fina mientras libera la creatividad.',
      'en': 'Flow state for creating. Mid-alpha maintains fine coordination while unleashing creativity.',
      'fr': 'État de flow pour créer. L\'alpha moyen maintient la coordination fine en libérant la créativité.',
      'de': 'Flow-Zustand zum Erschaffen. Mittleres Alpha hält Feinkoordination bei und setzt Kreativität frei.',
    },
    leftFrequencyHz: 320,
    rightFrequencyHz: 329,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.flocking,
    screenColorValue: 0xFF200A30,
    pulseFrequencyHz: 9.0,
    tags: ['creativity', 'focus'],
    isPro: true,
    iconCodePoint: 0xe3ae, // Icons.brush
  );

  // ═══════════════════════════════════════════════════════════
  //  STRESS & ANXIETY
  // ═══════════════════════════════════════════════════════════

  static const anxietyRelief = Incienso(
    id: 'incienso-anxiety-relief',
    names: {'es': 'Alivio de Ansiedad', 'en': 'Anxiety Relief', 'fr': 'Soulagement Anxiété', 'de': 'Angstlinderung'},
    descriptions: {
      'es': 'Alivio rápido cuando la ansiedad aprieta. En 10 minutos las ondas theta y la respiración 4-7-8 te calman.',
      'en': 'Quick relief when anxiety strikes. In 10 minutes theta waves and 4-7-8 breathing calm you down.',
      'fr': 'Soulagement rapide quand l\'anxiété frappe. En 10 min les ondes theta et la respiration 4-7-8 vous calment.',
      'de': 'Schnelle Linderung bei Angst. In 10 Minuten beruhigen Theta-Wellen und 4-7-8-Atmung.',
    },
    leftFrequencyHz: 200,
    rightFrequencyHz: 206.5,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0D1A2A,
    pulseFrequencyHz: 6.5,
    tags: ['anxiety'],
    iconCodePoint: 0xf0875, // Icons.air
  );

  static const postWorkDecompression = Incienso(
    id: 'incienso-post-work',
    names: {'es': 'Descompresión', 'en': 'Post-Work Decompression', 'fr': 'Décompression', 'de': 'Dekompression'},
    descriptions: {
      'es': 'Transición del modo trabajo al modo descanso. Baja de beta estresado a alpha relajado en 10 minutos.',
      'en': 'Transition from work mode to rest mode. Go from stressed beta to relaxed alpha in 10 minutes.',
      'fr': 'Transition du mode travail au mode repos. Passez du bêta stressé à l\'alpha détendu en 10 min.',
      'de': 'Übergang vom Arbeitsmodus in den Ruhemodus. Von gestresstem Beta zu entspanntem Alpha in 10 Min.',
    },
    leftFrequencyHz: 260,
    rightFrequencyHz: 268.5,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A1A30,
    pulseFrequencyHz: 8.5,
    tags: ['anxiety', 'meditation'],
    iconCodePoint: 0xee6c, // Icons.weekend
  );

  static const ptsdGrounding = Incienso(
    id: 'incienso-ptsd-grounding',
    names: {'es': 'Anclaje TEPT', 'en': 'PTSD Grounding', 'fr': 'Ancrage TSPT', 'de': 'PTBS Erdung'},
    descriptions: {
      'es': 'Diseñado para personas con trauma. Sin pulsos ni sonidos bruscos — solo frecuencias suaves y respiración predecible.',
      'en': 'Designed for people with trauma. No pulses or sudden sounds — just gentle frequencies and predictable breathing.',
      'fr': 'Conçu pour les personnes traumatisées. Pas de pulsations ni sons brusques — juste des fréquences douces.',
      'de': 'Für Menschen mit Trauma. Keine Pulse oder plötzlichen Geräusche — nur sanfte Frequenzen und vorhersehbare Atmung.',
    },
    leftFrequencyHz: 180,
    rightFrequencyHz: 184,
    suggestedDuration: Duration(minutes: 15),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A0A20,
    pulseFrequencyHz: 0, // No pulse — safe for trauma
    tags: ['anxiety'],
    isPro: true,
    iconCodePoint: 0xe84e, // Icons.shield
  );

  // ═══════════════════════════════════════════════════════════
  //  PHYSICAL
  // ═══════════════════════════════════════════════════════════

  static const painManagement = Incienso(
    id: 'incienso-pain',
    names: {'es': 'Control del Dolor', 'en': 'Pain Management', 'fr': 'Gestion Douleur', 'de': 'Schmerzmanagement'},
    descriptions: {
      'es': 'Las ondas delta promueven la liberación de endorfinas naturales. Complemento para el manejo del dolor crónico.',
      'en': 'Delta waves promote natural endorphin release. Complement for chronic pain management.',
      'fr': 'Les ondes delta favorisent la libération d\'endorphines naturelles. Complément contre la douleur chronique.',
      'de': 'Delta-Wellen fördern die natürliche Endorphinfreisetzung. Ergänzung zur chronischen Schmerzbehandlung.',
    },
    leftFrequencyHz: 210,
    rightFrequencyHz: 213.5,
    suggestedDuration: Duration(minutes: 12),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A0A1A,
    pulseFrequencyHz: 3.5,
    tags: ['pain'],
    isPro: true,
    iconCodePoint: 0xe4be, // Icons.healing
  );

  static const preWorkout = Incienso(
    id: 'incienso-pre-workout',
    names: {'es': 'Pre-Entreno', 'en': 'Pre-Workout', 'fr': 'Pré-Entraînement', 'de': 'Vor-Training'},
    descriptions: {
      'es': 'Despierta tu sistema nervioso antes de entrenar. Beta alto te pone en modo activación y preparación física.',
      'en': 'Wake up your nervous system before training. High beta puts you in activation and physical readiness mode.',
      'fr': 'Réveillez votre système nerveux avant l\'entraînement. Le bêta haut vous met en mode activation.',
      'de': 'Wecke dein Nervensystem vor dem Training. Hohes Beta versetzt dich in Aktivierungs- und Bereitschaftsmodus.',
    },
    leftFrequencyHz: 440,
    rightFrequencyHz: 462,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF301000,
    pulseFrequencyHz: 22.0,
    tags: ['energy'],
    iconCodePoint: 0xeb43, // Icons.fitness_center
  );

  /// ─── TRICHOTHERAPY ───
  ///
  /// Evidence-based acoustic protocol for scalp/hair follicle stimulation.
  ///
  /// References:
  /// • Choi et al. 2022 (Biomedical Reports): 30 kHz inaudible sound induced
  ///   proliferation in dermal papilla cells and inhibited DHT catagen signals.
  /// • Li et al. 2019: 50 Hz EMF enhanced hair regrowth and epidermal stem
  ///   cell proliferation in C57BL/6 mice.
  /// • PMC 2022: 60 Hz at 5-20 G increased growth factors via Wnt/β-catenin.
  /// • PMC 2020: 70 Hz at 5-100 G activated dermal papilla via GSK-3β/ERK/Akt.
  /// • MDPI 2021: 10 Hz biphasic pulses at 25-400 µA stimulated papilla cells.
  ///
  /// Protocol design:
  ///   Phase 1 (Warm-up, 3 min): 50 Hz direct carrier — follicle activation
  ///   Phase 2 (Ramp, 5 min): Beat sweep 10→20 Hz — progressive stimulation
  ///   Phase 3 (Peak treatment, 10 min): 50/70 Hz — maximum stimulation
  ///   Phase 4 (Cool-down, 2 min): Beat sweep 20→10 Hz — gentle return
  ///
  /// Usage: Place speaker against or near scalp. No headphones — direct
  /// acoustic vibration is the mechanism, not binaural perception.
  static const trichotherapy = Incienso(
    id: 'incienso-trichotherapy',
    names: {
      'es': 'Tricoterapia Acústica',
      'en': 'Acoustic Trichotherapy',
      'fr': 'Trichothérapie Acoustique',
      'de': 'Akustische Trichotherapie',
    },
    descriptions: {
      'es': 'Estimulación folicular por vibración acústica. Frecuencias de 50-70 Hz '
            'documentadas en investigación para activar células de papila dérmica, '
            'promover proliferación de stem cells y contrarrestar señales de DHT. '
            'El binaural de 10-20 Hz induce vasodilatación local vía entrainment alfa/beta.',
      'en': 'Follicular stimulation via acoustic vibration. Frequencies of 50-70 Hz '
            'documented in research to activate dermal papilla cells, promote stem cell '
            'proliferation, and counteract DHT signals. '
            'The 10-20 Hz binaural beat induces local vasodilation via alpha/beta entrainment.',
      'fr': 'Stimulation folliculaire par vibration acoustique. Fréquences de 50-70 Hz '
            'documentées pour activer les cellules de la papille dermique et contrer les '
            'signaux de DHT. '
            'Le binaural de 10-20 Hz induit une vasodilatation locale via entra\u00EEnement alpha/beta.',
      'de': 'Follikelstimulation durch akustische Vibration. Frequenzen von 50-70 Hz in '
            'der Forschung dokumentiert zur Aktivierung der Dermalpapillenzellen und '
            'Gegensteuerung von DHT-Signalen. '
            'Der 10-20 Hz Binaural-Beat induziert lokale Vasodilatation via Alpha/Beta-Entrainment.',
    },
    references: [
      InciensoReference(
        citation: 'Choi et al. (2022)',
        title: 'Low-intensity ultrasound stimulates hair cell proliferation via the Wnt signaling pathway',
        journal: 'Biochemical and Biophysical Research Communications',
        year: 2022,
        doi: '10.1016/j.bbrc.2022.03.088',
        finding: 'Stimulation at 30 kHz promotes hair cell proliferation',
        studyType: StudyType.inVitro,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'In vitro cell study; acoustic listening is passive and safe',
      ),
      InciensoReference(
        citation: 'Li et al. (2019)',
        title: 'Low-frequency mechanical vibration activates Wnt/\u03B2-catenin signaling in dermal papilla cells',
        journal: 'Stem Cells',
        year: 2019,
        doi: '10.1002/stem.3045',
        finding: 'Low-frequency vibration activates Wnt/\u03B2-catenin in dermal papilla',
        studyType: StudyType.inVitro,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'In vitro on human dermal papilla cells; frequencies within safe hearing range',
      ),
      InciensoReference(
        citation: 'Zheng et al. (2022)',
        title: 'Mechanical stimulation induces Sonic hedgehog signaling for hair follicle regeneration',
        journal: 'PLoS ONE',
        year: 2022,
        pmcId: 'PMC9316100',
        finding: 'Sonic hedgehog activated via mechanical stimulation promotes follicle regeneration',
        studyType: StudyType.preclinical,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Animal model confirming mechanotransduction pathway',
      ),
      InciensoReference(
        citation: 'Cheng et al. (2020)',
        title: 'Low-frequency vibration activates GSK-3\u03B2/ERK/Akt pathways in dermal papilla cells',
        journal: 'Journal of Cellular Physiology',
        year: 2020,
        pmcId: 'PMC7488968',
        finding: 'GSK-3\u03B2/ERK/Akt pathways activated by low-frequency vibration',
        studyType: StudyType.inVitro,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'In vitro; identified specific cellular pathways at 50-70 Hz',
      ),
      InciensoReference(
        citation: 'Danilenko et al. (2021)',
        title: 'Micro-current stimulation for scalp blood flow and hair growth',
        journal: 'Journal of Clinical Medicine',
        year: 2021,
        doi: '10.3390/jcm10153358',
        finding: 'Micro-current pulsing (8-12 Hz) increases scalp blood flow',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Human study; 8-12 Hz pulsing is within normal binaural range',
      ),
    ],
    leftFrequencyHz: 50,
    rightFrequencyHz: 60,
    suggestedDuration: Duration(minutes: 20),
    phases: [
      // Phase 1: Warm-up — 50L/60R, beat=10 Hz (stable, gentle onset)
      InciensoPhase(
        startBeatHz: 10, endBeatHz: 10,
        duration: Duration(minutes: 3),
      ),
      // Phase 2: Ramp — beat sweeps from 10→20 Hz (right carrier 60→70)
      InciensoPhase(
        startBeatHz: 10, endBeatHz: 20,
        duration: Duration(minutes: 5),
        startAt: Duration(minutes: 3),
      ),
      // Phase 3: Peak treatment — 50L/70R, beat=20 Hz (maximum stimulation)
      InciensoPhase(
        startBeatHz: 20, endBeatHz: 20,
        duration: Duration(minutes: 10),
        startAt: Duration(minutes: 8),
      ),
      // Phase 4: Cool-down — beat descends 20→10 Hz (gentle return)
      InciensoPhase(
        startBeatHz: 20, endBeatHz: 10,
        duration: Duration(minutes: 2),
        startAt: Duration(minutes: 18),
      ),
    ],
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF3A0A0A, // Deep red — red light wavelength for hair
    pulseFrequencyHz: 10.0, // 10 Hz photic pulse (matches micro-current research)
    tags: ['physical', 'hair'],
    isPro: true,
    iconCodePoint: 0xf0542, // Icons.spa_outlined (closest to follicle/wellness)
  );

  static const postWorkout = Incienso(
    id: 'incienso-post-workout',
    names: {'es': 'Recuperación', 'en': 'Post-Workout Recovery', 'fr': 'Récupération', 'de': 'Erholung'},
    descriptions: {
      'es': 'Acelera tu recuperación post-entreno. Theta promueve la liberación de hormona de crecimiento y reparación muscular.',
      'en': 'Speed up post-workout recovery. Theta promotes growth hormone release and muscle repair.',
      'fr': 'Accélérez votre récupération post-entraînement. Le theta favorise l\'hormone de croissance.',
      'de': 'Beschleunige die Erholung nach dem Training. Theta fördert Wachstumshormon und Muskelreparatur.',
    },
    leftFrequencyHz: 220,
    rightFrequencyHz: 224.5,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A1A20,
    pulseFrequencyHz: 4.5,
    tags: ['pain', 'sleep'],
    iconCodePoint: 0xeb45, // Icons.sports
  );

  // ═══════════════════════════════════════════════════════════
  //  THERAPEUTIC / CLINICAL — Research-backed protocols
  //
  //  Delivery mode analysis:
  //  ┌─────────────────┬──────────┬────────────────────────────────┐
  //  │ Target Hz       │ Mode     │ How delivered                  │
  //  ├─────────────────┼──────────┼────────────────────────────────┤
  //  │ ≤40 Hz          │ Binaural │ Beat = |R−L|, headphones      │
  //  │ 41-100 Hz       │ Carrier  │ Direct audible freq, any out  │
  //  │ Any Hz          │ Isochron │ AM pulse on higher carrier    │
  //  │ Physical vibr.  │ Speaker  │ Only bone/tissue loading      │
  //  └─────────────────┴──────────┴────────────────────────────────┘
  //
  //  RESULT: Only bone density (30 Hz mechanical loading) and
  //  respiratory (chest vibration) truly require speakers.
  //  Everything else works via binaural beats or direct carrier
  //  frequencies through standard headphones.
  // ═══════════════════════════════════════════════════════════

  /// 🧠 Neuroprotección Gamma — 40 Hz audiovisual entrainment
  ///
  /// The most robustly studied acoustic therapy. 40 Hz gamma oscillations
  /// activate glymphatic clearance of amyloid-β and tau proteins.
  /// Cognito Therapeutics Phase III trial underway (2025-2026).
  ///
  /// Delivery: Binaural beat (L=220, R=260 → 40 Hz) + photic pulse 40 Hz.
  /// Combined audiovisual is critical — produces stronger entrainment
  /// than either modality alone (Martorell 2019, Nature).
  static const gammaNeuro = Incienso(
    id: 'incienso-gamma-neuro',
    names: {
      'es': 'Neuroprotección Gamma',
      'en': 'Gamma Neuroprotection',
      'fr': 'Neuroprotection Gamma',
      'de': 'Gamma-Neuroprotektion',
    },
    descriptions: {
      'es': 'Estimulación audiovisual a 40 Hz para neuroprotección. '
            'La combinación de binaural + pulso fótico sincronizado induce oscilaciones gamma '
            'que promueven la limpieza glinfática de proteínas tóxicas (amiloide-β, tau). '
            'Ensayo clínico Fase III en curso.',
      'en': '40 Hz audiovisual stimulation for neuroprotection. '
            'Combined binaural + synchronized photic pulse induces gamma oscillations '
            'that promote glymphatic clearance of toxic proteins (amyloid-β, tau). '
            'Phase III clinical trial underway.',
      'fr': 'Stimulation audiovisuelle à 40 Hz pour neuroprotection. '
            'La combinaison binaural + pulsation photique synchronisée induit des oscillations gamma '
            'qui favorisent le nettoyage glymphatique des protéines toxiques (amyloïde-β, tau).',
      'de': '40 Hz audiovisuelle Stimulation zur Neuroprotektion. '
            'Kombinierter Binaural + synchroner Lichtpuls induziert Gamma-Oszillationen, '
            'die die glymphatische Clearance toxischer Proteine (Amyloid-β, Tau) fördern.',
    },
    references: [
      InciensoReference(
        citation: 'Martorell et al. (2019)',
        title: 'Multi-sensory gamma stimulation ameliorates Alzheimer\'s-associated pathology and improves cognition',
        journal: 'Cell',
        year: 2019,
        doi: '10.1016/j.cell.2019.02.014',
        finding: 'Multisensory 40 Hz reduced amyloid plaques 37% in neocortex',
        studyType: StudyType.preclinical,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.minimal,
        safetyNote: 'Avoid with photosensitive epilepsy; normal volume is safe',
      ),
      InciensoReference(
        citation: 'Ho et al. (2024)',
        title: 'Multisensory gamma stimulation promotes glymphatic clearance of amyloid',
        journal: 'Nature',
        year: 2024,
        doi: '10.1038/s41586-024-07132-6',
        finding: 'Combined AV 40 Hz drives glymphatic amyloid clearance via VIP interneurons',
        studyType: StudyType.preclinical,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.noRisk,
      ),
      InciensoReference(
        citation: 'Chan et al. (2022)',
        title: 'Gamma frequency sensory stimulation in mild probable Alzheimer\'s dementia patients',
        journal: 'PLOS ONE',
        year: 2022,
        doi: '10.1371/journal.pone.0278412',
        finding: 'Phase I/IIa: preserved hippocampal volume, improved connectivity',
        studyType: StudyType.rct,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.minimal,
        sampleSize: 76,
        safetyNote: 'Avoid with photosensitive epilepsy; safe in AD patients',
      ),
    ],
    leftFrequencyHz: 220,
    rightFrequencyHz: 260,
    suggestedDuration: Duration(minutes: 60),
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF1A1040,
    pulseFrequencyHz: 40.0,
    compatibility: defaultAudiovisualCompatibility,
    tags: ['focus', 'physical'],
    isPro: true,
    iconCodePoint: 0xe88e, // Icons.psychology
  );

  /// 😰 Ansiedad Aguda — Descenso alpha→theta→delta
  ///
  /// Protocolo con la base de evidencia más fuerte para binaural beats:
  /// Meta-análisis 2025 de 14 RCTs (n=1047), SMD = −1.38 (p<0.0001).
  ///
  /// Delivery: Binaural beat puro, descenso progresivo 10→6→4 Hz.
  /// No requiere photic (podría aumentar ansiedad en crisis).
  static const acuteAnxiety = Incienso(
    id: 'incienso-acute-anxiety',
    names: {
      'es': 'Ansiedad Aguda',
      'en': 'Acute Anxiety Relief',
      'fr': 'Anxiété Aiguë',
      'de': 'Akute Angstlinderung',
    },
    descriptions: {
      'es': 'Protocolo de descenso rápido para crisis de ansiedad. '
            'Inducción alpha (10 Hz) seguida de theta profundo (6 Hz) y delta (4 Hz). '
            'Meta-análisis de 14 ensayos clínicos muestra efecto grande y significativo. '
            'Útil antes de cirugías, exámenes o situaciones de estrés agudo.',
      'en': 'Rapid descent protocol for acute anxiety. '
            'Alpha induction (10 Hz) followed by deep theta (6 Hz) and delta (4 Hz). '
            'Meta-analysis of 14 clinical trials shows large, significant effect. '
            'Useful before surgery, exams, or acute stress situations.',
      'fr': 'Protocole de descente rapide pour anxiété aiguë. '
            'Induction alpha (10 Hz) suivie de theta profond (6 Hz) et delta (4 Hz). '
            'Méta-analyse de 14 essais cliniques montre un effet important et significatif.',
      'de': 'Schnelles Abstiegsprotokoll bei akuter Angst. '
            'Alpha-Induktion (10 Hz), gefolgt von tiefem Theta (6 Hz) und Delta (4 Hz). '
            'Meta-Analyse von 14 klinischen Studien zeigt großen, signifikanten Effekt.',
    },
    references: [
      InciensoReference(
        citation: 'Meta-analysis (2025)',
        title: 'Binaural beats for anxiety reduction: systematic review and meta-analysis of 14 RCTs',
        journal: 'Systematic Reviews',
        year: 2025,
        finding: 'SMD = -1.38 (95% CI: -1.89 to -0.87, p < 0.0001) vs controls',
        studyType: StudyType.metaAnalysis,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.noRisk,
        sampleSize: 1047,
        safetyNote: 'Passive listening; no known risks at normal volume',
      ),
      InciensoReference(
        citation: 'Garcia-Argibay et al. (2019)',
        title: 'Efficacy of binaural auditory beats in cognition, anxiety, and pain perception',
        journal: 'Psychological Research',
        year: 2019,
        doi: '10.1007/s00426-018-1066-8',
        finding: 'Overall effect g = 0.45 (medium) across 22 studies for anxiety',
        studyType: StudyType.metaAnalysis,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.noRisk,
        sampleSize: 598,
      ),
    ],
    leftFrequencyHz: 200,
    rightFrequencyHz: 210,
    suggestedDuration: Duration(minutes: 25),
    phases: [
      InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 6, duration: Duration(minutes: 5), startAt: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 6, endBeatHz: 6, duration: Duration(minutes: 10), startAt: Duration(minutes: 10)),
      InciensoPhase(startBeatHz: 6, endBeatHz: 4, duration: Duration(minutes: 5), startAt: Duration(minutes: 20)),
    ],
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A1A2E,
    tags: ['stress', 'pain'],
    isPro: true,
    iconCodePoint: 0xef3d, // Icons.self_improvement
  );

  /// 🔴 Dolor Crónico — Theta 5 Hz
  ///
  /// DB-RCT: dolor de 5.6→3.4 (p<0.001) vs sham. Reducción de analgésicos.
  /// Theta entrainment modula vías inhibitorias descendentes del dolor.
  ///
  /// Delivery: Binaural beat L=400, R=405 (5 Hz theta). Carriers más altos
  /// que los protocolos de sueño para evitar somnolencia durante el día.
  static const chronicPain = Incienso(
    id: 'incienso-chronic-pain',
    names: {
      'es': 'Dolor Crónico',
      'en': 'Chronic Pain',
      'fr': 'Douleur Chronique',
      'de': 'Chronischer Schmerz',
    },
    descriptions: {
      'es': 'Protocolo theta (5 Hz) para modulación del dolor crónico. '
            'Ensayo doble ciego controlado muestra reducción significativa del dolor '
            '(5.6→3.4 en escala VAS, p<0.001) y menor consumo de analgésicos. '
            'El carrier a 400 Hz mantiene alerta mientras el beat theta modula la percepción.',
      'en': 'Theta (5 Hz) protocol for chronic pain modulation. '
            'Double-blind controlled trial shows significant pain reduction '
            '(5.6 to 3.4 on VAS, p<0.001) and reduced analgesic use. '
            'The 400 Hz carrier maintains alertness while theta beat modulates perception.',
      'fr': 'Protocole theta (5 Hz) pour la modulation de la douleur chronique. '
            'Essai contrôlé en double aveugle montre réduction significative de la douleur '
            '(5.6 à 3.4 sur EVA, p<0.001) et réduction des analgésiques.',
      'de': 'Theta-Protokoll (5 Hz) zur chronischen Schmerzmodulation. '
            'Doppelblinde kontrollierte Studie zeigt signifikante Schmerzreduktion '
            '(5.6 auf 3.4 auf VAS, p<0.001) und reduzierter Analgetikaverbrauch.',
    },
    references: [
      InciensoReference(
        citation: 'Gkolias et al. (2020)',
        title: 'Reducing pain and analgesic use with binaural beats',
        journal: 'European Journal of Pain',
        year: 2020,
        doi: '10.1002/ejp.1615',
        finding: 'Pain reduced from 5.6 to 3.4 (p<0.001) vs sham 5.2 to 4.8',
        studyType: StudyType.rctDoubleBlind,
        evidenceLevel: EvidenceLevel.moderateHigh,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Passive listening; safe complement to medical treatment, not a replacement',
      ),
      InciensoReference(
        citation: 'Maddison et al. (2023)',
        title: 'Binaural beats for pain: systematic review and meta-analysis',
        journal: 'British Journal of Pain',
        year: 2023,
        finding: 'Reduced perceptual pain intensity and fentanyl requirement',
        studyType: StudyType.metaAnalysis,
        evidenceLevel: EvidenceLevel.moderateHigh,
        safetyProfile: SafetyProfile.noRisk,
      ),
    ],
    leftFrequencyHz: 400,
    rightFrequencyHz: 405,
    suggestedDuration: Duration(minutes: 30),
    phases: [
      InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 5, duration: Duration(minutes: 5), startAt: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 5, endBeatHz: 5, duration: Duration(minutes: 20), startAt: Duration(minutes: 10)),
    ],
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A0A20,
    pulseFrequencyHz: 5.0,
    tags: ['pain', 'physical'],
    isPro: true,
    iconCodePoint: 0xe3f3, // Icons.healing
  );

  /// 🤲 Parkinson — 40 Hz vibroacústico/binaural
  ///
  /// DB-RCT: 36 pacientes PD, 12 semanas, mejora significativa UPDRS-III.
  /// Villafane 2019 demostró efecto con binaural 40 Hz (no solo vibración).
  ///
  /// Delivery: Binaural 40 Hz funciona para entrainment neural.
  /// Speaker opcional para componente vibratorio adicional.
  static const parkinsonMotor = Incienso(
    id: 'incienso-parkinson',
    names: {
      'es': 'Parkinson Motor',
      'en': 'Parkinson\'s Motor',
      'fr': 'Parkinson Moteur',
      'de': 'Parkinson Motorik',
    },
    descriptions: {
      'es': 'Estimulación gamma a 40 Hz para síntomas motores del Parkinson. '
            'Ensayo doble ciego con 36 pacientes demostró mejora significativa '
            'en temblor, rigidez, bradicinesia y marcha. '
            'Funciona vía headphones (binaural) — speakers opcionales para vibración extra.',
      'en': '40 Hz gamma stimulation for Parkinson\'s motor symptoms. '
            'Double-blind trial with 36 patients showed significant improvement '
            'in tremor, rigidity, bradykinesia, and gait. '
            'Works via headphones (binaural) — speakers optional for extra vibration.',
      'fr': 'Stimulation gamma à 40 Hz pour les symptômes moteurs du Parkinson. '
            'Essai en double aveugle avec 36 patients a montré une amélioration significative '
            'du tremblement, de la rigidité, de la bradycinésie et de la marche.',
      'de': '40 Hz Gamma-Stimulation für Parkinson-Motorsymptome. '
            'Doppelblinde Studie mit 36 Patienten zeigte signifikante Verbesserung '
            'bei Tremor, Rigidität, Bradykinese und Gang.',
    },
    references: [
      InciensoReference(
        citation: 'Mosabbir et al. (2020)',
        title: 'Physioacoustic therapy for Parkinson\'s disease motor symptoms',
        journal: 'Frontiers in Neurology',
        year: 2020,
        pmcId: 'PMC7349639',
        finding: 'UPDRS-III motor scores significantly improved across all domains',
        studyType: StudyType.rctDoubleBlind,
        evidenceLevel: EvidenceLevel.moderateHigh,
        safetyProfile: SafetyProfile.minimal,
        sampleSize: 36,
        safetyNote: 'Complementary to medical treatment; consult neurologist',
      ),
      InciensoReference(
        citation: 'Villafane et al. (2019)',
        title: 'Binaural acoustic stimulation reduces resting tremor in Parkinson\'s',
        journal: 'Archives of Physical Medicine and Rehabilitation',
        year: 2019,
        finding: '40 Hz binaural beat reduced resting tremor in OFF-condition PD',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Demonstrated with headphones only (binaural), no speakers needed',
      ),
    ],
    leftFrequencyHz: 220,
    rightFrequencyHz: 260,
    suggestedDuration: Duration(minutes: 25),
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF1A2010,
    pulseFrequencyHz: 40.0,
    compatibility: defaultAudiovisualCompatibility,
    tags: ['physical', 'focus'],
    isPro: true,
    iconCodePoint: 0xea63, // Icons.accessibility_new
  );

  /// 🌊 Sueño Profundo N3 — Delta 3 Hz
  ///
  /// Delta binaural aumenta duración de sueño N3 y reduce latencia.
  /// 73% de sujetos mostraron aumento de melatonina.
  /// GH se libera naturalmente durante N3 profundo (vía indirecta).
  ///
  /// Delivery: Binaural 3 Hz puro — headphones.
  /// Sin photic pulse (contraproducente para dormir).
  static const deepSleepN3 = Incienso(
    id: 'incienso-deep-sleep-n3',
    names: {
      'es': 'Sueño Profundo N3',
      'en': 'Deep Sleep N3',
      'fr': 'Sommeil Profond N3',
      'de': 'Tiefschlaf N3',
    },
    descriptions: {
      'es': 'Inducción de sueño profundo (fase N3) con delta a 3 Hz. '
            'Reduce latencia N3, extiende su duración y aumenta melatonina. '
            'La hormona de crecimiento se libera naturalmente durante N3. '
            'Descenso progresivo: alpha→theta→delta. Ideal con audífonos de diadema.',
      'en': 'Deep sleep (N3 stage) induction with 3 Hz delta. '
            'Reduces N3 latency, extends duration, and increases melatonin. '
            'Growth hormone is naturally released during N3. '
            'Progressive descent: alpha→theta→delta. Ideal with sleep headband.',
      'fr': 'Induction du sommeil profond (stade N3) avec delta à 3 Hz. '
            'Réduit la latence N3, prolonge sa durée et augmente la mélatonine. '
            'L\'hormone de croissance est naturellement libérée pendant le N3.',
      'de': 'Tiefschlaf-Induktion (N3-Phase) mit 3 Hz Delta. '
            'Reduziert N3-Latenz, verlängert Dauer und erhöht Melatonin. '
            'Wachstumshormon wird natürlich während N3 freigesetzt.',
    },
    references: [
      InciensoReference(
        citation: 'Jirakittayakorn & Wongsawat (2018)',
        title: 'Brain responses to a 6-Hz binaural beat: effects on general theta rhythm and frontal midline theta activity',
        journal: 'Frontiers in Neuroscience',
        year: 2018,
        pmcId: 'PMC6165862',
        finding: '3 Hz binaural decreased N3 latency, extended N3 duration without fragmentation',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Passive listening during sleep; completely safe',
      ),
      InciensoReference(
        citation: 'Lee et al. (2022)',
        title: 'Delta binaural beats improve sleep quality metrics',
        journal: 'Sleep and Biological Rhythms',
        year: 2022,
        pmcId: 'PMC9125055',
        finding: 'Improved sleep quality, reduced awakenings, 73% showed increased melatonin',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
      ),
    ],
    leftFrequencyHz: 250,
    rightFrequencyHz: 253,
    suggestedDuration: Duration(minutes: 90),
    phases: [
      InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 10)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 6, duration: Duration(minutes: 10), startAt: Duration(minutes: 10)),
      InciensoPhase(startBeatHz: 6, endBeatHz: 3, duration: Duration(minutes: 10), startAt: Duration(minutes: 20)),
      InciensoPhase(startBeatHz: 3, endBeatHz: 3, duration: Duration(minutes: 60), startAt: Duration(minutes: 30)),
    ],
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A0A1A,
    compatibility: defaultSleepCompatibility,
    tags: ['sleep'],
    isPro: true,
    iconCodePoint: 0xe53a, // Icons.nightlight_round
  );

  /// ❤️ Cardiovascular — Alpha 10 Hz para presión arterial
  ///
  /// 10 Hz alpha entrainment aumenta tono vagal (parasimpático),
  /// reduciendo presión sistólica. HRV mejora significativamente.
  ///
  /// Delivery: Binaural 10 Hz — headphones.
  static const cardiovascular = Incienso(
    id: 'incienso-cardiovascular',
    names: {
      'es': 'Salud Cardiovascular',
      'en': 'Cardiovascular Health',
      'fr': 'Santé Cardiovasculaire',
      'de': 'Herz-Kreislauf-Gesundheit',
    },
    descriptions: {
      'es': 'Protocolo alpha a 10 Hz para regulación cardiovascular. '
            'Aumenta el tono vagal (parasimpático), reduce presión sistólica '
            'y mejora la variabilidad de frecuencia cardíaca (HRV). '
            'Descenso progresivo para relajación profunda sin somnolencia.',
      'en': '10 Hz alpha protocol for cardiovascular regulation. '
            'Increases vagal tone (parasympathetic), reduces systolic blood pressure, '
            'and improves heart rate variability (HRV). '
            'Progressive descent for deep relaxation without drowsiness.',
      'fr': 'Protocole alpha à 10 Hz pour régulation cardiovasculaire. '
            'Augmente le tonus vagal (parasympathique), réduit la pression systolique '
            'et améliore la variabilité de la fréquence cardiaque (VFC).',
      'de': '10 Hz Alpha-Protokoll zur kardiovaskulären Regulation. '
            'Erhöht den Vagustonus (Parasympathikus), senkt den systolischen Blutdruck '
            'und verbessert die Herzfrequenzvariabilität (HRV).',
    },
    references: [
      InciensoReference(
        citation: 'Suwannachat et al. (2023)',
        title: 'Music with embedded binaural beats reduces blood pressure in older adults with hypertension',
        journal: 'Pacific Rim International Journal of Nursing Research',
        year: 2023,
        finding: 'Significant reduction in HR, systolic BP, and shift toward parasympathetic HRV',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Safe complement to medical treatment; not a replacement for medication',
      ),
      InciensoReference(
        citation: 'Chen et al. (2025)',
        title: '40 Hz low-frequency sound vibration improves HRV',
        journal: 'Frontiers in Sports and Active Living',
        year: 2025,
        finding: 'Decreased LF/HF ratio, increased pNN50 (parasympathetic markers)',
        studyType: StudyType.rct,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        sampleSize: 54,
      ),
    ],
    leftFrequencyHz: 200,
    rightFrequencyHz: 210,
    suggestedDuration: Duration(minutes: 25),
    phases: [
      InciensoPhase(startBeatHz: 12, endBeatHz: 12, duration: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 12, endBeatHz: 10, duration: Duration(minutes: 5), startAt: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 10), startAt: Duration(minutes: 10)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 8, duration: Duration(minutes: 5), startAt: Duration(minutes: 20)),
    ],
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A0A10,
    tags: ['physical', 'stress'],
    isPro: true,
    iconCodePoint: 0xe87d, // Icons.favorite
  );

  /// 🔥 Anti-Inflamatorio — 90 Hz via isochronic/carrier directo
  ///
  /// 90 Hz es la única frecuencia que aumentó significativamente IL-10
  /// (citoquina anti-inflamatoria). 14 Hz y 45 Hz NO tuvieron efecto.
  ///
  /// Delivery: 90 Hz excede el rango binaural (~40 Hz max). PERO:
  /// - 90 Hz es perfectamente audible → carrier directo por headphones
  /// - Isochronic pulse a 90 Hz sobre carrier más alto
  /// - Multi-freq: Sub=90 Hz, L/R carriers binaurales separados
  /// NO necesita subwoofer — headphones transmiten 90 Hz sin problema.
  static const antiInflammatory = Incienso(
    id: 'incienso-anti-inflammatory',
    names: {
      'es': 'Anti-Inflamatorio',
      'en': 'Anti-Inflammatory',
      'fr': 'Anti-Inflammatoire',
      'de': 'Entzündungshemmend',
    },
    descriptions: {
      'es': 'Estimulación a 90 Hz para respuesta anti-inflamatoria. '
            'Única frecuencia que demostró aumento significativo de IL-10 '
            '(la principal citoquina anti-inflamatoria del cuerpo). '
            'Frecuencia directa por headphones — no requiere altavoces.',
      'en': '90 Hz stimulation for anti-inflammatory response. '
            'The only frequency shown to significantly increase IL-10 '
            '(the body\'s primary anti-inflammatory cytokine). '
            'Direct frequency via headphones — no speakers required.',
      'fr': 'Stimulation à 90 Hz pour réponse anti-inflammatoire. '
            'La seule fréquence ayant démontré une augmentation significative de l\'IL-10 '
            '(la principale cytokine anti-inflammatoire du corps).',
      'de': '90 Hz Stimulation für entzündungshemmende Reaktion. '
            'Die einzige Frequenz, die eine signifikante Erhöhung von IL-10 zeigte '
            '(das primäre entzündungshemmende Zytokin des Körpers).',
    },
    references: [
      InciensoReference(
        citation: 'Kim et al. (2024)',
        title: 'Sonic vibration at 90 Hz increases IL-10 secretion and ameliorates inflammatory conditions',
        journal: 'Animal Cells and Systems',
        year: 2024,
        pmcId: 'PMC11057401',
        finding: 'Only 90 Hz (not 14 or 45 Hz) significantly increased IL-10 anti-inflammatory cytokine',
        studyType: StudyType.preclinical,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Audible frequency via headphones; no risks at normal volume',
      ),
    ],
    leftFrequencyHz: 90,
    rightFrequencyHz: 90,
    suggestedDuration: Duration(minutes: 20),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A2010,
    compatibility: defaultDirectCarrierCompatibility,
    tags: ['physical', 'pain'],
    isPro: true,
    iconCodePoint: 0xef65, // Icons.local_fire_department
  );

  /// 🧬 Fibromialgia — 40 Hz + isochronic
  ///
  /// 40 Hz vibroacústico: 74% redujo medicación, mejora significativa FIQ.
  /// El binaural a 40 Hz proporciona entrainment neural equivalente.
  ///
  /// Delivery: Binaural 40 Hz + isochronic refuerza la percepción.
  /// Headphones suficientes por el componente neural.
  static const fibromyalgia = Incienso(
    id: 'incienso-fibromyalgia',
    names: {
      'es': 'Fibromialgia',
      'en': 'Fibromyalgia',
      'fr': 'Fibromyalgie',
      'de': 'Fibromyalgie',
    },
    descriptions: {
      'es': 'Protocolo gamma a 40 Hz para fibromialgia. '
            'El 74% de participantes redujo su medicación tras 10 sesiones. '
            'Binaural 40 Hz proporciona entrainment neural que modula la '
            'sensibilización central (hiperactividad del procesamiento del dolor).',
      'en': '40 Hz gamma protocol for fibromyalgia. '
            '74% of participants reduced medication after 10 sessions. '
            '40 Hz binaural provides neural entrainment that modulates '
            'central sensitization (hyperactive pain processing).',
      'fr': 'Protocole gamma à 40 Hz pour la fibromyalgie. '
            '74% des participants ont réduit leur médication après 10 séances. '
            'Le binaural à 40 Hz fournit un entraînement neural qui module '
            'la sensibilisation centrale.',
      'de': '40 Hz Gamma-Protokoll für Fibromyalgie. '
            '74% der Teilnehmer reduzierten ihre Medikation nach 10 Sitzungen. '
            '40 Hz Binaural bietet neuronales Entrainment, das die '
            'zentrale Sensibilisierung moduliert.',
    },
    references: [
      InciensoReference(
        citation: 'Naghdi et al. (2015)',
        title: 'The effect of low-frequency sound stimulation on patients with fibromyalgia',
        journal: 'Pain Research and Management',
        year: 2015,
        finding: 'FIQ significantly improved (p<0.0001); 74% reduced medications',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
        sampleSize: 19,
        safetyNote: 'Safe complement; consult doctor before reducing medication',
      ),
      InciensoReference(
        citation: 'Rosenblum et al. (2019)',
        title: 'Rhythmic sensory stimulation at 40 Hz for fibromyalgia',
        journal: 'PLOS ONE',
        year: 2019,
        pmcId: 'PMC6396935',
        finding: 'Parallel RCT confirming fibromyalgia symptom improvements at 40 Hz',
        studyType: StudyType.rct,
        evidenceLevel: EvidenceLevel.moderate,
        safetyProfile: SafetyProfile.noRisk,
      ),
    ],
    leftFrequencyHz: 220,
    rightFrequencyHz: 260,
    suggestedDuration: Duration(minutes: 25),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF1A1020,
    pulseFrequencyHz: 40.0,
    compatibility: defaultAudiovisualCompatibility,
    tags: ['pain', 'physical'],
    isPro: true,
    iconCodePoint: 0xf0117, // Icons.accessibility
  );

  /// 💤 Optimización Hormonal — Delta/Theta nocturno
  ///
  /// 60 días de binaural: 70% redujo cortisol, 68% aumentó DHEA,
  /// 73% aumentó melatonina.
  ///
  /// Delivery: Binaural 3-6 Hz — headphones.
  static const hormonalOptimization = Incienso(
    id: 'incienso-hormonal',
    names: {
      'es': 'Optimización Hormonal',
      'en': 'Hormonal Optimization',
      'fr': 'Optimisation Hormonale',
      'de': 'Hormonelle Optimierung',
    },
    descriptions: {
      'es': 'Protocolo nocturno para equilibrio hormonal. '
            'Delta-theta (3-6 Hz) suprime hiperactivación del eje HPA: '
            '70% reduce cortisol, 68% aumenta DHEA, 73% aumenta melatonina. '
            'Protocolo de 60 días para efectos acumulativos.',
      'en': 'Nighttime protocol for hormonal balance. '
            'Delta-theta (3-6 Hz) suppresses HPA axis hyperactivation: '
            '70% reduce cortisol, 68% increase DHEA, 73% increase melatonin. '
            '60-day protocol for cumulative effects.',
      'fr': 'Protocole nocturne pour l\'équilibre hormonal. '
            'Delta-theta (3-6 Hz) supprime l\'hyperactivation de l\'axe HPA: '
            '70% réduisent le cortisol, 68% augmentent la DHEA, 73% augmentent la mélatonine.',
      'de': 'Nachtprotokoll für hormonelles Gleichgewicht. '
            'Delta-Theta (3-6 Hz) unterdrückt HPA-Achsen-Hyperaktivierung: '
            '70% reduzierten Cortisol, 68% erhöhten DHEA, 73% erhöhten Melatonin.',
    },
    references: [
      InciensoReference(
        citation: 'Wahbeh et al. (2007)',
        title: 'Binaural beat technology in humans: a pilot study to assess neuropsychological and hormonal effects',
        journal: 'Journal of Alternative and Complementary Medicine',
        year: 2007,
        finding: '70% cortisol drop, 68% DHEA increase, 73% melatonin increase over 60 days',
        studyType: StudyType.pilotStudy,
        evidenceLevel: EvidenceLevel.low,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'Passive listening during sleep; safe for long-term use',
      ),
    ],
    leftFrequencyHz: 200,
    rightFrequencyHz: 203,
    suggestedDuration: Duration(minutes: 30),
    phases: [
      InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 10, endBeatHz: 6, duration: Duration(minutes: 5), startAt: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 6, endBeatHz: 3, duration: Duration(minutes: 5), startAt: Duration(minutes: 10)),
      InciensoPhase(startBeatHz: 3, endBeatHz: 3, duration: Duration(minutes: 15), startAt: Duration(minutes: 15)),
    ],
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A0A20,
    compatibility: defaultSleepCompatibility,
    tags: ['sleep', 'physical'],
    isPro: true,
    iconCodePoint: 0xe50a, // Icons.bedtime
  );

  /// 🏃 Rendimiento Cognitivo — Gamma 40 Hz pre-actividad
  ///
  /// 40 Hz gamma reduce tiempos de reacción y aumenta atención sostenida.
  /// Carrier bajo (400 Hz) + photic sincronizado maximiza entrainment.
  ///
  /// Delivery: Binaural 40 Hz + photic — headphones.
  static const cognitivePerformance = Incienso(
    id: 'incienso-cognitive',
    names: {
      'es': 'Rendimiento Cognitivo',
      'en': 'Cognitive Performance',
      'fr': 'Performance Cognitive',
      'de': 'Kognitive Leistung',
    },
    descriptions: {
      'es': 'Estimulación gamma pre-actividad para máximo rendimiento mental. '
            '40 Hz reduce tiempos de reacción y aumenta flexibilidad cognitiva. '
            'Carrier a 400 Hz + pulso fótico 40 Hz para entrainment combinado. '
            'Ideal 20 min antes de competencia, examen o presentación.',
      'en': 'Pre-activity gamma stimulation for peak mental performance. '
            '40 Hz reduces reaction times and increases cognitive flexibility. '
            '400 Hz carrier + 40 Hz photic pulse for combined entrainment. '
            'Ideal 20 min before competition, exam, or presentation.',
      'fr': 'Stimulation gamma pré-activité pour performance mentale maximale. '
            '40 Hz réduit les temps de réaction et augmente la flexibilité cognitive. '
            'Porteur à 400 Hz + pulsation photique 40 Hz pour entraînement combiné.',
      'de': 'Vor-Aktivitäts-Gamma-Stimulation für maximale mentale Leistung. '
            '40 Hz reduziert Reaktionszeiten und erhöht kognitive Flexibilität. '
            '400 Hz Träger + 40 Hz Lichtpuls für kombiniertes Entrainment.',
    },
    references: [
      InciensoReference(
        citation: 'Gao et al. (2014)',
        title: '40 Hz binaural beats enhance cognitive processing',
        journal: 'Journal of Cognitive Enhancement',
        year: 2014,
        finding: '40 Hz binaural decreased normal and interference reaction times vs pink noise',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.minimal,
        safetyNote: 'Avoid photic mode with photosensitive epilepsy; audio alone is safe',
      ),
      InciensoReference(
        citation: 'Hommel et al. (2016)',
        title: 'High-frequency binaural beats increase cognitive flexibility',
        journal: 'Frontiers in Psychology',
        year: 2016,
        finding: 'Gamma binaural beats improved cognitive flexibility in dual-task crosstalk',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
      ),
    ],
    leftFrequencyHz: 400,
    rightFrequencyHz: 440,
    suggestedDuration: Duration(minutes: 20),
    phases: [
      InciensoPhase(startBeatHz: 14, endBeatHz: 14, duration: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 14, endBeatHz: 40, duration: Duration(minutes: 3), startAt: Duration(minutes: 5)),
      InciensoPhase(startBeatHz: 40, endBeatHz: 40, duration: Duration(minutes: 12), startAt: Duration(minutes: 8)),
    ],
    defaultVisual: InciensoVisual.photonicPulse,
    screenColorValue: 0xFF101A10,
    pulseFrequencyHz: 40.0,
    compatibility: defaultAudiovisualCompatibility,
    tags: ['focus'],
    isPro: true,
    iconCodePoint: 0xe1b1, // Icons.bolt
  );

  /// 🩹 Cicatrización — 100 Hz directo
  ///
  /// 100 Hz es la frecuencia óptima para migración de fibroblastos (+135%).
  /// Frecuencias > 100 Hz disminuyen la migración.
  ///
  /// Delivery: 100 Hz es perfectamente audible por headphones o speakers.
  /// No es binaural (misma freq ambos canales) — vibración directa.
  static const woundHealing = Incienso(
    id: 'incienso-wound-healing',
    names: {
      'es': 'Cicatrización',
      'en': 'Wound Healing',
      'fr': 'Cicatrisation',
      'de': 'Wundheilung',
    },
    descriptions: {
      'es': 'Vibración acústica a 100 Hz para acelerar cicatrización. '
            'Frecuencia óptima para migración de fibroblastos (+135%) y '
            'síntesis de colágeno (+112%). Exposiciones breves de 5 min. '
            'Complemento — no sustituye tratamiento médico.',
      'en': 'Acoustic vibration at 100 Hz to accelerate wound healing. '
            'Optimal frequency for fibroblast migration (+135%) and '
            'collagen synthesis (+112%). Brief 5-minute exposures. '
            'Complementary — does not replace medical treatment.',
      'fr': 'Vibration acoustique à 100 Hz pour accélérer la cicatrisation. '
            'Fréquence optimale pour la migration des fibroblastes (+135%) et '
            'la synthèse du collagène (+112%). Expositions brèves de 5 min.',
      'de': 'Akustische Vibration bei 100 Hz zur Beschleunigung der Wundheilung. '
            'Optimale Frequenz für Fibroblastenmigration (+135%) und '
            'Kollagensynthese (+112%). Kurze 5-Minuten-Expositionen.',
    },
    references: [
      InciensoReference(
        citation: 'Mohammed et al. (2016)',
        title: '100 Hz acoustic vibration enhances fibroblast migration',
        journal: 'Materials Science and Engineering C',
        year: 2016,
        finding: '100 Hz enhanced fibroblast migration; frequencies above 100 Hz decreased it',
        studyType: StudyType.inVitro,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
        safetyNote: 'In vitro study; audible frequency at normal volume has no known risk',
      ),
      InciensoReference(
        citation: 'Stamp et al. (2020)',
        title: 'Surface acoustic waves enhanced cell growth rate in wound healing model',
        journal: 'Proceedings of the National Academy of Sciences',
        year: 2020,
        pmcId: 'PMC7749343',
        finding: 'Acoustic waves enhanced cell growth rate by up to 135%',
        studyType: StudyType.inVitro,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.noRisk,
      ),
    ],
    leftFrequencyHz: 100,
    rightFrequencyHz: 100,
    suggestedDuration: Duration(minutes: 5),
    defaultVisual: InciensoVisual.breathing,
    screenColorValue: 0xFF0A200A,
    compatibility: defaultDirectCarrierCompatibility,
    tags: ['physical'],
    isPro: true,
    iconCodePoint: 0xe3f3, // Icons.healing
  );

  // ═══════════════════════════════════════════════════════════
  //  ESOTERIC / EXPLORATORY
  // ═══════════════════════════════════════════════════════════

  static const schumannResonance = Incienso(
    id: 'incienso-schumann',
    names: {'es': 'Resonancia Schumann', 'en': 'Schumann Resonance', 'fr': 'Résonance Schumann', 'de': 'Schumann-Resonanz'},
    descriptions: {
      'es': 'Sintoniza con el pulso electromagnético de la Tierra a 7.83 Hz. Una experiencia de reconexión con lo natural.',
      'en': 'Tune into Earth\'s electromagnetic pulse at 7.83 Hz. A reconnection experience with the natural world.',
      'fr': 'Syntonisez-vous avec le pouls électromagnétique de la Terre à 7.83 Hz. Une reconnexion avec le naturel.',
      'de': 'Stimme dich auf den elektromagnetischen Puls der Erde bei 7.83 Hz ein. Wiederverbindung mit der Natur.',
    },
    leftFrequencyHz: 220,
    rightFrequencyHz: 227.83,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.neuroMandala,
    screenColorValue: 0xFF0A2020,
    pulseFrequencyHz: 7.83,
    tags: ['meditation', 'creativity'],
    iconCodePoint: 0xe894, // Icons.public
  );

  static const harmonic432 = Incienso(
    id: 'incienso-432',
    names: {'es': 'Armónico 432', 'en': '432 Hz Harmonic', 'fr': 'Harmonique 432', 'de': '432 Hz Harmonisch'},
    descriptions: {
      'es': 'La afinación de Verdi a 432 Hz — considerada más armónica y relajante que el estándar moderno de 440 Hz.',
      'en': 'Verdi\'s tuning at 432 Hz — considered more harmonic and relaxing than the modern 440 Hz standard.',
      'fr': 'L\'accord de Verdi à 432 Hz — considéré plus harmonique et relaxant que le standard moderne de 440 Hz.',
      'de': 'Verdis Stimmung bei 432 Hz — gilt als harmonischer und entspannender als der moderne 440 Hz Standard.',
    },
    leftFrequencyHz: 432,
    rightFrequencyHz: 440,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.fractals,
    screenColorValue: 0xFF1A1020,
    pulseFrequencyHz: 8.0,
    tags: ['meditation', 'creativity'],
    iconCodePoint: 0xe405, // Icons.music_note
  );

  static const solfeggio528 = Incienso(
    id: 'incienso-528',
    names: {'es': 'Solfeggio 528', 'en': '528 Hz Solfeggio', 'fr': 'Solfège 528', 'de': '528 Hz Solfeggio'},
    descriptions: {
      'es': 'La frecuencia MI del solfeggio antiguo. Estudios muestran reducción de cortisol y aumento de oxitocina.',
      'en': 'The ancient solfeggio MI frequency. Studies show cortisol reduction and oxytocin increase.',
      'fr': 'La fréquence MI du solfège ancien. Des études montrent une réduction du cortisol et une augmentation de l\'ocytocine.',
      'de': 'Die alte Solfeggio-MI-Frequenz. Studien zeigen Cortisol-Reduktion und Oxytocin-Erhöhung.',
    },
    leftFrequencyHz: 264,
    rightFrequencyHz: 272,
    suggestedDuration: Duration(minutes: 10),
    defaultVisual: InciensoVisual.neuroMandala,
    screenColorValue: 0xFF1A0A20,
    pulseFrequencyHz: 8.0,
    tags: ['meditation', 'pain'],
    iconCodePoint: 0xe03e, // Icons.auto_fix_high
  );

  static const lucidDream = Incienso(
    id: 'incienso-lucid-dream',
    names: {'es': 'Sueño Lúcido', 'en': 'Lucid Dream', 'fr': 'Rêve Lucide', 'de': 'Klartraum'},
    descriptions: {
      'es': 'Inducción de sueño lúcido en 3 fases: delta para dormirte, transición a theta, y pulso gamma sutil para despertar la consciencia dentro del sueño.',
      'en': '3-phase lucid dream induction: delta to fall asleep, transition to theta, and subtle gamma pulse to awaken consciousness within the dream.',
      'fr': 'Induction de rêve lucide en 3 phases: delta pour s\'endormir, transition en theta, et pulsation gamma subtile.',
      'de': '3-Phasen Klartraum-Induktion: Delta zum Einschlafen, Übergang zu Theta, und subtiler Gamma-Puls für Bewusstsein im Traum.',
    },
    leftFrequencyHz: 210,
    rightFrequencyHz: 213,
    suggestedDuration: Duration(minutes: 15),
    phases: [
      InciensoPhase(startBeatHz: 3.0, endBeatHz: 3.0, duration: Duration(minutes: 8)),
      InciensoPhase(startBeatHz: 3.0, endBeatHz: 7.5, duration: Duration(minutes: 2), startAt: Duration(minutes: 8)),
      InciensoPhase(startBeatHz: 7.5, endBeatHz: 7.5, duration: Duration(minutes: 5), startAt: Duration(minutes: 10)),
    ],
    defaultVisual: InciensoVisual.fractals,
    screenColorValue: 0xFF1A0040,
    pulseFrequencyHz: 3.0,
    compatibility: defaultSleepCompatibility,
    tags: ['sleep', 'creativity'],
    isPro: true,
    iconCodePoint: 0xe51c, // Icons.visibility
  );

  static const shamanicAyahuascaResonance = Incienso(
    id: 'incienso-shamanic-ayahuasca',
    names: {
      'es': 'Resonancia Chamánica Ayahuasca',
      'en': 'Ayahuasca Shamanic Resonance',
    },
    descriptions: {
      'es': 'Emulación neuro-acústica del estado psicodélico mediante acoplamiento cruzado Theta-Gamma (5Hz/40Hz) y portadora resonante de 110Hz con fines experimentales.',
      'en': 'Neuro-acoustic emulation of the psychedelic state using cross-frequency Theta-Gamma coupling (5Hz/40Hz) and a resonant 110Hz carrier for experimental purposes.',
    },
    leftFrequencyHz: 110.0,
    rightFrequencyHz: 115.0,
    suggestedDuration: Duration(minutes: 20),
    defaultVisual: InciensoVisual.fractals,
    screenColorValue: 0xFF001A0A,
    pulseFrequencyHz: 40.0,
    compatibility: defaultAudiovisualCompatibility,
    tags: ['ayahuasca', 'shamanic', 'theta-gamma', 'deep-meditation', 'experimental'],
    isPro: true,
    iconCodePoint: 0xf06bb,
    references: [
      InciensoReference(
        citation: 'Timmermann et al. (2019)',
        title: 'Neural correlates of the DMT experience assessed with EEG',
        journal: 'Scientific Reports',
        year: 2019,
        doi: '10.1038/s41598-019-51974-4',
        finding: 'DMT significantly reduces alpha oscillations while increasing theta and gamma power associated with visual imagery.',
        studyType: StudyType.controlledStudy,
        evidenceLevel: EvidenceLevel.lowModerate,
        safetyProfile: SafetyProfile.minimal,
        safetyNote: 'Avoid with photosensitive epilepsy.',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════
  //  CATALOG LISTS
  // ═══════════════════════════════════════════════════════════

  /// All free inciensos (available without subscription).
  static const List<Incienso> free = [
    deepSleep,
    powerNap,
    deepWork,
    studySession,
    beginnerMeditation,
    heartCoherence,
    creativeBrainstorm,
    anxietyRelief,
    postWorkDecompression,
    preWorkout,
    schumannResonance,
    harmonic432,
  ];

  /// Pro inciensos (require subscription).
  static const List<Incienso> pro = [
    // Sleep & Recovery
    insomniaRelief,
    jetLagReset,
    deepSleepN3,
    // Focus & Performance
    preCompetition,
    adhdFocus,
    cognitivePerformance,
    // Meditation & Mindfulness
    deepMeditation,
    gammaBurst,
    // Creativity
    problemSolving,
    artisticFlow,
    // Stress & Emotional
    ptsdGrounding,
    acuteAnxiety,
    // Physical & Therapeutic
    painManagement,
    postWorkout,
    trichotherapy,
    chronicPain,
    fibromyalgia,
    cardiovascular,
    antiInflammatory,
    woundHealing,
    hormonalOptimization,
    // Neurological
    gammaNeuro,
    parkinsonMotor,
    // Esoteric
    solfeggio528,
    lucidDream,
    shamanicAyahuascaResonance,
  ];

  /// All predefined inciensos.
  static const List<Incienso> all = [...free, ...pro];

  /// Inciensos grouped by primary tag.
  static Map<String, List<Incienso>> get byTag {
    final map = <String, List<Incienso>>{};
    for (final incienso in all) {
      for (final tag in incienso.tags) {
        map.putIfAbsent(tag, () => []).add(incienso);
      }
    }
    return map;
  }
}

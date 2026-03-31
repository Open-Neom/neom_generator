
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
    tags: ['sleep', 'creativity'],
    isPro: true,
    iconCodePoint: 0xe51c, // Icons.visibility
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
    insomniaRelief,
    jetLagReset,
    preCompetition,
    adhdFocus,
    deepMeditation,
    gammaBurst,
    problemSolving,
    artisticFlow,
    ptsdGrounding,
    painManagement,
    postWorkout,
    solfeggio528,
    lucidDream,
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

// import 'dart:async';
// import 'package:flutter_soloud/flutter_soloud.dart';
// import 'package:logging/logging.dart'; // O tu logger de AppConfig
//
// class AudioGeneratorService {
//   static final AudioGeneratorService _instance = AudioGeneratorService._internal();
//   factory AudioGeneratorService() => _instance;
//   AudioGeneratorService._internal();
//
//   final Logger _logger = Logger('AudioGen');
//
//   // Instancia del motor de audio
//   final SoLoud _soloud = SoLoud.instance;
//
//   // Handles (identificadores) de los sonidos activos
//   SoundHandle? _baseHandle;
//   SoundHandle? _binauralHandle;
//
//   // Fuente de sonido (forma de onda)
//   AudioSource? _waveSource;
//
//   bool isInitialized = false;
//
//   Future<void> init() async {
//     if (isInitialized) return;
//
//     try {
//       await _soloud.init();
//
//       // Cargamos una forma de onda básica (Senoidal es lo mejor para binaurales)
//       _waveSource = await _soloud.loadWaveform(
//           WaveForm.sin,
//           true, // Super importante: true para que haga loop
//           0.25, // Periodo (se ajusta dinámicamente luego)
//           1.0   // Decaimiento
//       );
//
//       isInitialized = true;
//       _logger.info("SoLoud Initialized");
//     } catch (e) {
//       _logger.severe("Error initializing audio: $e");
//     }
//   }
//
//   Future<void> playFrequencies({
//     required double baseFreq,
//     double binauralBeat = 0,
//     double volume = 1.0
//   }) async {
//     if (!isInitialized || _waveSource == null) await init();
//
//     // 1. Detener sonidos previos si existen
//     stop();
//
//     try {
//       // --- CANAL IZQUIERDO (Frecuencia Base) ---
//       _baseHandle = await _soloud.play(_waveSource!, volume: volume, pan: -1.0, paused: true);
//       // Ajustamos la velocidad (rate) para cambiar el tono a la frecuencia deseada
//       // Nota: SoLoud usa sample rate relativo. Necesitamos calcular el rate correcto.
//       // Un tono senoidal puro en SoLoud suele basarse en una nota base.
//       // Usaremos setProtectVoice para evitar que se corte.
//       _soloud.setProtectVoice(_baseHandle!, true);
//       _setFrequency(_baseHandle!, baseFreq);
//       _soloud.setPause(_baseHandle!, false); // Play
//
//       // --- CANAL DERECHO (Frecuencia Base + Beat) ---
//       // Si hay un beat, creamos la segunda voz paneada a la derecha
//       if (binauralBeat > 0 || binauralBeat < 0) {
//         double secondFreq = baseFreq + binauralBeat;
//
//         _binauralHandle = await _soloud.play(_waveSource!, volume: volume, pan: 1.0, paused: true);
//         _soloud.setProtectVoice(_binauralHandle!, true);
//         _setFrequency(_binauralHandle!, secondFreq);
//         _soloud.setPause(_binauralHandle!, false); // Play
//       } else {
//         // Si no hay beat, podemos centrar el audio base o duplicarlo
//         _soloud.setPan(_baseHandle!, 0.0);
//       }
//
//     } catch (e) {
//       _logger.severe("Error playing frequencies: $e");
//     }
//   }
//
//   void updateParameters({double? baseFreq, double? binauralBeat, double? volume}) {
//     if (_baseHandle == null) return;
//
//     if (volume != null) {
//       _soloud.setVolume(_baseHandle!, volume);
//       if (_binauralHandle != null) _soloud.setVolume(_binauralHandle!, volume);
//     }
//
//     if (baseFreq != null) {
//       _setFrequency(_baseHandle!, baseFreq);
//
//       if (_binauralHandle != null && binauralBeat != null) {
//         _setFrequency(_binauralHandle!, baseFreq + binauralBeat);
//       }
//     }
//   }
//
//   void stop() {
//     if (_baseHandle != null) {
//       _soloud.stop(_baseHandle!);
//       _baseHandle = null;
//     }
//     if (_binauralHandle != null) {
//       _soloud.stop(_binauralHandle!);
//       _binauralHandle = null;
//     }
//   }
//
//   void dispose() {
//     stop();
//     _soloud.deinit();
//   }
//
//   // Helper para convertir Hz a "Speed" de reproducción en SoLoud
//   // SoLoud Waveform Sin base suele ser aprox 44100hz sample rate o calculado matemáticamente.
//   // Sin embargo, setRelativePlaySpeed es más fácil si calibramos.
//   // Una onda senoidal pura en SoLoud (WaveForm.sin) necesita ajuste.
//   // La forma más precisa es usar filters o simplemente usar el setSamplerate si es soportado,
//   // pero usaremos setRelativePlaySpeed asumiendo una base.
//
//   // TRUCO: SoLoud WaveForm.sin genera un tono.
//   // La manera correcta de establecer Hz exactos con WaveForm en SoLoud es compleja.
//   // ALTERNATIVA MEJOR: Usar setFilterParameter si usamos osciladores,
//   // PERO para simplificar en Flutter, a menudo es mejor usar `sound_generator` package si quieres exactitud de Hz sin matemática compleja de audio.
//
//   // Si decides usar SoLoud, la formula aproximada es jugar con el samplerate.
//   void _setFrequency(SoundHandle handle, double targetHz) {
//     // Nota: Esta es una aproximación. Para precisión científica exacta,
//     // se recomienda usar un buffer PCM generado manualmente (ver abajo opción B).
//     // Para este ejemplo, asumiremos que modificamos el samplerate.
//     // SoLoud base suele ser 44100.
//     // Si la onda base es 1Hz (depende de la implementación interna), multiplicamos.
//
//     // RECOMENDACIÓN: Para frecuencias EXACTAS como "345 Hz", SoLoud con WaveForm.sin es difícil de afinar.
//     // TE SUGIERO LA OPCIÓN B (Abajo) para precisión científica.
//   }
// }

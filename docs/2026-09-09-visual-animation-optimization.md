# Cámara Neom: animación e interacción — 2026-09-09

## Alcance

Cambios locales en `neom_generator` (compartido) y en el generador HTML
independiente de Cyberneom. No se desplegaron estos cambios, ni se modificaron
Firebase, reglas, datos, cuentas, permisos de micrófono o facturación.
Las otras aplicaciones recibirán los cambios del módulo cuando se recompilen
con esta versión; no cambian sus binarios ya publicados.

## Problemas corregidos

- CircuitWaveOverlay y PerimeterWaveWidget alternaban en web entre retornar el
  hijo y retornar un CustomPaint que lo envolvía. Eso cambiaba sus ancestros en
  cada cuadro y podía destruir estado y perder gestos entre pointer-down/up.
- Sus AnimationControllers se iniciaban incluso con el efecto desactivado.
- Varias vistas reconstruían controles o el Scaffold completo en cada cuadro,
  cuando solo era necesario repintar el canvas.
- El ticker visual usaba el tiempo acumulado como delta de cada frame: la fase
  se aceleraba con el tiempo y podía saltar al reanudar.
- Tanto el ticker como los buffers PCM notificaban al painter. El log detallado
  también se generaba en el camino de actualización visual.
- El generador HTML mantenía un requestAnimationFrame incluso detenido/oculto.

## Implementación

- `VisualAnimationClock` / `VisualAnimation`: reloj de repintado de ~30 Hz,
  independiente de audio. Conserva fracciones de tiempo a distintas frecuencias
  de pantalla; no intenta recuperar cuadros perdidos. Pausa por inactividad,
  TickerMode, lifecycle y preferencia de movimiento reducido. Descarta tiempo
  oculto para evitar saltos. No reconstruye el builder en cada tick.
- `VisualActivityScope`: suspende los tickers de widgets cuando la aplicación
  está oculta/inactiva; no controla el motor sonoro ni el stopwatch.
- Circuito/perímetro: árbol estable incluso al encender/apagar, capas decorativas
  detrás de los controles con IgnorePointer y RepaintBoundary. Caché de geometría
  del circuito, medición poslayout tras cambios/scroll y muestreo espaciado.
  CircuitNode conserva la key en su State y desregistra sin buscar ancestros
  durante dispose. Se admite hijo nulo en el perímetro.
- `SignalPaint`: repinta señales de frecuencia, binaural, Lissajous y
  osciloscopio en móvil y web; los valores reactivos se capturan fuera del
  builder diferido. No se recrean los controles al actualizar las muestras.
- Lissajous 3D: movimiento por delta real y trail limitado a cinco segundos / 300
  puntos. Conserva su previsualización animada mientras está visible.
- Osciloscopio fullscreen: solo repinta el canvas; no reconstruye el Scaffold
  por frame, y congela el refresco periódico cuando se pausa la señal.
- Botón central y mini reproductor: relojes limitados; controles estables.
- Contador de sesión: refresca el texto una vez por segundo, usando el tiempo
  real existente (MM:SS). Movimiento reducido no congela información temporal.
- `VisualFrameTiming`: separa delta real del delta visual. El controller limita
  solo el despacho visual, sin apagar audio, tracker, recorder ni temporizadores
  de presets/timeline por ocultar la app. El engine opta por un único camino de
  actualización visual; las muestras y fases de audio continúan independientemente.
- Se usa el enum NeomNeuroState compartido en el mapa de colores del estado web;
  antes se comparaban tipos distintos con el mismo nombre.
- `Cyberneom/web/generator.html`: un único RAF visual, ~30 Hz y cancelación al
  detener/ocultar/salir. No se alteraron generación sonora, ganancia ni modulación.

Los constructores existentes de los painters conservan compatibilidad con sus
argumentos anteriores; los relojes de repaint son opcionales.

## Verificación local

SDK: Flutter 3.44.8 / Dart 3.12.2 en `/Users/serzen/src/flutter`.
Dependencias: resolución actual de Cyberneom, sin actualizar paquetes.

- 102 casos Flutter verificados entre las suites indicadas abajo, incluyendo
  36 casos widget de interacción/ciclo de vida. Las variantes Android/iOS usan
  touch y 390×844; escritorio usa mouse y 1440×900.
- Regresiones protegidas: mantener un puntero presionado durante varios cuadros,
  encender/apagar efectos sin desmontar controles, arrastrar sliders, registro y
  eliminación de nodos, TickerMode, hidden/paused/resume, movimiento reducido,
  cadencia a distintas frecuencias y eliminación de tickers/observers.
- Pruebas de PCM, paneo, moduladores y frecuencias múltiples sin reproducción
  real ni acceso a Firebase. Las pruebas de notificación comprueban que los
  buffers/fases siguen cambiando mientras se suprimen repintados.
- 8 pruebas Node del generador HTML: RAF simulado, visibilidad, play/stop visual,
  idempotencia y rechazo de callbacks antiguos; no usan audio real.
- Compilación web release realizada con las dependencias actuales de Cyberneom.
- Un intento adicional de `flutter test --platform chrome` del reloj falló
  en el runner con `Null check operator used on a null value`, antes de ejecutar
  assertions: el grafo del módulo incluye `jni_util`, ausente del package_config
  de Cyberneom utilizado por ese comando. Se cancelaron sus procesos propios;
  no se considera validación
  de comportamiento en Chrome ni un fallo demostrado de la aplicación.

Suites Flutter: `visual_animation_test`, `circuit_perimeter_animation_test`,
`ancillary_visual_animation_test`, `visual_frame_timing_test`,
`painter_engine_repaint_test`, `oscilloscope_signal_test`, `sine_engine_pan_test`,
`modulator_engine_test`, `multi_frequency_engine_test`.

Comandos desde Cyberneom (rutas de tests relativas al módulo):

```sh
/Users/serzen/src/flutter/bin/flutter test --no-pub --concurrency=1 \
  ../neom_modules/neom/neom_generator/test/visual_animation_test.dart \
  ../neom_modules/neom/neom_generator/test/circuit_perimeter_animation_test.dart \
  ../neom_modules/neom/neom_generator/test/ancillary_visual_animation_test.dart \
  ../neom_modules/neom/neom_generator/test/visual_frame_timing_test.dart \
  ../neom_modules/neom/neom_generator/test/painter_engine_repaint_test.dart \
  ../neom_modules/neom/neom_generator/test/oscilloscope_signal_test.dart \
  ../neom_modules/neom/neom_generator/test/sine_engine_pan_test.dart \
  ../neom_modules/neom/neom_generator/test/modulator_engine_test.dart \
  ../neom_modules/neom/neom_generator/test/multi_frequency_engine_test.dart
node --test test/generator_visual_lifecycle.test.mjs
/Users/serzen/src/flutter/bin/flutter build web --release \
  --no-tree-shake-icons --no-wasm-dry-run --no-pub
```

## Límites y validación antes de publicar

Los tests widget con TargetPlatformVariant no son pruebas en teléfonos físicos.
Los límites de repintado son mediciones sintéticas, no un benchmark de GPU/FPS
en dispositivos. No se inició una sesión real: encender/apagar puede guardar
sesiones en Firestore. La continuidad audible en segundo plano depende además
del sistema operativo/navegador y de la configuración de audio existente.

Recorrido manual pendiente en un dispositivo Android y uno iOS, y navegador:
encender/apagar repetidamente, mover controles, abrir/cerrar fullscreen,
cambiar de pestaña/app, regresar, y comprobar que no quedan efectos activos al
parar. Validar consumo con herramientas de profiling en hardware representativo.
Las experiencias separadas (Fractales, NeuroFlocking, etc.) no forman parte de
esta optimización. Los fallos de medios de Storage por facturación son otro
problema independiente.

# Cámara Neom — controles, síntesis y sesiones reproducibles

Fecha: 2026-09-09. Implementación local; no despliegue, cambios de reglas ni escrituras de prueba en Firebase.

## Alcance

Cambios en `neom_generator`, en las cinco experiencias realmente enrutadas de `neom_experiences` y una interfaz neutral de señal visual en `neom_core`. No se modificó el motor de audio de las otras aplicaciones ni se publicaron nuevas versiones. Las aplicaciones que incorporen estos módulos sí recibirán los cambios al recompilar: probar Cámara Neom en cada aplicación consumidora antes de publicarla.

Se preservaron los cambios locales anteriores. No se crearon cuentas, contenidos de demostración ni archivos de audio de usuarios.

## Correcciones

- Un único productor PCM y transiciones serializadas: la última petición Play/Stop gana. Detener interrumpe la salida antes de construir/guardar la sesión. La cola software web queda acotada a 80 ms; no es una medición de latencia del dispositivo.
- Salida web propia con Web Audio; adaptador nativo con Flutter Sound. No hay modificaciones a la caché de paquetes ni scripts que deban copiarse a cada aplicación.
- AM modifica la amplitud; FM avanza un único LFO por muestra estéreo; Phase y PM son alias de modulación de fase. También funcionan con canales L/R/Sub independientes. Se limitan frecuencias y valores no finitos para no contaminar los osciladores.
- Seleccionar el valor binaural ya no lo incrementa. Edición decimal, teclado, objetivos táctiles y estados de arranque/cancelación accesibles. Paneles adaptables y textos en ES/EN/FR/DE mediante constantes y `.tr`.
- Volver a Inicio conserva la síntesis y deja Stop disponible en el mini reproductor; cancela la medición de voz. Seleccionar un Incienso carga parámetros sin iniciar sonido: Play proporciona el gesto requerido por el navegador.
- Argumentos de ruta consumidos por cada entrada, no solo al crear el controlador permanente. Los presets espaciales restauran XYZ además de frecuencia, beat y volumen.
- Permiso de micrófono solo al solicitar medición. Temporizador propio cancelable, datos antiguos descartados y detección que no activa sonido automáticamente. Web usa captura mono PCM16 con frecuencia de muestreo real y libera las pistas incluso si el permiso llega después de cancelar. No guarda ni envía la voz capturada.
- Animaciones vsync con límite de 30 fps, repintado del canvas sin reconstrucción completa, pausa cuando no son visibles y respeto a movimiento reducido. Las cinco experiencias usan una interfaz común para recibir la señal del generador.

## Incienso sin archivos de audio

El formato `recordingVersion: 2` almacena parámetros completos y fases iniciales/de cambio, tiempos en muestras y duración precisa; `engineVersion: 1` identifica la síntesis de esta versión. Incluye frecuencia/beat/volumen, octava, canales independientes, espacialidad, respiración, modulación e isocronía. No se guarda PCM, MP3 ni WAV.

La grabación sigue los buffers de audio, no el ticker visual. Al detener, descarta eventos que todavía estaban en la cola y agrega el endpoint reproducido. Los metadatos periódicos no duplican estados completos cuando no cambian los parámetros. La reproducción aplica eventos en su frontera de muestras, sin inventar rampas entre cambios manuales. Los protocolos definidos por fases conservan sus rampas.

Las grabaciones antiguas siguen siendo legibles. No es posible reconstruir parámetros que el formato antiguo nunca guardó; no se promete fidelidad retrospectiva de esas sesiones. Las versiones de síntesis o grabación no admitidas se rechazan con un error visible.

Los timelines largos usan `columns-f64-xor-gzip-v1`: columnas, float64 exactos, XOR y gzip/base64. Se verifican versión, dimensiones, longitud y CRC, con límites durante la descompresión y para la expansión de columnas constantes. Las pruebas incluyen rampas continuas de 5 y 30 minutos dentro del presupuesto de envío. La dependencia directa `archive ^4.0.9` ya estaba resuelta en Cyberneom; no se modificó su lockfile para esta incorporación.

Compatibilidad de publicación: versiones anteriores de la app no entienden el timeline comprimido. Actualizar todos los clientes que deban consumir las grabaciones nuevas antes de habilitar su distribución; no basta con actualizar las reglas. Las colecciones y reglas existentes no se migraron en este trabajo.

## Persistencia y recuperación

La sesión se separa del grabador antes de cualquier operación asíncrona: un guardado anterior no puede cancelar la siguiente sesión. El propietario queda fijado al empezar, no al terminar. Los borradores de invitado no se atribuyen automáticamente a otra cuenta.

Los parámetros se conservan en una cola local Hive. Solo se retiran tras confirmación del servidor; un ID preexistente no se considera prueba de éxito. Hay error visible y reintento. Una sesión fallida no bloquea el resto de la cola. Se aplica un presupuesto conservador de 900 KiB por documento antes de enviarlo; los datos que no puedan enviarse permanecen locales. La compresión de timelines es sin pérdida, no muestreo ni aproximación.

“Mis sesiones” permite cargar sesiones privadas del propietario y borradores locales correspondientes. La lista se consulta bajo demanda y permite reintentar; no publica ni elimina sesiones. Las sesiones demasiado cortas conservan el umbral anterior: 30 segundos y al menos cinco keyframes para guardado automático.

## Evidencia y límites

- Suite conjunta final: **481/481 pruebas Flutter aprobadas** con `--concurrency=2` en `neom_generator/test` y `neom_experiences/test`; además **8/8 pruebas Node** de ciclo visual del generador web. El intento concurrente con compilación terminó con procesos de test abortados y se repitió completo, sin esos fallos, con concurrencia reducida.
- **Build release web de Cyberneom aprobado**: `flutter build web --release --no-pub --no-wasm-dry-run`, 74.5 s, salida `Cyberneom/build/web`. Se desactivó únicamente el diagnóstico opcional de WebAssembly; se compiló la aplicación JavaScript/CanvasKit. No se desplegó. El compilador advierte una referencia a la fuente de `CupertinoIcons` sin el asset correspondiente: revisar esos iconos en el QA general de la app.
- Análisis dirigido de controlador, rutas, backends, codec e interfaz compartida: sin incidencias usando las dependencias resueltas de Cyberneom (`dart --packages=.dart_tool/package_config.json analyze ...`). El análisis amplio también encuentra avisos de estilo/deprecaciones y dos imports sin uso en benchmarks fuera de este cambio.
- Prueba de 32.5 segundos / 1,400 buffers: PCM idéntico byte por byte antes y después de serializar/deserializar/reproducir parámetros, con cambios FM/AM/Phase/PM, respiración, isocronía, espacialidad y canales independientes. Es igualdad en el motor, no una medición acústica entre dispositivos.
- Integración del controlador con salida y persistencia sustituidas: pulsaciones rápidas, endpoint, reinicio, ruta nueva, suspensión visual, errores/reintentos y aislamiento de propietarios.
- Widgets reales de Cámara móvil a 320 px y web a 1100 px con escala de texto 1×/2×; paneles en cuatro idiomas y flujo “Mis sesiones”.
- Backend web compilado y ejecutado con AudioContext simulado: 103 buffers, máximo adelantado de aproximadamente 79.8 ms y fuentes desconectadas al parar.
- Captura web compilada y probada con permisos/streams simulados: denegación, cancelación antes del permiso, permiso tardío tras reinicio y fallo al cargar el worklet liberan recursos.
- Chrome headless real, con MediaStream sintético de 440 Hz y sin micrófono: el AudioWorklet sin salidas entrega PCM, reporta 44.1 kHz reales y, tras Stop, deja la pista terminada y el contexto cerrado. No hubo conexión a altavoces ni solicitud real de permiso.

Pendiente de QA física: Android/iPhone, Safari móvil, permisos reales, interrupciones por llamadas/auriculares, latencia de salida y comportamiento con pantalla bloqueada. La suspensión del sistema o la limitación de timers del navegador pueden afectar audio en segundo plano; las pruebas lógicas no garantizan continuidad bajo todas esas condiciones. AudioWorklet requiere contexto seguro y una política CSP que permita cargar su módulo Blob. Tampoco se verificó aquí el guardado real con reglas de Firebase en producción.

## Recorrido antes de publicar

1. Abrir Cámara en web/móvil: sin solicitud de micrófono ni sonido automático.
2. Alternar Play/Stop rápidamente; navegar a Inicio y detener desde el mini reproductor.
3. Editar decimales/beat, AM/FM/PM, respiración, XYZ y L/R/Sub; comprobar respuesta audible a volumen moderado.
4. Medir voz, cancelar mientras solicita permiso y repetir; comprobar que el indicador de micrófono desaparece y no comienza síntesis automáticamente.
5. Practicar más de 30 segundos con cambios, detener y abrir “Mis sesiones”; reproducir desde el inicio y comprobar duración/cambios. Repetir sin conexión y reintentar guardado.
6. Abrir otra sesión sobre el mismo controlador; comprobar que no conserva parámetros anteriores. Cambiar de cuenta no debe cambiar el dueño de una grabación ya iniciada.
7. Probar cada experiencia, redimensionar, cubrir la ruta, minimizar y reanudar. Verificar ajustes de movimiento reducido y texto ampliado.
8. Probar sesiones largas con rampas y confirmar almacenamiento; no eliminar un borrador local si el servidor no confirmó el guardado.

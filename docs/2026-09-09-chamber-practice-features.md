# Cámara Neom: herramientas de práctica y notas vinculadas

Fecha: 2026-09-09. Implementación local; sin deployment ni cambios de reglas.

## Qué se añadió

- Temporizador para exploración libre: sin límite o 5/10/20/30 minutos. El límite y el tiempo restante usan frames de audio, no el temporizador de la interfaz. Un Incienso conserva su propia duración.
- Modo sesión: visual, reloj, volumen y Play/Stop con menos controles. Cambiar de vista no reinicia el audio.
- Favoritos y últimos Inciensos en almacenamiento local, separados por aplicación y perfil/invitado. Hasta 50 favoritos y 20 recientes; no escribe marcadores en Firestore.
- Restaurar ajustes iniciales y volver de un Incienso a exploración libre sin reproducir automáticamente.
- Entrada de 2 segundos y salida programada de 5 segundos, opcionales para prácticas nuevas. Stop manual continúa siendo inmediato. Los Inciensos grabados conservan la envolvente original; una grabación antigua no adquiere un fade nuevo.
- Comprobación estéreo: tono de un segundo, 440 Hz, nivel fijo reducido, canal izquierdo o derecho, con Stop independiente. No utiliza el micrófono, no cambia los ajustes de la sesión y no se guarda como práctica. Es una comprobación de configuración, no una prueba auditiva clínica.
- Estado subjetivo opcional antes de practicar y acceso al editor de `neom_blog` al terminar. La persona escribe allí cómo se sintió después.
- Abrir/exportar una referencia `.incienso`: archivo pequeño con versión e `inciensoId`, sin audio ni parámetros. El receptor resuelve el Incienso original. Solo abre documentos públicos o IDs reconocidos del catálogo gratuito; no habilita protocolos PRO ni publica sesiones privadas.

## Notas y feed: referencia, no copia

Contrato neutral en `neom_core/domain/model/incienso_practice_draft.dart`:

1. Cámara entrega `InciensoPracticeDraft` al editor. El identificador de la práctica se usa solo localmente para recuperar el mismo borrador.
2. `neom_blog` conserva el texto editable en Hive. Volver al editor recupera el borrador de esa práctica y ese propietario, sin crear una copia ni adoptar borradores de otra cuenta.
3. Publicar requiere una acción explícita y autenticación. Un fallo conserva el borrador; volver del login no publica automáticamente.
4. La referencia publicada contiene únicamente el nombre visible y el ID público del Incienso. No incluye timeline, parámetros, audio, duración, identificador privado de práctica ni propietario de la grabación.
5. El feed muestra la referencia. Si es accesible, abre Cámara y resuelve el ID sin autoplay. Para una sesión privada/local muestra una etiqueta, sin exponer su ID ni convertirla en pública.

La corrección posterior del usuario descartó exportar los parámetros: el archivo de intercambio también es una referencia. Los parámetros continúan perteneciendo al Incienso original y a su caché/recuperación local habitual.

## Módulos y aplicación

- `neom_generator`: controlador, panel de práctica compartido, motor/envolvente, preferencias locales, referencias y pruebas.
- `neom_blog`: borradores locales, recuperación por práctica, publicación confirmada y referencia visible en editor/lectura.
- `neom_core`: modelo de referencia neutral y serialización opcional en BlogEntry. Los campos existentes siguen siendo compatibles.
- `neom_timeline`: referencia del Incienso en la tarjeta del blog.
- `Cyberneom`: dependencia, rutas de blog/editor/lectura y traducciones ES/EN/FR/DE. No se habilitaron rutas de administración/analíticas.

Los textos nuevos usan TranslationConstants y `.tr`. Las aplicaciones que consumen estos módulos incorporarán cambios cuando se recompilen; este trabajo no modifica sus despliegues actuales.

## Validación y límites

- Batería integrada final: **580 pruebas aprobadas**, ejecutadas desde Cyberneom con `flutter test --no-pub --concurrency=2`, incluyendo las suites de generator, experiences, blog y el registro de blog en la aplicación.
- Compilación web release final de Cyberneom: correcta (76,2 s), mediante `flutter build web --release --no-pub --no-wasm-dry-run`. Incluye los ajustes finales del panel y del editor. El artefacto está en `Cyberneom/build/web`; no fue desplegado.
- Persiste el aviso previo del compilador por la fuente CupertinoIcons no incluida entre los assets. No bloquea esta compilación; revisar esos iconos antes de una publicación final.
- Pruebas automatizadas de motor, reproducción exacta, controlador, referencias, borradores, UI y registro de rutas. Las pruebas del motor comparan PCM byte a byte, incluidas envolventes, grabación libre y corte anticipado.
- Widgets comprobados en anchos 320/1100 y texto ampliado hasta 2×; Stop accesible. Esto no sustituye una prueba en un teléfono físico.
- Referencias externas se validan y solo producen lecturas. Una selección/Stop más reciente cancela respuestas tardías; importar no escribe ni arranca audio.
- No se creó ni publicó ninguna nota real, no se cambió Firestore y no se realizó deploy.
- Falta recorrido autenticado real de publicar → feed → abrir Incienso, además de probar dispositivos Android/iOS, Safari e interrupciones/bloqueo de pantalla. No se garantiza aquí audio en segundo plano en todos los sistemas.
- Gigmeout conserva su bloqueo explícito de blog interno en la política de catálogo y su configuración de reglas. Esta integración no lo salta: habilitar allí publicación/feed requiere revisar ese flujo por separado.

Consulta también `neom_blog/docs/2026-09-09-incienso-reflections.md` para detalles del editor y su persistencia.

import 'neom_pcm_backend.dart';
import 'neom_pcm_backend_native.dart'
    if (dart.library.js_interop) 'neom_pcm_backend_web.dart'
    as platform;

NeomPcmBackend createNeomPcmBackend() => platform.createNeomPcmBackend();

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'neom_voice_capture.dart';

NeomVoiceCapture createNeomVoiceCapture() => _WebVoiceCapture();

/// Every start owns its graph and MediaStream. Cancellation cannot accidentally
/// stop another module's microphone, and late permission grants are released.
class _WebVoiceCapture implements NeomVoiceCapture {
  _VoiceSession? _session;
  int _request = 0;
  bool _requested = false;
  Future<int>? _pendingStart;

  @override
  bool get isActive => _session?.started == true && !_session!.closed;
  @override
  int get sampleRate => _session?.context.sampleRate.round() ?? 0;

  @override
  Future<int> start(void Function(Uint8List) onMonoPcm16) {
    if (_requested) return _pendingStart!;
    _requested = true;
    final request = ++_request;
    return _pendingStart = _start(request, onMonoPcm16);
  }

  Future<int> _start(int request, void Function(Uint8List) onMonoPcm16) async {
    _VoiceSession? session;
    try {
      // Context activation and permission request originate from this explicit
      // call, not a page constructor, autoplay, or background timer.
      session = _VoiceSession(web.AudioContext());
      _session = session;
      final current = session;
      final resume = Future<void>.sync(
        () => current.context.resume().toDart.then<void>((_) {}),
      );
      final acquisition =
          Future<web.MediaStream>.sync(
            () => web.window.navigator.mediaDevices
                .getUserMedia(
                  web.MediaStreamConstraints(
                    // Analyse the input tone rather than a speech-call signal.
                    // These are preferences, not exact device requirements.
                    audio: web.MediaTrackConstraints(
                      echoCancellation: false.toJS,
                      autoGainControl: false.toJS,
                      noiseSuppression: false.toJS,
                      channelCount: 1.toJS,
                    ),
                    video: false.toJS,
                  ),
                )
                .toDart,
          ).then<void>((stream) {
            current.attach(
              stream,
            ); // Stops tracks immediately if already cancelled.
          });
      await Future.wait<void>([resume, acquisition], eagerError: true);
      _ensureCurrent(request, current);

      final blob = web.Blob(
        [_processorSource.toJS].toJS,
        web.BlobPropertyBag(type: 'application/javascript'),
      );
      final moduleUrl = web.URL.createObjectURL(blob);
      current.moduleUrl = moduleUrl;
      try {
        await current.context.audioWorklet.addModule(moduleUrl).toDart;
      } finally {
        current.releaseModuleUrl();
      }
      _ensureCurrent(request, current);

      final node = web.AudioWorkletNode(
        current.context,
        'neom-voice-pcm16',
        web.AudioWorkletNodeOptions(
          numberOfInputs: 1,
          numberOfOutputs: 0,
          channelCount: 1,
          channelCountMode: 'explicit',
        ),
      );
      current.worklet = node;
      node.port.onmessage = ((web.MessageEvent event) {
        if (request != _request || current.closed || !current.started) return;
        final data = event.data;
        if (data != null) {
          onMonoPcm16((data as JSArrayBuffer).toDart.asUint8List());
        }
      }).toJS;
      current.source = current.context.createMediaStreamSource(current.stream!);
      current.started = true;
      current.source!.connect(
        node,
      ); // No destination/output: never monitor voice.
      return current.context.sampleRate.round();
    } catch (error, stack) {
      if (request == _request) {
        _requested = false;
        _session = null;
      }
      await session?.close();
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _ensureCurrent(int request, _VoiceSession session) {
    if (request != _request || session.closed || !_requested) {
      throw StateError('Microphone measurement cancelled');
    }
  }

  @override
  Future<void> stop() {
    _requested = false;
    ++_request;
    final session = _session;
    _session = null;
    // close() synchronously stops available tracks before awaiting the context.
    // A still-pending getUserMedia response retains this closed session, whose
    // attach() will stop the tracks as soon as permission eventually resolves.
    return session?.close() ?? Future<void>.value();
  }

  @override
  Future<void> dispose() => stop();
}

class _VoiceSession {
  _VoiceSession(this.context);
  final web.AudioContext context;
  web.MediaStream? stream;
  web.MediaStreamAudioSourceNode? source;
  web.AudioWorkletNode? worklet;
  String? moduleUrl;
  bool started = false;
  bool closed = false;
  Future<void>? _closing;

  void attach(web.MediaStream acquired) {
    if (closed) {
      for (final track in acquired.getTracks().toDart) {
        track.stop();
      }
      return;
    }
    stream = acquired;
  }

  void releaseModuleUrl() {
    final url = moduleUrl;
    moduleUrl = null;
    if (url != null) web.URL.revokeObjectURL(url);
  }

  Future<void> close() {
    if (closed) return _closing ?? Future<void>.value();
    closed = true;
    started = false;
    for (final track
        in stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
    stream = null;
    source?.disconnect();
    source = null;
    worklet?.port.onmessage = null;
    worklet?.port.close();
    worklet?.disconnect();
    worklet = null;
    releaseModuleUrl();
    return _closing = context.state == 'closed'
        ? Future<void>.value()
        : context.close().toDart.then<void>((_) {});
  }
}

const _processorSource = r'''
class NeomVoicePcm16 extends AudioWorkletProcessor {
  constructor() { super(); this.pcm = new Int16Array(2048); this.offset = 0; }
  process(inputs) {
    const channels = inputs[0];
    if (!channels || channels.length === 0) return true;
    for (let i = 0; i < channels[0].length; i++) {
      let sample = 0;
      for (let ch = 0; ch < channels.length; ch++) sample += channels[ch][i] || 0;
      sample = Math.max(-1, Math.min(1, sample / channels.length));
      this.pcm[this.offset++] = Math.round(sample * (sample < 0 ? 32768 : 32767));
      if (this.offset === this.pcm.length) {
        this.port.postMessage(this.pcm.buffer, [this.pcm.buffer]);
        this.pcm = new Int16Array(2048); this.offset = 0;
      }
    }
    return true;
  }
}
registerProcessor('neom-voice-pcm16', NeomVoicePcm16);
''';

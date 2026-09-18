const assert = require('node:assert/strict');
const vm = require('node:vm');
globalThis.self = globalThis;
globalThis.window = globalThis;
const contexts = [], tracks = [], nodes = [], sources = [], pending = [];
const urls = new Map();
let urlSerial = 0, rejectWorklet = false, processorTests = 0;
globalThis.voiceTestGrant = (request) => {
  const track = {stopped: false, stop() { this.stopped = true; }};
  tracks.push(track);
  pending[request].resolve({getTracks: () => [track]});
};
globalThis.voiceTestDeny = (request) => pending[request].reject(new Error('Denied'));
globalThis.voiceTestFailWorklet = () => { rejectWorklet = true; };
Object.defineProperty(globalThis, 'navigator', {value: {mediaDevices: {
  getUserMedia(constraints) {
    assert.deepEqual(constraints.audio, {
      echoCancellation: false, autoGainControl: false,
      noiseSuppression: false, channelCount: 1,
    });
    assert.equal(constraints.video, false);
    return new Promise((resolve, reject) => pending.push({resolve, reject}));
  },
}}});
URL.createObjectURL = (blob) => { const url = `blob:voice-test-${++urlSerial}`;
  urls.set(url, blob); return url; };
URL.revokeObjectURL = (url) => { urls.delete(url); };
class TestAudioContext {
  constructor() {
    this.sampleRate = 48000; this.state = 'suspended'; contexts.push(this);
    this.audioWorklet = {addModule: async (url) => {
      if (rejectWorklet) { rejectWorklet = false; throw new Error('CSP/module failed'); }
      const code = await urls.get(url).text();
      vm.runInNewContext(code, {
        AudioWorkletProcessor: class {
          constructor() { this.port = {postMessage: (buffer) => {
            const result = new Int16Array(buffer);
            assert.equal(result.length, 2048);
            assert.equal(result[0], 0); // stereo +1/-1 averages to mono 0
            assert.equal(result[1], 32767);
            assert.equal(result[2], -32768);
            processorTests++;
          }}; }
        },
        registerProcessor: (name, Type) => {
          assert.equal(name, 'neom-voice-pcm16');
          const processor = new Type();
          const left = new Float32Array(2048), right = new Float32Array(2048);
          left[0] = 1; right[0] = -1;
          left[1] = right[1] = 2; // clamp positive overflow
          left[2] = right[2] = -2;
          assert.equal(processor.process([[left, right]]), true);
        },
      });
    }};
  }
  async resume() { this.state = 'running'; }
  async close() { this.state = 'closed'; }
  createMediaStreamSource(stream) {
    assert.ok(stream.getTracks().every((track) => !track.stopped));
    const source = {disconnected: false, connect(node) {
      assert.equal(node.outputs, 0, 'Microphone must never connect to audible output');
    }, disconnect() { this.disconnected = true; }};
    sources.push(source); return source;
  }
}
globalThis.AudioContext = TestAudioContext;
globalThis.AudioWorkletNode = class {
  constructor(context, name, options) {
    assert.equal(context.state, 'running');
    assert.equal(name, 'neom-voice-pcm16');
    assert.equal(options.numberOfOutputs, 0);
    assert.equal(options.channelCount, 1);
    this.outputs = options.numberOfOutputs; this.disconnected = false;
    this.port = {onmessage: null, closed: false, close() { this.closed = true; }};
    nodes.push(this);
  }
  disconnect() { this.disconnected = true; }
};
globalThis.voiceTestEmit = () => {
  const node = nodes.at(-1);
  const pcm = new Int16Array(2048); pcm[0] = 1234; pcm[1] = -1234;
  if (node?.port.onmessage) node.port.onmessage({data: pcm.buffer});
};
globalThis.voiceTestAssertClean = () => {
  assert.ok(tracks.every((track) => track.stopped), 'Microphone track leaked');
  assert.ok(contexts.every((ctx) => ctx.state === 'closed'), 'Context leaked');
  assert.ok(sources.every((source) => source.disconnected), 'Source leaked');
  assert.ok(nodes.every((node) => node.disconnected && node.port.closed), 'Worklet leaked');
  assert.equal(urls.size, 0, 'Blob module URL leaked');
};
let succeeded = false;
const originalLog = console.log;
console.log = (...args) => {
  if (args.includes('VOICE_WEB_PROBE_OK')) succeeded = true;
  originalLog(...args);
};
process.on('beforeExit', () => {
  assert.ok(succeeded, 'Dart voice probe did not complete');
  globalThis.voiceTestAssertClean();
  assert.equal(contexts.length, 6);
  assert.equal(tracks.length, 5);
  assert.equal(processorTests, 2);
  originalLog(JSON.stringify({contexts: contexts.length, releasedTracks: tracks.length,
    processorTests, requests: pending.length, leakedUrls: urls.size}));
});
require(process.argv[2]);

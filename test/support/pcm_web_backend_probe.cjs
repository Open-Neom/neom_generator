// Node harness for the compiled Dart backend. Deliberately no real audio.
const assert = require('node:assert/strict');
globalThis.self = globalThis;
let contexts = 0;
let starts = 0;
let disconnected = 0;
let maxAhead = 0;
let maxLive = 0;
const live = new Set();
class TestAudioContext {
  constructor() {
    contexts++;
    this.state = 'suspended';
    this.destination = {};
    this.origin = performance.now();
  }
  get currentTime() { return (performance.now() - this.origin) / 1000; }
  async resume() { this.state = 'running'; }
  async close() { this.state = 'closed'; }
  createBuffer(channels, length, sampleRate) {
    assert.equal(channels, 2);
    assert.equal(sampleRate, 44100);
    return { duration: length / sampleRate, copyToChannel(samples, channel) {
      assert.equal(samples.length, length);
      const expected = channel === 0 ? 32767 / 32768 : -1;
      assert.equal(samples[0], expected);
      assert.equal(samples[samples.length - 1], expected);
    } };
  }
  createBufferSource() {
    const context = this;
    return {
      buffer: null, onended: null, timer: null,
      connect() {},
      disconnect() { disconnected++; live.delete(this); },
      start(when) {
        starts++;
        const ahead = when + this.buffer.duration - context.currentTime;
        maxAhead = Math.max(maxAhead, ahead);
        assert.ok(ahead <= 0.080001, `Unbounded queue: ${ahead}`);
        live.add(this);
        maxLive = Math.max(maxLive, live.size);
        this.timer = setTimeout(() => {
          live.delete(this);
          if (this.onended) this.onended({});
        }, Math.max(0, ahead * 1000));
      },
      stop() { clearTimeout(this.timer); live.delete(this); },
    };
  }
}
globalThis.AudioContext = TestAudioContext;
let succeeded = false;
const originalLog = console.log;
console.log = (...args) => {
  if (args.includes('PCM_WEB_PROBE_OK')) succeeded = true;
  originalLog(...args);
};
process.on('beforeExit', () => {
  assert.ok(succeeded, 'Dart probe did not complete');
  assert.equal(contexts, 1, 'Repeated play must reuse the context');
  assert.equal(starts, 103);
  assert.equal(live.size, 0, 'All sources must be disposed');
  assert.equal(disconnected, starts);
  assert.ok(maxLive <= 4, `Retained ${maxLive} simultaneous sources`);
  originalLog(JSON.stringify({contexts, starts, maxAhead, maxLive, disconnected}));
});
require(process.argv[2]);

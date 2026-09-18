// Isolated real Chrome + real AudioWorklet/YIN, synthetic input only.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const http = require('node:http');
const {chromium} = require(process.env.NEOM_PLAYWRIGHT_MODULE || 'playwright');

async function main() {
  const compiled = await fs.readFile(process.argv[2]);
  const server = http.createServer((request, response) => {
    if (request.url === '/probe.js') {
      response.writeHead(200, {'Content-Type': 'text/javascript'});
      return response.end(compiled);
    }
    const query = new URL(request.url, 'http://localhost').searchParams;
    const hz = Number(query.get('hz'));
    const rate = Number(query.get('rate'));
    response.writeHead(200, {'Content-Type': 'text/html'});
    response.end(`<!doctype html><html><body><script>
      (async () => {
        const RealContext = AudioContext;
        const contexts = [];
        window.metrics = {contexts, requests: 0, speakers: 0};
        window.AudioContext = function() {
          const context = new RealContext({sampleRate: ${rate}});
          contexts.push(context); return context;
        };
        const connect = AudioNode.prototype.connect;
        AudioNode.prototype.connect = function(destination, ...args) {
          if (destination === this.context.destination) metrics.speakers++;
          return connect.call(this, destination, ...args);
        };
        const source = new RealContext({sampleRate: ${rate}});
        const oscillator = source.createOscillator();
        const gain = source.createGain();
        gain.gain.value = ${hz === 0 ? 0 : 0.4};
        oscillator.frequency.value = ${hz || 440};
        const destination = source.createMediaStreamDestination();
        oscillator.connect(gain); gain.connect(destination);
        window.testStream = destination.stream;
        navigator.mediaDevices.getUserMedia = async constraints => {
          metrics.requests++; metrics.constraints = constraints;
          return testStream; // Never call the real getUserMedia.
        };
        window.voicePitchResult = result => { window.result = result; };
        window.cleanupInput = async () => {
          oscillator.stop(); oscillator.disconnect(); gain.disconnect();
          testStream.getTracks().forEach(track => track.stop());
          await source.close();
        };
        oscillator.start(); await source.resume();
        const script = document.createElement('script');
        script.src = '/probe.js'; document.body.appendChild(script);
      })().catch(error => { window.result = {ok:false, error:String(error)}; });
    </script></body></html>`);
  });
  let browser;
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    browser = await chromium.launch({
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      headless: true,
      args: ['--mute-audio', '--autoplay-policy=no-user-gesture-required',
        '--disable-background-networking', '--disable-extensions'],
    });
    for (const [hz, rate] of [[110, 44100], [220, 48000], [440, 48000], [0, 48000]]) {
      const context = await browser.newContext();
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto(`http://127.0.0.1:${server.address().port}/?hz=${hz}&rate=${rate}`);
      await page.waitForFunction(() => window.result != null, null, {timeout: 15000});
      const result = await page.evaluate(() => ({
        ...window.result, requests: metrics.requests, speakers: metrics.speakers,
        rates: metrics.contexts.map(context => context.sampleRate),
        states: metrics.contexts.map(context => context.state),
        tracks: testStream.getTracks().map(track => track.readyState),
        constraints: metrics.constraints,
      }));
      console.log(JSON.stringify({inputHz: hz, inputRate: rate, ...result, live: result.live?.length}));
      assert.equal(result.ok, true);
      assert.deepEqual(errors, []);
      assert.equal(result.requests, 1);
      assert.equal(result.speakers, 0);
      assert.deepEqual(result.rates, [rate]);
      assert.deepEqual(result.states, ['closed']);
      assert.deepEqual(result.tracks, ['ended']);
      assert.equal(result.constraints.audio.echoCancellation, false);
      if (hz === 0) {
        assert.equal(result.pitch, null); assert.equal(result.live.length, 0);
      } else {
        assert.ok(Math.abs(result.pitch - hz) < 1, 'Measured pitch differs by more than 1 Hz');
        assert.ok(result.live.length > 0);
      }
      await page.evaluate(() => cleanupInput());
      await context.close();
    }
  } finally {
    await browser?.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

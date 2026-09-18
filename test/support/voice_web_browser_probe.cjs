// Real headless Chrome, isolated temporary profile, no real mic or speakers.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const {chromium} = require(process.env.NEOM_PLAYWRIGHT_MODULE || 'playwright');

async function main() {
  const compiled = await fs.readFile(process.argv[2]);
  const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'neom-voice-chrome-'));
  let browser;
  const server = http.createServer((request, response) => {
    if (request.url === '/probe.js') {
      response.writeHead(200, {'Content-Type': 'text/javascript'});
      response.end(compiled);
      return;
    }
    response.writeHead(200, {'Content-Type': 'text/html'});
    response.end(`<!doctype html><html><body>Voice synthetic input probe<script>
      (async () => {
        window.probeMetrics = {permissionCalls: 0, outputs: [], contexts: [], speakerConnections: 0};
        const RealContext = window.AudioContext;
        const RealWorklet = window.AudioWorkletNode;
        window.AudioContext = function(options) {
          const context = new RealContext(options);
          probeMetrics.contexts.push(context);
          return context;
        };
        window.AudioWorkletNode = function(context, name, options) {
          probeMetrics.outputs.push(options.numberOfOutputs);
          return new RealWorklet(context, name, options);
        };
        const connect = AudioNode.prototype.connect;
        AudioNode.prototype.connect = function(destination, ...args) {
          if (destination === this.context.destination) probeMetrics.speakerConnections++;
          return connect.call(this, destination, ...args);
        };
        window.syntheticContext = new RealContext({sampleRate: 48000});
        const oscillator = syntheticContext.createOscillator();
        oscillator.frequency.value = 440;
        const destination = syntheticContext.createMediaStreamDestination();
        oscillator.connect(destination);
        window.syntheticStream = destination.stream;
        navigator.mediaDevices.getUserMedia = async () => {
          probeMetrics.permissionCalls++;
          return syntheticStream; // NEVER invokes the real getUserMedia.
        };
        window.voiceBrowserResult = (result) => { window.probeResult = result; };
        window.cleanupSynthetic = async () => {
          oscillator.stop(); oscillator.disconnect();
          syntheticStream.getTracks().forEach(track => track.stop());
          await syntheticContext.close();
        };
        oscillator.start(); await syntheticContext.resume();
        const script = document.createElement('script'); script.src = '/probe.js';
        document.body.appendChild(script);
      })().catch(error => { window.probeResult = {ok:false,error:String(error)}; });
    </script></body></html>`);
  });
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    browser = await chromium.launchPersistentContext(profile, {
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      headless: true,
      args: ['--mute-audio', '--autoplay-policy=no-user-gesture-required',
        '--disable-background-networking', '--disable-extensions'],
    });
    const page = await browser.newPage();
    page.on('pageerror', error => console.error('pageerror:', error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.waitForFunction(() => window.probeResult != null, null, {timeout: 15000});
    const result = await page.evaluate(() => ({
      ...window.probeResult,
      workletOutputs: probeMetrics.outputs,
      syntheticPermissionCalls: probeMetrics.permissionCalls,
      speakerConnections: probeMetrics.speakerConnections,
      inputTrackStates: syntheticStream.getTracks().map(track => track.readyState),
      captureContextStates: probeMetrics.contexts.map(context => context.state),
      captureContextRates: probeMetrics.contexts.map(context => context.sampleRate),
    }));
    await page.evaluate(() => cleanupSynthetic());
    console.log(JSON.stringify(result));
    assert.equal(result.ok, true);
    assert.ok(result.buffers >= 3 && result.nonzeroSamples > 100);
    assert.equal(result.sampleRate, result.captureContextRates[0]);
    assert.ok(result.sampleRate > 0);
    assert.deepEqual(result.workletOutputs, [0]);
    assert.equal(result.speakerConnections, 0);
    assert.deepEqual(result.inputTrackStates, ['ended']);
    assert.deepEqual(result.captureContextStates, ['closed']);
  } finally {
    await browser?.close();
    await new Promise(resolve => server.close(resolve));
    // Only this test's explicit mkdtemp profile; no user's browser data touched.
    await fs.rm(profile, {recursive: true, force: true});
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

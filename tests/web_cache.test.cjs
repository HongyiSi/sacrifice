// Browser integration checks for persistent bytes, updates, corruption and fallback.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs'), path = require('node:path'), http = require('node:http');
const crypto = require('node:crypto'), assert = require('node:assert/strict');
const output = process.argv[2];
if (!output) throw Error('Pass an isolated output directory for the test browser profile.');
fs.mkdirSync(output, { recursive: true });
const code = fs.readFileSync(path.join(__dirname, '../deploy/web_cache.js'), 'utf8');
const bodies = { 'fixture.pck': Buffer.alloc(2048, 65), 'engine.wasm': Buffer.from('fixed engine fixture') };
const calls = [], checks = [];
let mode = 'ok', context;
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost/');
  const name = url.pathname.slice(1);
  if (!name) { res.setHeader('Content-Type', 'text/html'); res.end('<!doctype html><title>Cache test</title>'); return; }
  calls.push({ name, search: url.search, method: req.method, range: req.headers.range });
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/octet-stream');
  if (mode === '500') { res.writeHead(500); res.end('failed'); return; }
  let bytes = bodies[name] || Buffer.from('passthrough');
  if (name === 'fixture.pck' && mode === 'wrong') bytes = Buffer.alloc(bytes.length, 90);
  if (name === 'fixture.pck' && mode === 'short') bytes = bytes.subarray(0, 512);
  res.write(bytes.subarray(0, 256));
  setTimeout(() => res.end(bytes.subarray(256)), 180);
});
const manifest = () => ({ schema: 1, assets: Object.fromEntries(Object.entries(bodies).map(([name, bytes]) => [name, { bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') }])) });
async function launch() {
  return chromium.launchPersistentContext(path.join(output, 'profile'), {
    executablePath: process.env.EDGE_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true,
  });
}
async function pageWithCache(fault) {
  const page = await context.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  if (fault) await page.evaluate(fault);
  await page.addScriptTag({ content: code });
  await page.evaluate(m => { window.testCache = SacrificeResourceCache.install(m); }, manifest());
  return page;
}
async function read(page, name = 'fixture.pck') {
  return page.evaluate(async name => {
    const response = await fetch(name);
    const text = await response.text();
    await testCache.settled();
    return { text, status: response.status, stats: testCache.stats };
  }, name);
}
function pass(name) { checks.push(name); console.log('PASS ' + name); }
(async () => {
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    context = await launch();
    let page = await pageWithCache();
    const timing = await page.evaluate(async () => {
      const start = performance.now(); const response = await fetch('fixture.pck'); const reader = response.body.getReader();
      await reader.read(); const first = performance.now();
      while (!(await reader.read()).done) {}
      await testCache.settled(); return { first: first - start, total: performance.now() - start };
    });
    assert(timing.total - timing.first > 100); pass('Download progress streams before completion');
    let before = calls.length; assert.equal((await read(page)).text, 'A'.repeat(2048));
    assert.equal(calls.length, before); pass('Second load uses verified cached bytes without HTTP');
    await read(page, 'engine.wasm');
    await context.close(); context = await launch(); page = await pageWithCache();
    before = calls.length; await read(page); await read(page, 'engine.wasm');
    assert.equal(calls.length, before); pass('Both files survive a real browser restart');
    bodies['fixture.pck'] = Buffer.alloc(2048, 66);
    await page.close(); page = await pageWithCache(); before = calls.length;
    assert.equal((await read(page)).text, 'B'.repeat(2048)); await read(page, 'engine.wasm');
    assert.equal(calls.length, before + 1); pass('Changed pack updates while unchanged engine is reused');
    await page.evaluate(async () => {
      const cache = await caches.open(testCache.cacheName);
      const unrelated = await caches.open('unrelated-app'); await unrelated.put('/keep', new Response('keep'));
      await testCache.ready();
      window.keyCount = (await cache.keys()).length;
    });
    assert.equal(await page.evaluate(() => keyCount), 2);
    assert(await page.evaluate(async () => !!await (await caches.open('unrelated-app')).match('/keep')));
    pass('Old versions cleaned without touching another cache');
    await page.evaluate(async () => {
      const cache = await caches.open(testCache.cacheName);
      for (const key of await cache.keys()) if (key.url.includes('fixture.pck')) await cache.put(key, new Response('damaged'));
    });
    before = calls.length; assert.equal((await read(page)).text, 'B'.repeat(2048));
    assert.equal(calls.length, before + 1); pass('Corrupted cache automatically redownloads');
    for (const failure of ['wrong', 'short']) {
      await page.evaluate(async () => {
        const cache = await caches.open(testCache.cacheName);
        for (const key of await cache.keys()) if (key.url.includes('fixture.pck')) await cache.delete(key);
      });
      mode = failure;
      const error = await page.evaluate(async () => { try { await (await fetch('fixture.pck')).arrayBuffer(); return null; } catch(e) { return String(e); } });
      assert(error, 'Invalid ' + failure + ' bytes must reject the response body');
      assert.equal(await page.evaluate(async () => (await (await caches.open(testCache.cacheName)).keys()).filter(k => k.url.includes('fixture.pck')).length), 0);
      mode = 'ok'; assert.equal((await read(page)).text, 'B'.repeat(2048));
      pass('Rejects ' + failure + ' download without caching it, retry succeeds');
    }
    await page.evaluate(async () => {
      await fetch('fixture.pck', { method: 'POST', body: 'test' });
      await fetch('fixture.pck', { headers: { Range: 'bytes=0-1' } });
      await fetch('outside.bin');
    });
    assert(calls.slice(-3).every(c => !c.search)); pass('POST, range and unrelated requests are untouched');
    await page.close(); page = await pageWithCache(() => Object.defineProperty(window, 'caches', { get() { throw new DOMException('Disabled', 'SecurityError'); } }));
    before = calls.length; assert.equal((await read(page)).text, 'B'.repeat(2048)); await read(page);
    assert.equal(calls.length, before + 2); pass('Unavailable storage falls back to normal downloads');
    await page.close(); page = await pageWithCache(() => Object.defineProperty(window, 'caches', { value: { open: async () => ({ match: async () => undefined, keys: async () => [], put: async () => { throw new DOMException('Full', 'QuotaExceededError'); } }) } }));
    assert.equal((await read(page)).text, 'B'.repeat(2048)); pass('Full storage does not block a valid download');
    mode = '500'; assert.equal((await read(page)).status, 500); mode = 'ok'; pass('HTTP errors remain errors and are not stored');
    fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ success: true, checks, timing }, null, 2));
  } finally { if (context) await context.close(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { fs.writeFileSync(path.join(output, 'failure.txt'), String(error.stack)); console.error(error); process.exitCode = 1; });

'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { requestImage, validateInput, localUrl } = require('../image-client.cjs');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRz8AAAAASUVORK5CYII=', 'base64');

async function fixture(t, handler) {
  const folder = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-proxy-tool-'));
  const received = [];
  const server = http.createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    received.push({ path: req.url, body: JSON.parse(raw || '{}') });
    if (handler) return handler(req, res);
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ data: [{ b64_json: png.toString('base64') }] }));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    assert.equal(path.dirname(path.resolve(folder)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(folder).startsWith('codex-proxy-tool-'));
    await fs.rm(folder, { recursive: true });
  });
  return { received, folder, options: { proxyUrl: `http://127.0.0.1:${server.address().port}`, outputDirectory: folder } };
}

test('only local HTTP origins are accepted', () => {
  for (const url of ['https://127.0.0.1', 'http://example.com', 'http://127.0.0.1.evil.test', 'http://user:secret@localhost', 'http://localhost/path', 'http://localhost?x=1']) assert.throws(() => localUrl(url));
  assert.equal(localUrl('http://127.0.0.1:18765').port, '18765');
});
test('reject unsafe filenames, empty prompts and nonlocal edit paths', () => {
  for (const filename of ['../x.png', 'C:\\x.png', 'CON.png', 'a:stream', '', 'trailing ']) assert.throws(() => validateInput({ prompt: 'test', filename }, false));
  assert.throws(() => validateInput({ prompt: ' ' }, false));
  assert.throws(() => validateInput({ prompt: 'test', images: ['relative.png'] }, true));
  assert.throws(() => validateInput({ prompt: 'test', images: [] }, true));
});
test('generates through correct endpoint, saves signature-matched image and does not overwrite', async t => {
  const f = await fixture(t);
  const result = await requestImage({ prompt: 'blue rocket', filename: 'rocket.jpg' }, f.options);
  assert.equal(result.mimeType, 'image/png');
  assert.equal(result.destination, path.join(f.folder, 'rocket.png'));
  assert.deepEqual(await fs.readFile(result.destination), png);
  assert.deepEqual(f.received[0], { path: '/v1/images/generations', body: { model: 'gpt-image-2', prompt: 'blue rocket', n: 1 } });
  await assert.rejects(requestImage({ prompt: 'green rocket', filename: 'rocket.png' }, f.options), { code: 'EEXIST' });
  assert.deepEqual(await fs.readFile(result.destination), png);
});
test('edits selected images through edits API and preserves originals', async t => {
  const f = await fixture(t);
  const source = path.join(f.folder, 'original.png');
  await fs.writeFile(source, png);
  await requestImage({ prompt: 'make green', filename: 'edited', images: [source] }, { ...f.options, edit: true });
  assert.equal(f.received[0].path, '/v1/images/edits');
  assert.equal(f.received[0].body.images[0].image_url, `data:image/png;base64,${png.toString('base64')}`);
  assert.deepEqual(await fs.readFile(source), png);
  assert.deepEqual(await fs.readFile(path.join(f.folder, 'edited.png')), png);
});
test('oversize and invalid input images are rejected before network', async t => {
  const f = await fixture(t);
  const file = path.join(f.folder, 'large.png');
  await fs.writeFile(file, png);
  await fs.truncate(file, 20 * 1024 * 1024 + 1);
  await assert.rejects(requestImage({ prompt: 'edit', images: [file] }, { ...f.options, edit: true }), /20 MiB/);
  await fs.writeFile(file, 'not an image');
  await assert.rejects(requestImage({ prompt: 'edit', images: [file] }, { ...f.options, edit: true }), /signature/);
  assert.equal(f.received.length, 0);
});
test('pre-cancelled calls spend no image request', async t => {
  const f = await fixture(t);
  await assert.rejects(requestImage({ prompt: 'test' }, { ...f.options, signal: AbortSignal.abort() }), { name: 'AbortError' });
  assert.equal(f.received.length, 0);
  assert.deepEqual(await fs.readdir(f.folder), []);
});
test('cancellation aborts a running request without saving a file', async t => {
  const controller = new AbortController();
  const f = await fixture(t, () => controller.abort());
  await assert.rejects(requestImage({ prompt: 'test' }, { ...f.options, signal: controller.signal }), { name: 'AbortError' });
  assert.equal(f.received.length, 1);
  assert.deepEqual(await fs.readdir(f.folder), []);
});
test('timeout does not retry or save a file', async t => {
  const f = await fixture(t, () => {});
  await assert.rejects(requestImage({ prompt: 'test' }, { ...f.options, timeoutMs: 100 }), { name: 'TimeoutError' });
  assert.equal(f.received.length, 1);
  assert.deepEqual(await fs.readdir(f.folder), []);
});
test('HTTP errors provide an actionable hint without exposing backend response bodies', async t => {
  const f = await fixture(t, (_req, res) => { res.writeHead(404); res.end('private backend data'); });
  await assert.rejects(requestImage({ prompt: 'test' }, f.options), error => /imagesApi/.test(error.message) && !/private/.test(error.message));
  assert.deepEqual(await fs.readdir(f.folder), []);
});
test('redirects cannot send images outside the local proxy', async t => {
  const f = await fixture(t, (_req, res) => { res.writeHead(307, { Location: 'http://example.com' }); res.end(); });
  await assert.rejects(requestImage({ prompt: 'test' }, f.options));
  assert.equal(f.received.length, 1);
});
test('invalid image result creates no output file', async t => {
  const f = await fixture(t, (_req, res) => res.end(JSON.stringify({ data: [{ b64_json: Buffer.from('invalid').toString('base64') }] })));
  await assert.rejects(requestImage({ prompt: 'test' }, f.options), /signature/);
  assert.deepEqual(await fs.readdir(f.folder), []);
});

'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { homedir } = require('node:os');
const MAX_INPUT = 20 * 1024 * 1024;
const MAX_RESPONSE = 40 * 1024 * 1024;

function imageType(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return ['image/png', '.png'];
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return ['image/jpeg', '.jpg'];
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') return ['image/webp', '.webp'];
  if (['GIF87a', 'GIF89a'].includes(bytes.toString('ascii', 0, 6))) return ['image/gif', '.gif'];
  throw new Error('Unsupported image signature. Use PNG, JPEG, WebP or GIF.');
}

function validateInput(input, edit) {
  if (!input || typeof input.prompt !== 'string' || !input.prompt.trim()) throw new Error('A nonempty prompt is required.');
  if (input.filename !== undefined && (typeof input.filename !== 'string' || !/^[\w -]{1,120}(?:\.(?:png|jpg|jpeg|webp|gif))?$/i.test(input.filename) || /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(input.filename) || /[ .]$/.test(input.filename))) {
    throw new Error('Use a simple new filename without directories or reserved names.');
  }
  if (edit && (!Array.isArray(input.images) || input.images.length < 1 || input.images.length > 5 || input.images.some(p => typeof p !== 'string' || !path.isAbsolute(p)))) {
    throw new Error('Select 1–5 absolute local image paths.');
  }
}

function localUrl(value) {
  const url = new URL(value || 'http://127.0.0.1:18765');
  if (url.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Proxy URL must be a local HTTP origin, for example http://127.0.0.1:18765.');
  }
  return url;
}

async function boundedJson(response) {
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > MAX_RESPONSE) throw new Error('Image response exceeds 40 MiB.');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

async function requestImage(input, { edit = false, proxyUrl, outputDirectory, signal, timeoutMs = 300000 } = {}) {
  validateInput(input, edit);
  const base = localUrl(proxyUrl);
  if (outputDirectory && !path.isAbsolute(outputDirectory)) throw new Error('Output directory must be an absolute local path.');
  const output = outputDirectory || path.join(homedir(), 'Pictures', 'Codex');
  const combined = AbortSignal.any([AbortSignal.timeout(timeoutMs), ...(signal ? [signal] : [])]);
  combined.throwIfAborted();
  const body = { model: 'gpt-image-2', prompt: input.prompt, n: 1 };
  if (edit) {
    body.images = [];
    for (const filename of input.images) {
      combined.throwIfAborted();
      const file = await fs.open(filename, 'r');
      let bytes;
      try {
        const stat = await file.stat();
        if (!stat.isFile() || stat.size > MAX_INPUT) throw new Error('Input must be a regular image file of at most 20 MiB.');
        // Read at most limit + 1, even if the file grows after stat.
        const buffer = Buffer.alloc(Math.min(stat.size + 1, MAX_INPUT + 1));
        let offset = 0;
        while (offset < buffer.length) {
          const { bytesRead } = await file.read(buffer, offset, buffer.length - offset, offset);
          if (!bytesRead) break;
          offset += bytesRead;
        }
        if (offset > stat.size) throw new Error('Input image changed while reading; select a stable file.');
        bytes = buffer.subarray(0, offset);
      } finally { await file.close(); }
      body.images.push({ image_url: `data:${imageType(bytes)[0]};base64,${bytes.toString('base64')}` });
    }
  }
  const response = await fetch(new URL(edit ? '/v1/images/edits' : '/v1/images/generations', base), {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: combined, redirect: 'error'
  });
  if (!response.ok) {
    await response.body?.cancel();
    const hints = { 401: 'Sign in again with codex auth login and restart the proxy.', 403: 'Check access to images on the signed-in ChatGPT account.', 404: 'Enable codex.imagesApi and restart the proxy.', 429: 'ChatGPT quota or rate limit reached. Try later.' };
    throw new Error(`Image proxy HTTP ${response.status}. ${hints[response.status] || 'Check the proxy log.'}`);
  }
  const result = await boundedJson(response);
  combined.throwIfAborted();
  const data = result.data?.[0]?.b64_json;
  if (typeof data !== 'string' || !data.length || !/^[A-Za-z0-9+/]+={0,2}$/.test(data)) throw new Error('The proxy returned no valid base64 image.');
  const bytes = Buffer.from(data, 'base64');
  const [mimeType, extension] = imageType(bytes);
  const requested = input.filename || `codex-${randomUUID()}`;
  const filename = path.parse(requested).name + extension;
  const destination = path.join(output, filename);
  await fs.mkdir(output, { recursive: true });
  combined.throwIfAborted();
  const file = await fs.open(destination, 'wx');
  try {
    await file.writeFile(bytes);
  } catch (error) {
    await file.close();
    await fs.unlink(destination);
    throw error;
  }
  await file.close();
  return { destination, bytes, mimeType };
}

module.exports = { requestImage, validateInput, localUrl };

#!/usr/bin/env node
// Dependency-free MCP bridge to this proxy's existing, opt-in Images API.
import { createInterface } from 'node:readline';
import { mkdir, readFile, open } from 'node:fs/promises';
import { resolve, join, dirname, extname } from 'node:path';
import { homedir } from 'node:os';
import { randomUUID } from 'node:crypto';

const base = new URL(process.env.CCP_IMAGE_PROXY_URL || 'http://127.0.0.1:18765');
if (base.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(base.hostname)) {
  throw new Error('CCP_IMAGE_PROXY_URL must be a local HTTP proxy URL');
}
const outputDir = resolve(process.env.CCP_IMAGE_OUTPUT_DIR || join(homedir(), 'Pictures', 'Codex'));
const send = value => process.stdout.write(JSON.stringify({ jsonrpc: '2.0', ...value }) + '\n');
const properties = {
  prompt: { type: 'string', minLength: 1, description: 'Describe the image to generate or the edit to make.' },
  filename: { type: 'string', description: 'Optional new filename, without a directory. Existing files are never overwritten.' },
};
const tools = [
  { name: 'codex_generate_image', description: 'Generate an image with gpt-image-2 through the local claude-code-proxy and the signed-in ChatGPT subscription. Uses image quota. Saves the result and returns an image preview.', inputSchema: { type: 'object', properties, required: ['prompt'], additionalProperties: false }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true } },
  { name: 'codex_edit_image', description: 'Edit 1–5 existing local image files with gpt-image-2 through the local proxy. Saves a new image; source files are preserved. Uses ChatGPT image quota.', inputSchema: { type: 'object', properties: { ...properties, images: { type: 'array', minItems: 1, maxItems: 5, items: { type: 'string' }, description: 'Absolute paths to PNG, JPEG, WebP or GIF images explicitly selected by the user.' } }, required: ['prompt', 'images'], additionalProperties: false }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true } },
];
function imageType(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return ['image/png', '.png'];
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return ['image/jpeg', '.jpg'];
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') return ['image/webp', '.webp'];
  if (['GIF87a', 'GIF89a'].includes(bytes.toString('ascii', 0, 6))) return ['image/gif', '.gif'];
  throw new Error('The image does not have a supported file signature');
}
async function callTool(params) {
  if (!tools.some(tool => tool.name === params.name)) throw new Error('Unknown image tool');
  const args = params.arguments || {};
  if (typeof args.prompt !== 'string' || !args.prompt.trim()) throw new Error('A nonempty prompt is required');
  if (args.filename && (typeof args.filename !== 'string' || !/^[\w -]+(?:\.(?:png|jpg|jpeg|webp|gif))?$/i.test(args.filename))) throw new Error('Use a simple filename without a directory');
  const body = { model: 'gpt-image-2', prompt: args.prompt, n: 1 };
  let endpoint = '/v1/images/generations';
  if (params.name === 'codex_edit_image') {
    if (!Array.isArray(args.images) || args.images.length < 1 || args.images.length > 5) throw new Error('Select 1–5 local image paths');
    endpoint = '/v1/images/edits';
    body.images = [];
    for (const file of args.images) {
      if (typeof file !== 'string' || resolve(file) !== file) throw new Error('Image paths must be absolute');
      const bytes = await readFile(file);
      if (bytes.length > 20 * 1024 * 1024) throw new Error('Input image exceeds 20 MiB');
      body.images.push({ image_url: `data:${imageType(bytes)[0]};base64,${bytes.toString('base64')}` });
    }
  }
  const progressToken = params._meta?.progressToken;
  let progress = 0;
  const heartbeat = setInterval(() => {
    if (progressToken !== undefined) send({ method: 'notifications/progress', params: { progressToken, progress: ++progress, message: 'Codex is generating the image' } });
  }, 10000);
  try {
    const response = await fetch(new URL(endpoint, base), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: AbortSignal.timeout(300000) });
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 2000);
      throw new Error(`Image proxy returned HTTP ${response.status}: ${detail}`);
    }
    const result = await response.json();
    const data = result.data?.[0]?.b64_json;
    if (typeof data !== 'string' || !data.length) throw new Error('The proxy returned no image');
    const bytes = Buffer.from(data, 'base64');
    const [mimeType, extension] = imageType(bytes);
    const requested = args.filename || `codex-${randomUUID()}${extension}`;
    const filename = extname(requested) ? requested.slice(0, -extname(requested).length) + extension : requested + extension;
    const destination = join(outputDir, filename);
    await mkdir(dirname(destination), { recursive: true });
    const file = await open(destination, 'wx');
    try { await file.writeFile(bytes); } finally { await file.close(); }
    return { content: [{ type: 'text', text: `Image saved to ${destination}` }, { type: 'image', mimeType, data }], isError: false };
  } finally { clearInterval(heartbeat); }
}
async function handle(message) {
  if (message.id === undefined) return;
  const id = message.id;
  if (message.method === 'initialize') return send({ id, result: { protocolVersion: '2025-11-25', capabilities: { tools: {} }, serverInfo: { name: 'codex-images-proxy', version: '1.0.0' }, instructions: 'Image tools use the local proxy and the user ChatGPT image quota. Generated images are saved locally.' } });
  if (message.method === 'ping') return send({ id, result: {} });
  if (message.method === 'tools/list') return send({ id, result: { tools } });
  if (message.method === 'tools/call') {
    try { send({ id, result: await callTool(message.params) }); }
    catch (error) { send({ id, result: { content: [{ type: 'text', text: error.message }], isError: true } }); }
    return;
  }
  send({ id, error: { code: -32601, message: 'Method not found' } });
}
createInterface({ input: process.stdin, crlfDelay: Infinity }).on('line', line => {
  try { void handle(JSON.parse(line)).catch(error => console.error(error.message)); }
  catch { send({ id: null, error: { code: -32700, message: 'Invalid JSON' } }); }
});

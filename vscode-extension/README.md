# Codex Proxy Tools

Native image generation and editing tools for VS Code's integrated Agent chat.
Connects directly to the local claude-code-proxy Images API using VS Code's
extension host. No MCP server, separate Node installation, API key, or terminal
is needed during daily use. The proxy must be running and signed in.

Install the `.vsix` from this fork's release once. Enable **Codex: Generate Image**
and **Codex: Edit Image** in Agent chat's tool picker. Refer to them explicitly as
`#codexGenerateImage` and `#codexEditImage`, or describe the image you want.
VS Code displays its standard tool confirmation. This extension does not bypass it.

Images default to `~/Pictures/Codex`. Configure `codexProxyTools.outputDirectory`
to change the local destination, or `codexProxyTools.proxyUrl` for another local
port. Edits accept 1–5 absolute local paths (PNG/JPEG/WebP/GIF, 20 MiB each),
preserve originals, and upload those selected images to ChatGPT. Existing output
files are never overwritten. Cancellation stops the local request; an already
submitted generation may still use quota upstream. A timeout is not retried.

Requires VS Code 1.112 or later on desktop. Runs locally even with a remote
workspace: input/output paths must refer to the local computer. Remote image
paths and VS Code for the Web are not supported.

Full Spanish setup and validation:
[FORK_SETUP.md](https://github.com/RonaldProCo/claude-code-proxy/blob/main/FORK_SETUP.md),
[VSCODE_GUIDE.md](https://github.com/RonaldProCo/claude-code-proxy/blob/main/VSCODE_GUIDE.md).

Developers only: Node 22+, `npm ci`, `npm test`, `npm run package`. The VSIX has
no runtime npm dependencies. Source and license are included in the package.

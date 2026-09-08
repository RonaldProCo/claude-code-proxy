# GPT-6 Astra — RonaldProCo fork

Independent release **v0.1.36-astra.1**, built from upstream `main` commit
[`55bf0b5818b461e1860964809726f99d2fd52c10`](https://github.com/raine/claude-code-proxy/commit/55bf0b5818b461e1860964809726f99d2fd52c10).

The Rust runtime is unchanged from that commit. This packages the already merged
GPT-6 Astra support, including model discovery, `gpt-6-astra-fast`, and Responses
Lite routing. Existing Claude aliases and the opt-in Codex Images API are preserved.
It also includes the upstream request-id and continuation fixes since v0.1.35.

All six platform archives include a matching SHA-256 checksum: Windows, macOS,
and Linux, on x64 and ARM64. Publication runs formatting, Clippy, the Rust test
suite, and binary version / Astra catalog checks.

On Windows, download `claude-code-proxy-windows-amd64.zip` (or `windows-arm64` for
ARM devices), verify its `.sha256`, and extract it. Stop the previous proxy before
replacing its executable, then restart it. Existing proxy authentication remains
in its original configuration directory.

Select `gpt-6-astra` or `gpt-6-astra[1m]` in the client. The `[1m]` suffix adjusts
Claude Code's local context policy; actual model access and context limits remain
those of your ChatGPT account. To enable the existing image endpoint, set
`CCP_CODEX_IMAGES_API=1` on the proxy process. Image generation uses the same
proxy-owned ChatGPT login and consumes its image quota.

[Complete Windows and VS Code instructions](https://github.com/RonaldProCo/claude-code-proxy/blob/main/FORK_SETUP.md).
The updated `vscode-setup.zip` attachment contains the installer, configuration
helper, hidden background launcher, and **Codex Proxy Tools 1.0.0**, a native
VS Code extension for image generation and editing. Its source commit is recorded
in `SOURCE.json`. It replaces this fork's earlier MCP image bridge. End users do
not need Rust, Node.js, an image MCP server, or an open terminal. Install once,
then start the proxy with `Iniciar proxy.lnk`. The VSIX is also attached separately.

The setup configures **Steer** for messages sent during work and enables automatic
history summarization. [Tools, context, steering, and compaction guide](https://github.com/RonaldProCo/claude-code-proxy/blob/main/VSCODE_GUIDE.md).
The VS Code package has its own build workflow and does not replace the Rust
executables from the original release tag.

Validated with the published Windows x64 executable: **1,027 passing Rust
tests**, Astra responding inside VS Code's built-in chat, native image generation
and editing with previews, reading/editing files, steering while an image tool
was running, and `/compact` followed by correct recall of the task's control data.
Native client regression tests also cover cancellation, timeouts, invalid inputs,
HTTP failures, redirects, and preserving existing images.
[Validation report](https://github.com/RonaldProCo/claude-code-proxy/blob/main/VALIDATION.md).

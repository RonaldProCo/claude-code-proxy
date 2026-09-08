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
The `vscode-setup.zip` attachment contains the installer, configuration helper,
startup script, and optional image MCP bridge from the fork, with its source
commit recorded in `SOURCE.json`. Node.js 22+ is required only for the image MCP
bridge. The proxy executable itself needs no Rust or Node installation.

Validated with the published Windows x64 executable: **1,027 passing Rust
tests**, Astra responding inside VS Code's built-in chat, image generation with
an inline chat preview, and a real image edit through the MCP bridge.
[Validation report](https://github.com/RonaldProCo/claude-code-proxy/blob/main/VALIDATION.md).

# Validación de v0.1.36-astra.1

Validado el 7 de septiembre de 2026 (UTC-05), con el ejecutable descargado de
GitHub Actions y de la release pública. No se utilizó una compilación local para
las pruebas de VS Code.

## Procedencia del binario

- Upstream: `raine/claude-code-proxy`, commit
  `55bf0b5818b461e1860964809726f99d2fd52c10`.
- Etiqueta: `v0.1.36-astra.1`, commit `e47fa9a`.
- `src/` y `tests/` son idénticos al commit indicado de upstream.
- [Compilación y publicación en GitHub Actions](https://github.com/RonaldProCo/claude-code-proxy/actions/runs/34181929235).
- [Release y descargas](https://github.com/RonaldProCo/claude-code-proxy/releases/tag/v0.1.36-astra.1).

| Archivo | SHA-256 |
| --- | --- |
| `claude-code-proxy-windows-amd64.zip` | `30d70b154e9ac68a69b8fb52ff4d4bc67499153dd0cbdb6b3cdeba9add1979f8` |
| `claude-code-proxy.exe` extraído | `1f2094ee4ec29a225be24495561ae630663c324fb291503e558e6038932a0941` |

## Comprobaciones realizadas

| Prueba | Resultado |
| --- | --- |
| `cargo fmt --all -- --check` | Aprobada |
| `cargo clippy --locked --all-targets -- -D warnings` | Aprobada |
| `cargo test --locked` | **1.027 aprobadas; 0 fallidas** |
| Compilaciones Windows, Linux y macOS, x64 y ARM64 | Las seis aprobadas |
| Versión y catálogo de Astra de cada binario | Aprobados |
| Smoke test adicional de Windows | Aprobado |
| Instalador descargando de la release pública en una carpeta limpia | Aprobado; SHA-256 y ejecutable idénticos |
| Configuración desde cero con Windows PowerShell 5.1 | Aprobada |
| Configuración sobre ajustes existentes, ejecutada dos veces | Conserva ajustes y no duplica Astra |
| `vscode-setup.zip` descargado de la release | SHA-256 verificado y configuración limpia aprobada |
| Dependencias del ejecutable Windows | Se identificó `VCRUNTIME140.dll`; el runtime oficial está incluido en los requisitos de instalación |
| Protocolo MCP: inicio, catálogo, errores, generación y edición | Aprobado con servidor simulado |
| Solicitud real de texto al ejecutable publicado | `model: gpt-6-astra`; respuesta `ASTRA_OK_42` |
| **Chat integrado de VS Code con Astra** | Respuesta **`ASTRA_VSCODE_OK`** |
| Generación real con la herramienta de imágenes y el proxy publicado | PNG válido guardado y revisado |
| **Generación solicitada desde el chat integrado de VS Code** | Astra invocó `codex_generate_image`; VS Code mostró el cohete azul generado |
| Edición real del cohete a verde por el puente MCP y el mismo ejecutable | PNG nuevo guardado; original conservado |

La prueba visual utilizó VS Code **1.135.0 x64**, Node.js **24.19.0** y el
proveedor **Codex via Proxy / GPT-6 Astra (Codex subscription)** en modo Agent.
Se comprobó en la interfaz que el modelo de la respuesta era
`Codex via Proxy/gpt-6-astra` y que la imagen se mostraba dentro del chat.
El permiso de uso de la herramienta MCP se aceptó manualmente en VS Code.

## Incidencia resuelta durante la prueba

La sesión anterior del proxy devolvía `invalid_refresh_token`. Se inició sesión
de nuevo mediante `codex auth login`, el usuario completó la autorización en el
navegador y se reinició el proxy. Las solicitudes reales posteriores de texto,
generación y edición de imágenes funcionaron.

## Reproducir en otra PC

Sigue [FORK_SETUP.md](FORK_SETUP.md). El paquete `vscode-setup.zip` contiene los
scripts y su commit de procedencia en `SOURCE.json`. No contiene credenciales,
tokens, ajustes privados ni las copias de respaldo del equipo de prueba.
Cada PC debe completar su propio inicio de sesión.

Las pruebas reales de interfaz se hicieron en Windows x64. Los demás binarios
se compilaron y verificaron en sus respectivos runners; no se realizó una prueba
visual de VS Code en esos sistemas. El acceso a modelos y la cuota de imágenes
siguen dependiendo de la cuenta autenticada y del servicio de ChatGPT.

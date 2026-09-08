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

## Revisión adicional: VS Code nativo sin MCP

El 7 de septiembre de 2026 se volvió a probar con **VS Code 1.136.1 x64**,
chat integrado **Local / Agent**, Astra y el mismo ejecutable publicado cuyo
SHA-256 figura arriba. Se instaló **Codex Proxy Tools 1.0.0** como VSIX: sus
herramientas aparecieron habilitadas en **Configure Tools**. El código de la
extensión se ejecuta dentro del host local de VS Code.

| Prueba real | Resultado observado |
| --- | --- |
| Lectura de archivo de contexto | Astra leyó `REVIEW_INPUT.md` con la herramienta del editor y obtuvo `LIMA-742-ASTRA` |
| Generación nativa | `codexProxy_generateImage` produjo `astra-native-fox.png`, zorro naranja con estrella azul; vista previa en el chat |
| Edición nativa | `codexProxy_editImage` produjo `astra-native-fox-edit.png`, estrella verde; original conservado y resultado revisado visualmente |
| Crear, leer y editar archivos | El agente creó `native-tool-report.md`, lo leyó y modificó mediante herramientas de VS Code; también comprobó diagnósticos |
| Mensaje durante una herramienta activa | Se observó **Editing image with Codex…**, se pulsó **Steer with Message** y apareció **STEERING** dentro de la misma sesión |
| Continuación tras Steer | La edición terminó; el agente aplicó `INFORME GUIADO` y `STEER_OK_742`, manteniendo ambas rutas y `LIMA-742-ASTRA` |
| Compactación manual | `/compact` mostró **Compacted conversation.**; el indicador pasó de 9% a 7% antes de continuar |
| Contexto después de compactar | Sin releer archivos ni invocar herramientas, Astra recordó código, título, marcador, estrella verde y ambos nombres de imagen |
| Migración de imágenes | Se retiró la entrada `codex-images`; el servidor `context7` existente se conservó. No había proceso del antiguo puente MCP de imágenes |
| Inicio oculto desde PowerShell 5.1 | El ejecutable publicado siguió activo tras terminar el lanzador, respondió `/v1/models` con Astra y no tenía ventana (`MainWindowHandle = 0`) |
| Inicio repetido | Detectó el proxy ya activo y no creó otra instancia |
| Instalación del ejecutable con PowerShell 5.1 | Descarga real de la release a una carpeta limpia; SHA-256 y versión verificados |

La respuesta posterior a la compactación fue:

```text
Código: LIMA-742-ASTRA; título final: INFORME GUIADO; marcador: STEER_OK_742;
estrella: verde; imágenes: astra-native-fox.png y astra-native-fox-edit.png.
```

| Imagen de la prueba | Bytes | SHA-256 |
| --- | ---: | --- |
| `astra-native-fox.png` | 936804 | `931eaba02635b339c1402c86644bfc240f215eaa59943c33eb495aca86326397` |
| `astra-native-fox-edit.png` | 1412910 | `3b058b129c4e15a8bdc04a657debc2c367dc004dac4fdb6cc1596b72baeea5f6` |

La extensión tiene **11 pruebas automatizadas** aprobadas para rutas locales,
entradas inválidas, llamadas de generación/edición, conservación de archivos,
cancelación previa y durante la petición, timeout sin reintento, errores HTTP,
redirecciones y resultados inválidos. El configurador se probó con PowerShell
**5.1 y 7**, desde cero y dos veces sobre ajustes existentes. Se corrigió una
envoltura accidental del array de proveedores al reinstalar bajo PowerShell 5.1.

La prueba del lanzador usó un puerto temporal y se detuvo después. El proxy
principal continuó activo. La extensión no añadió un proceso Node externo,
servicio ni tarea de arranque. No se alteraron permisos ni configuraciones de
otras herramientas. El paquete incluye un workflow independiente para ejecutar
las pruebas y publicar el VSIX y el ZIP con sumas SHA-256.

**Alcance:** se probó compactación manual y continuidad; no se llenó artificialmente
una ventana de 240.000 tokens para forzar el umbral automático. Se verificó que
el ajuste automático queda habilitado. Las pruebas de interfaz cubren las
herramientas enumeradas arriba; no certifican todas las herramientas de terminal,
navegador, extensiones de terceros, WSL/SSH o todas las cuentas. Steer conservó
la herramienta en curso en esta prueba; su punto de interrupción depende del
agente y la versión de VS Code. [Guía de uso y límites](VSCODE_GUIDE.md).

## Validación inicial de la release (antes de la integración nativa)

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

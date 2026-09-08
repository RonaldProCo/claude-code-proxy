# Astra: instalar en Windows y usar el chat de VS Code

Release independiente **v0.1.36-astra.1** del fork RonaldProCo. El código Rust de
ejecución conserva upstream `55bf0b5`, que ya incluye Astra. El complemento de
VS Code se distribuye por separado; no cambia el binario del proxy.

## Requisitos para otra PC

- Windows 10/11, x64 o ARM64; VS Code de escritorio **1.112 o posterior**, con
  el chat integrado habilitado. La revisión actual se realizó en **1.136.1 x64**.
- Cuenta de ChatGPT con acceso al modelo y cuota de imágenes si las vas a usar.
- [Microsoft Visual C++ Redistributable v14](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
  si falta el runtime: [x64](https://aka.ms/vc14/vc_redist.x64.exe) o
  [ARM64](https://aka.ms/vc14/vc_redist.arm64.exe), según tu equipo.

**No necesitas instalar Rust, Cargo, Node.js ni un servidor MCP.** La herramienta
de imágenes usa el runtime que ya incluye VS Code. No requiere clave de OpenAI
Platform ni privilegios de administrador. La cuenta y las funciones de chat de
VS Code se habilitan según sus propios requisitos; el login del proxy no inicia
sesión en GitHub/Copilot.

## Instalación única

1. Descarga [vscode-setup.zip desde la release](https://github.com/RonaldProCo/claude-code-proxy/releases/tag/v0.1.36-astra.1)
   y su `.sha256`. Verifica el ZIP con `Get-FileHash .\vscode-setup.zip -Algorithm SHA256`,
   extráelo y abre PowerShell en la carpeta extraída. `SOURCE.json` identifica el
   commit del paquete. No contiene cuentas ni credenciales.
2. Instala el binario publicado (el instalador comprueba SHA-256 y versión):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. Inicia sesión con tu cuenta en esa PC y completa el acceso en el navegador:

   ```powershell
   $env:CCP_CONFIG_DIR = "$env:USERPROFILE\.config\claude-code-proxy"
   & "$env:LOCALAPPDATA\Programs\claude-code-proxy\claude-code-proxy.exe" codex auth login
   ```

   Cada equipo guarda su propia sesión. No copies el archivo de tokens desde otra PC.
4. Configura el chat y la extensión de imágenes nativa:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\configure-vscode.ps1
   ```

   El script instala el VSIX incluido, añade Astra, habilita imágenes y
   compactación automática, configura Steer y crea el acceso directo de inicio.
   Combina los ajustes y crea respaldos `.bak` junto a los archivos modificados.
   Conserva otros modelos, servidores, límites del agente y permisos. Si tenías
   nuestro antiguo MCP `codex-images`, retira solo esa entrada al migrar.
   Si solo necesitas texto, usa `-SkipImages`.
5. Abre `%LOCALAPPDATA%\Programs\claude-code-proxy\Iniciar proxy.lnk`.
   El proxy queda en segundo plano, visible en el Administrador de tareas.
   **No dejes una terminal abierta.** También puedes ejecutar `start-proxy.ps1`:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\start-proxy.ps1
   ```

6. En VS Code ejecuta **Developer: Reload Window**. Abre un chat **Local**, modo
   **Agent**, y selecciona **Other Models > Codex via Proxy >
   GPT-6 Astra (Codex subscription)**. En **Configure Tools** comprueba
   **Codex Proxy Tools**, que contiene **Codex: Generate Image** y **Codex: Edit Image**.
7. Pide «Usa #codexGenerateImage para crear un robot azul sobre fondo blanco».
   Revisa la confirmación de herramienta cuando VS Code la solicite.

Desde entonces solo inicias el proxy y usas VS Code. No hay un servidor MCP de
imágenes que encender. Las imágenes se guardan en `%USERPROFILE%\Pictures\Codex`.
Detalles de mensajes intermedios, herramientas, contexto, compactación y pruebas:
[VSCODE_GUIDE.md](VSCODE_GUIDE.md).

## Instalar sobre una configuración existente

Los scripts aceptan `-InstallDir` y `-ProxyConfigDir`. Usa el mismo directorio de
configuración en el inicio y en `CCP_CONFIG_DIR` al autenticar. Para otra carpeta
de usuario de VS Code, usa `-VSCodeUserDir`. En perfiles con extensiones separadas,
instala además el VSIX en el perfil donde vas a usar el chat.

Desde el código fuente, pasa
`-VsixPath .\vscode-extension\dist\codex-proxy-tools.vsix` después de empaquetarlo.
El ZIP de instalación ya incluye ese archivo. Los scripts requieren JSON válido
en los archivos que van a combinar. Si tienes JSONC con comentarios o comas
finales, el script se detiene antes de escribir; aplica manualmente los ejemplos.
`ExecutionPolicy Bypass` solo se aplica al proceso que ejecuta el script.

## Configuración manual

Instala `codex-proxy-tools.vsix` con **Extensions: Install from VSIX** o con
`code --install-extension .\codex-proxy-tools.vsix`. En
`%APPDATA%\Code\User\chatLanguageModels.json`, combina esta entrada con el array
de proveedores existente:

```json
{
  "name": "Codex via Proxy",
  "vendor": "customendpoint",
  "apiKey": "unused",
  "apiType": "messages",
  "models": [{
    "id": "gpt-6-astra",
    "name": "GPT-6 Astra (Codex subscription)",
    "url": "http://127.0.0.1:18765/v1/messages",
    "toolCalling": true,
    "vision": true,
    "maxInputTokens": 240000,
    "maxOutputTokens": 32000,
    "thinking": true,
    "supportsReasoningEffort": ["low", "medium", "high", "xhigh", "max"],
    "reasoningEffortFormat": "messages"
  }]
}
```

`unused` satisface el campo de la conexión local. La autenticación real es la
sesión del proxy. Los límites son conservadores, no una promesa de contexto de
un millón de tokens. Si ya existe el proveedor, añade Astra a sus modelos.

En `settings.json`, combina:

```json
{
  "chat.requestQueuing.defaultAction": "steer",
  "github.copilot.chat.summarizeAgentConversationHistory.enabled": true,
  "chat.byokUtilityModelDefault": "mainAgent",
  "codexProxyTools.proxyUrl": "http://127.0.0.1:18765"
}
```

Para las imágenes, combina `"imagesApi": true` dentro del objeto `codex` de
`%USERPROFILE%\.config\claude-code-proxy\config.json` y reinicia el proxy.
El script de inicio también fija `CCP_CODEX_IMAGES_API=1`. Si cambias el puerto,
actualiza las URL del modelo y de la extensión.

## Actualizar o comprobar el binario

Detén el proxy antes de reemplazar su ejecutable. `install.ps1` descarga de este
fork, verifica la suma y comprueba la versión. No modifica la sesión del proxy.

```powershell
$env:CCP_CONFIG_DIR = "$env:USERPROFILE\.config\claude-code-proxy"
$proxy = "$env:LOCALAPPDATA\Programs\claude-code-proxy\claude-code-proxy.exe"
& $proxy --version
& $proxy models | Select-String 'gpt-6-astra'
& $proxy codex auth status
```

Debe mostrar `0.1.36-astra.1` y los modelos `gpt-6-astra` y `gpt-6-astra-fast`.
El lanzador evita iniciar otra instancia si ese binario ya escucha en el puerto.
Si otro programa ocupa el puerto, informa del conflicto.

## Problemas frecuentes

- `invalid_refresh_token`: ejecuta `codex auth login` usando el mismo
  `CCP_CONFIG_DIR`, completa el acceso y reinicia el proxy.
- Conexión rechazada: inicia el proxy y revisa el puerto y sus registros en
  `.config\claude-code-proxy\logs`. La extensión no arranca el proxy por su cuenta.
- `VCRUNTIME140.dll` ausente: instala el runtime de Microsoft enlazado arriba.
- Imágenes HTTP 404: habilita `codex.imagesApi` y reinicia el proxy.
- La herramienta no aparece: comprueba que el VSIX esté instalado y habilitado
  en el perfil actual; recarga la ventana y revisa **Configure Tools** en Agent.
- El modelo dice no tener herramientas: comprueba Agent, la selección de
  herramientas y `toolCalling: true` en el modelo.
- La corrección abre otro chat: usa **Steer** en la misma sesión; revisa el botón,
  el modificador Alt y `chat.requestQueuing.defaultAction`.
- Contexto excesivo: usa `/compact`, vuelve a adjuntar los archivos necesarios y
  evita enviar registros completos. Revisa [la guía de contexto](VSCODE_GUIDE.md).
- HTTP 403/429 o rechazo de modelo: revisa el acceso y cuota de la cuenta.
  Este fork no amplía las cuotas ni habilita modelos que tu cuenta no tenga.

## Opcional: extensión Claude Code

Es una integración diferente del chat descrito arriba. Combina en el objeto
`env` de `%USERPROFILE%\.claude\settings.json`, preservando el resto:

```json
{
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:18765",
  "ANTHROPIC_AUTH_TOKEN": "unused",
  "ANTHROPIC_MODEL": "gpt-6-astra[1m]",
  "ANTHROPIC_SMALL_FAST_MODEL": "gpt-5.6-luna[1m]",
  "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "272000",
  "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
  "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK": "1"
}
```

Sus ajustes pueden sobrescribir esas variables. `[1m]` no amplía el contexto
efectivo de la suscripción. Codex Proxy Tools aporta herramientas al chat
integrado de VS Code, no al agente privado de la extensión Claude Code.

## Reconstruir el complemento (desarrolladores)

Solo para empaquetar el VSIX necesitas Node 22+: dentro de `vscode-extension/`,
ejecuta `npm ci`, `npm test` y `npm run package`. El resultado está en
`vscode-extension/dist/codex-proxy-tools.vsix`. `scripts/package-vscode.ps1`
arma el ZIP de instalación y sus sumas con el commit de procedencia.
El workflow **VS Code package** prueba y publica esos complementos sobre la
release existente sin recompilar ni reemplazar el binario Rust.

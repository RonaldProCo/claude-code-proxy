# Astra: Windows y el chat integrado de VS Code

Esta versión del fork conserva el código de ejecución de upstream `55bf0b5`.
Incluye el soporte de Astra de `main` y se publica de forma independiente como
`v0.1.36-astra.1`.

## Configurar otra PC desde cero

Requisitos: Windows x64 o ARM64, VS Code con su chat integrado habilitado, una
cuenta de ChatGPT con acceso a Astra y, para las herramientas de imágenes,
[Node.js 22 LTS o posterior](https://nodejs.org/en/download). El binario del proxy
funciona sin Node.js. No necesitas Rust, Cargo ni compilar el proyecto.

1. Descarga `vscode-setup.zip` y extráelo. Sus scripts también están en `scripts/`
   en este repositorio. Abre PowerShell en la carpeta extraída.
2. Instala el **binario de la release** con comprobación SHA-256:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. Inicia sesión en la nueva PC. Cada PC guarda su propia sesión; no copies
   credenciales ni tokens del equipo anterior:

   ```powershell
   $env:CCP_CONFIG_DIR = "$env:USERPROFILE\.config\claude-code-proxy"
   & "$env:LOCALAPPDATA\Programs\claude-code-proxy\claude-code-proxy.exe" codex auth login
   ```

4. Añade Astra y la herramienta de imágenes al chat de VS Code:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\configure-vscode.ps1
   ```

   El script combina las entradas con las existentes y guarda copias `.bak` junto
   a los archivos modificados. Si solo quieres texto, usa `-SkipImages`. Los
   archivos JSON existentes deben ser JSON válido; si contienen comentarios,
   combina manualmente los ejemplos siguientes. El parámetro `ExecutionPolicy`
   se aplica únicamente a ese proceso de PowerShell.

5. Inicia el proxy y mantén abierta esa terminal:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\start-proxy.ps1
   ```

6. En VS Code abre un chat nuevo, despliega el selector de modelos y selecciona
   **Other Models > Codex via Proxy > GPT-6 Astra (Codex subscription)**. Si no aparece,
   ejecuta **Developer: Reload Window** desde la paleta de comandos.
7. Ejecuta **MCP: List Servers**, selecciona **codex-images** e inícialo. Revisa
   y acepta la confianza de ese servidor cuando VS Code la solicite. En modo
   Agent, habilita `codex_generate_image` y `codex_edit_image` entre las herramientas.
   Prueba: “Usa codex_generate_image para crear un robot azul sobre fondo blanco”.

Los scripts aceptan `-InstallDir` para instalar en otro directorio. Para perfiles
distintos de VS Code, `configure-vscode.ps1` acepta `-VSCodeUserDir`. Para otra
carpeta de credenciales/configuración, usa el mismo `-ProxyConfigDir` en la
configuración y el inicio, y `CCP_CONFIG_DIR` al autenticar.

## Configuración manual del chat integrado

Abre **Chat: Manage Language Models**, o el archivo de usuario
`%APPDATA%\Code\User\chatLanguageModels.json`, y añade esta entrada al array:

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

Los límites son conservadores y no afirman que tu cuenta permita un millón de
tokens. `unused` solo satisface el campo de la conexión local; la autenticación
real se realiza con `codex auth login`.

Para imágenes, combina `"imagesApi": true` dentro del objeto `codex` en
`%USERPROFILE%\.config\claude-code-proxy\config.json`. El script de inicio
establece explícitamente esta ubicación con `CCP_CONFIG_DIR`.
Añade a `servers` en **MCP: Open User Configuration**:

```json
"codex-images": {
  "type": "stdio",
  "command": "node",
  "args": ["C:/RUTA/claude-code-proxy/codex-images-mcp.mjs"],
  "env": { "CCP_IMAGE_PROXY_URL": "http://127.0.0.1:18765" }
}
```

Sustituye la ruta por el archivo instalado. Las imágenes se guardan en
`%USERPROFILE%\Pictures\Codex`; `CCP_IMAGE_OUTPUT_DIR` permite cambiarla.
El puente MCP solo llama al proxy local. Las imágenes y los prompts usan la
sesión de ChatGPT del proxy; el puente no lee ni incluye credenciales.
Las ediciones reciben rutas absolutas a imágenes elegidas por el usuario y
guardan una imagen nueva, conservando los originales.

## Instalar o actualizar

Descarga el ZIP para tu arquitectura y su archivo `.sha256` desde
[Releases](https://github.com/RonaldProCo/claude-code-proxy/releases/latest).
También puedes descargar y ejecutar `scripts/install.ps1`: verifica la suma y la
versión antes de copiar el ejecutable. Su destino predeterminado es
`%LOCALAPPDATA%\Programs\claude-code-proxy`; acepta `-InstallDir` para otro destino.
Detén el proceso anterior antes de reemplazar un ejecutable en uso.

```powershell
$proxy = "$env:LOCALAPPDATA\Programs\claude-code-proxy\claude-code-proxy.exe"
& $proxy --version
& $proxy models | Select-String 'gpt-6-astra'
& $proxy codex auth status
```

Si el proxy ya tiene una sesión válida, consérvala. Si no, ejecuta
`& $proxy codex auth login` y completa el acceso con tu cuenta de ChatGPT.
El proxy utiliza su propia sesión y no lee automáticamente las credenciales de
la aplicación Codex. No requiere una clave de OpenAI Platform.

## Iniciar el proxy con imágenes

```powershell
$env:CCP_CODEX_IMAGES_API = '1'
& $proxy serve
```

El servidor escucha en `http://127.0.0.1:18765`. Conserva esa terminal abierta.
También puedes habilitarlo de forma persistente con `codex.imagesApi: true` en
el `config.json` del proxy, combinándolo con las opciones existentes.

## Opcional: configurar la extensión Claude Code

Combina estas variables con el objeto `env` de `%USERPROFILE%\.claude\settings.json`.
Conserva los demás ajustes y variables que ya tengas:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:18765",
    "ANTHROPIC_AUTH_TOKEN": "unused",
    "ANTHROPIC_MODEL": "gpt-6-astra[1m]",
    "ANTHROPIC_SMALL_FAST_MODEL": "gpt-5.6-luna[1m]",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "272000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK": "1"
  }
}
```

En la extensión **Claude Code** de VS Code, comprueba que sus ajustes de modelo y
entorno no sobrescriban estas variables con el modelo anterior. Reinicia la sesión
de chat después de cambiar la configuración. Para seleccionar Astra expresamente
usa `gpt-6-astra` en el selector de modelo. Los alias `opus`, `sonnet` y `haiku`
mantienen sus asignaciones originales. El límite de compactación de arriba es una
opción conservadora; `[1m]` no aumenta los límites efectivos de tu suscripción.

## Generación de imágenes

El endpoint existente `POST /v1/images/generations` acepta, por ejemplo:

```json
{"model":"gpt-image-2","prompt":"A small blue robot on a white background"}
```

Devuelve imágenes en `data[].b64_json`. El cliente o una herramienta debe guardar
ese contenido como imagen. Habilitar el endpoint por sí solo no añade un botón o
una herramienta de imágenes al chat de Claude Code. Para usarlo desde el chat,
Claude Code puede llamar al endpoint mediante sus herramientas locales siguiendo
las instrucciones de tu proyecto. La generación usa la cuota de imágenes de tu
cuenta de ChatGPT.

## Comprobar

1. `--version` muestra `0.1.36-astra.1`.
2. `models` incluye `gpt-6-astra` y `gpt-6-astra-fast`.
3. El chat nuevo de Claude Code obtiene una respuesta y el monitor del proxy
   registra una solicitud con Astra. En el chat integrado selecciona el modelo
   en su selector; en la extensión Claude Code configura sus propias variables.
4. Una solicitud al endpoint de imágenes devuelve una imagen válida.

El registro local del modelo no garantiza que una cuenta concreta tenga acceso.
Si el proveedor rechaza una solicitud, revisa el error que devuelve el proxy.

## Problemas frecuentes

- `invalid_refresh_token` o “Could not validate your refresh token”: vuelve a
  ejecutar `codex auth login` con el mismo `CCP_CONFIG_DIR`, completa el acceso
  en el navegador y reinicia el proxy para cargar la sesión renovada.
- Conexión rechazada: inicia `start-proxy.ps1` y verifica el puerto de la URL
  configurada en VS Code. El proxy debe seguir ejecutándose.
- HTTP 404 al generar imágenes: habilita `codex.imagesApi` o
  `CCP_CODEX_IMAGES_API=1` y reinicia el proxy.
- La herramienta de imágenes no aparece: instala Node.js, reinicia VS Code y
  revisa **MCP: List Servers > codex-images**. Confirma la confianza del servidor
  y habilita sus herramientas en modo Agent.
- El proveedor rechaza Astra o la generación por cuota: revisa el acceso y la
  cuota de la cuenta autenticada. La release no modifica las cuotas ni desbloquea
  modelos que el proveedor no haya habilitado para tu cuenta.

La guía de configuración de MCP de VS Code está en
[la documentación oficial](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

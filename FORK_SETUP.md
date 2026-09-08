# Astra: Windows y Claude Code en VS Code

Esta versión del fork conserva el código de ejecución de upstream `55bf0b5`.
Incluye el soporte de Astra de `main` y se publica de forma independiente como
`v0.1.36-astra.1`.

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

## Configurar Claude Code

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
   registra una solicitud con Astra.
4. Una solicitud al endpoint de imágenes devuelve una imagen válida.

El registro local del modelo no garantiza que una cuenta concreta tenga acceso.
Si el proveedor rechaza una solicitud, revisa el error que devuelve el proxy.

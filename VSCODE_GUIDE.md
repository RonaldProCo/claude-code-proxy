# VS Code: herramientas, contexto y mensajes durante el trabajo

Esta guía se refiere al **chat integrado de VS Code, modo Agent, sesión Local,
proveedor Codex via Proxy y modelo GPT-6 Astra**. La extensión Claude Code y la
extensión oficial de Codex tienen sus propios agentes y ajustes. Elegir el mismo
modelo no hace que esos agentes se comporten igual.

## Uso diario: encender el proxy y abrir VS Code

Después de la instalación única de [FORK_SETUP.md](FORK_SETUP.md), abre
`%LOCALAPPDATA%\Programs\claude-code-proxy\Iniciar proxy.lnk`. Puedes copiar ese
acceso directo al escritorio. El lanzador termina y deja `claude-code-proxy.exe`
en segundo plano, visible en el Administrador de tareas. No requiere privilegios
de administrador, terminal abierta ni un servidor MCP para imágenes.

La extensión **Codex Proxy Tools** usa el proceso de extensiones que ya tiene
VS Code. No añade un servicio, tarea programada, arranque automático ni proceso
Node externo. El ejecutable del proxy mantiene el código upstream de esta release.
El proxy por sí solo no puede registrar herramientas en el editor: el VSIX se
instala una vez para aportar esa integración.

Los registros del inicio en segundo plano quedan en
`%USERPROFILE%\.config\claude-code-proxy\logs`. Para ver el monitor interactivo,
inicia `start-proxy.ps1 -Foreground` cuando el proxy esté detenido. Para detener
el servicio de uso diario, finaliza **ese** `claude-code-proxy.exe` en el
Administrador de tareas cuando no tengas solicitudes pendientes.

## Guiar el trabajo sin abrir otra conversación

El configurador establece este ajuste de usuario:

```json
"chat.requestQueuing.defaultAction": "steer"
```

Mientras Agent trabaja, escribe la corrección en **la misma caja de chat** y
envíala con **Steer**. Por ejemplo: «Mantén el objetivo anterior; cambia el color
a verde y conserva las pruebas pendientes». El mensaje se incorpora como una
orientación dentro de esa sesión. No uses **New Chat**, **Send to New Chat** ni
el modificador Alt para esa acción. Comprueba el texto del botón, porque los
atajos pueden variar con tu configuración de teclado y la versión de VS Code.

| Acción | Cuándo usarla |
| --- | --- |
| Steer | Corregir o completar la tarea que está ejecutándose |
| Queue | Dejar otra petición pendiente hasta que termine la actual |
| Stop | Cancelar expresamente la ejecución actual |
| New Chat / Send to New Chat | Empezar una conversación separada |

Steer depende del agente de VS Code: le solicita ceder el control para incluir
el mensaje. Puede esperar un punto de control o finalizar una solicitud de modelo
y continuar con otra dentro de la misma sesión. No modifica retroactivamente
una llamada HTTP ya enviada ni deshace una herramienta que ya produjo un efecto.
Una generación de imagen en marcha puede terminar con el prompt original;
aplica la corrección mediante una edición posterior si afecta a esa imagen.
El proxy no controla el botón ni promete una reproducción exacta del agente Codex.
Fuente: [ajustes oficiales de chat](https://code.visualstudio.com/docs/agents/reference/ai-settings).

## Herramientas

Usa **Agent** y el selector **Configure Tools** junto al selector de modelo.
Comprueba que estén disponibles las herramientas necesarias de lectura, búsqueda,
edición, terminal y las dos de **Codex Proxy Tools**. El modelo declara soporte
`toolCalling: true` y `vision: true`; el editor ejecuta las herramientas y devuelve
sus resultados al modelo a través del proxy.

Una herramienta desmarcada no estará disponible para el agente. Las herramientas
de terminal, depuración, navegador y las de otras extensiones conservan sus
dependencias, permisos y restricciones de VS Code. Este fork no elimina las
confirmaciones ni garantiza todas las extensiones de terceros. El configurador
tampoco cambia `chat.agent.maxRequests`: ese límite cuenta pasos del agente,
no tokens. Si alcanzas el límite, usa Continue y revisa el ajuste según tu uso.

**Generación nativa:** pide «Usa #codexGenerateImage para crear un zorro naranja
con una estrella azul sobre fondo blanco». VS Code puede pedir la autorización
estándar de la herramienta. Tras completarse, devuelve una vista previa y una
ruta local. **Edición nativa:** pide «Usa #codexEditImage para cambiar esta imagen
a verde», indicando o adjuntando la imagen local correspondiente.

| Herramienta | Resultado y límites |
| --- | --- |
| Codex: Generate Image (`#codexGenerateImage`) | Una imagen nueva con `gpt-image-2` |
| Codex: Edit Image (`#codexEditImage`) | Lee 1–5 archivos locales seleccionados y guarda una imagen nueva; conserva originales |

La carpeta predeterminada es `%USERPROFILE%\Pictures\Codex`.
`codexProxyTools.outputDirectory` admite otra ruta absoluta local. PNG, JPEG,
WebP y GIF son entradas admitidas, hasta 20 MiB por archivo. Un nombre existente
no se sobrescribe. Las imágenes seleccionadas para editar se envían a ChatGPT,
mediante la sesión del proxy; ambas herramientas consumen la cuota de imágenes.
No necesitan clave de OpenAI Platform. Cancelar corta la espera local, pero el
servicio puede haber iniciado el trabajo y consumir cuota. No se reintenta
automáticamente tras cancelación o al agotarse la espera de cinco minutos.

En WSL/SSH/Containers la extensión corre del lado local: el proxy y las rutas de
imágenes deben estar en ese mismo equipo. No admite rutas remotas como imágenes
de entrada ni VS Code Web. Desarrollo basado en la
[API oficial de herramientas](https://code.visualstudio.com/api/extension-guides/ai/tools).

## Contexto y compactación

El contexto combina instrucciones, conversación y archivos/resultados que el
editor incorpora. Tener un repositorio abierto no significa que todo su contenido
se envíe en cada petición. Adjunta los archivos importantes con **Add Context** o
`#`, y pide al agente que busque y lea los demás. Conserva las restricciones del
proyecto en `AGENTS.md` o `.github/copilot-instructions.md` cuando deban durar más
que una conversación. No guardes credenciales en esos archivos.

La configuración usa **240.000 tokens de entrada** y **32.000 de salida** como
presupuesto conservador para Astra. No certifica un máximo de un millón en la
suscripción. Instrucciones, historial, esquemas de herramientas y sus resultados
consumen ese presupuesto; una cifra anunciada para otra API no amplía la cuenta.
No cambies el límite solo para ocultar un error de contexto.

La compactación automática queda habilitada con:

```json
"github.copilot.chat.summarizeAgentConversationHistory.enabled": true
```

VS Code resume el historial al acercarse al límite. Puedes iniciar el proceso
con `/compact` en la misma sesión y después continuar. Añade instrucciones como
«conserva el objetivo, las restricciones, las decisiones, los archivos cambiados
y las pruebas pendientes» cuando la versión permita acompañar el comando.
El resumen puede perder detalles: vuelve a leer un archivo o vuelve a adjuntarlo
si un dato exacto resulta necesario. No es memoria ilimitada ni borra archivos.

En instalaciones nuevas el configurador establece
`chat.byokUtilityModelDefault: "mainAgent"`, para que las funciones auxiliares
que respetan esa selección usen el modelo principal. Si ya elegiste otro valor,
lo conserva. Revisa también selecciones explícitas de `chat.utilityModel` y
`chat.utilitySmallModel` si una función auxiliar usa otro proveedor. Los cambios
se aplican a las funciones del editor, no a la autenticación de la suscripción.

Fuentes: [contexto del agente](https://code.visualstudio.com/docs/agents/concepts/context),
[gestión del uso y compactación](https://code.visualstudio.com/docs/agents/guides/optimize-usage),
[referencia de ajustes](https://code.visualstudio.com/docs/agents/reference/ai-settings).

## Prueba breve en otra PC

1. Pide una respuesta exacta, por ejemplo `ASTRA_OK`, y verifica Astra en el selector.
2. Pide leer un archivo de prueba y crear otro con un dato que solo exista allí.
3. Mientras trabaja, envía una corrección con Steer; comprueba que se mantiene
   la misma sesión, el objetivo original y que el resultado incorpora el cambio.
4. Pide una imagen con `#codexGenerateImage` y después edítala con
   `#codexEditImage`. Verifica las dos rutas y que el original siga intacto.
5. Ejecuta `/compact` y pide recordar el objetivo y el dato de control. Contrasta
   la respuesta con el archivo original.

Consulta [VALIDATION.md](VALIDATION.md) para distinguir pruebas realmente
ejecutadas de comportamiento documentado. Ninguna prueba breve demuestra todas
las herramientas, todas las ventanas de contexto o todas las cuentas posibles.

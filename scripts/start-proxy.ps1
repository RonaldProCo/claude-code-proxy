param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\claude-code-proxy'),
    [string]$ProxyConfigDir = (Join-Path $env:USERPROFILE '.config\claude-code-proxy')
)
$ErrorActionPreference = 'Stop'
$binary = Join-Path $InstallDir 'claude-code-proxy.exe'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Run install.ps1 first, or supply -InstallDir.' }
$env:CCP_CONFIG_DIR = $ProxyConfigDir
$env:CCP_CODEX_IMAGES_API = '1'
& $binary serve
exit $LASTEXITCODE

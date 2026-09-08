param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\claude-code-proxy'),
    [string]$ProxyConfigDir = (Join-Path $env:USERPROFILE '.config\claude-code-proxy'),
    [switch]$Foreground
)
$ErrorActionPreference = 'Stop'
$binary = Join-Path $InstallDir 'claude-code-proxy.exe'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Run install.ps1 first, or supply -InstallDir.' }
$env:CCP_CONFIG_DIR = $ProxyConfigDir
$env:CCP_CODEX_IMAGES_API = '1'
if ($Foreground) {
    & $binary serve
    exit $LASTEXITCODE
}
$configFile = Join-Path $ProxyConfigDir 'config.json'
$config = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json }
$port = if ($config.port) { [int]$config.port } else { 18765 }
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $existing = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
    if ($existing.Path -eq [System.IO.Path]::GetFullPath($binary)) {
        Write-Host "Proxy already running (PID $($existing.Id), port $port)."
        exit 0
    }
    throw "Port $port is occupied by another process. The proxy was not started."
}
$logDir = Join-Path $ProxyConfigDir 'logs'
[System.IO.Directory]::CreateDirectory($logDir) | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
$errorLog = Join-Path $logDir "proxy-$stamp.stderr.log"
$proxyProcess = Start-Process -FilePath $binary -ArgumentList @('serve', '--no-monitor') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir "proxy-$stamp.stdout.log") -RedirectStandardError $errorLog
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 250
    $proxyProcess.Refresh()
    if ($proxyProcess.HasExited) { throw "Proxy exited. Check $errorLog" }
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/models" -TimeoutSec 2
        Write-Host "Proxy running in background (PID $($proxyProcess.Id), port $port). Logs: $logDir"
        exit 0
    } catch { }
}
throw "Proxy was started but readiness was not confirmed. Check $errorLog before starting another instance."

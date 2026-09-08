param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\claude-code-proxy'),
    [string]$VSCodeUserDir = (Join-Path $env:APPDATA 'Code\User'),
    [string]$ProxyConfigDir = (Join-Path $env:USERPROFILE '.config\claude-code-proxy'),
    [switch]$SkipImages
)
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Save-Config($Path, $Value) {
    if (Test-Path -LiteralPath $Path) { Copy-Item -LiteralPath $Path -Destination "$Path.$stamp.bak" }
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [System.IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100) + [Environment]::NewLine, $utf8)
}
function Set-Property($Object, $Name, $Value) {
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}
$modelsFile = Join-Path $VSCodeUserDir 'chatLanguageModels.json'
$mcpFile = Join-Path $VSCodeUserDir 'mcp.json'
$configFile = Join-Path $ProxyConfigDir 'config.json'
# Parse every existing file before any writes. JSONC needs manual merging.
$models = @(if (Test-Path -LiteralPath $modelsFile) { Get-Content -LiteralPath $modelsFile -Raw | ConvertFrom-Json })
$config = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$mcp = if (-not $SkipImages -and (Test-Path -LiteralPath $mcpFile)) { Get-Content -LiteralPath $mcpFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{ servers = [pscustomobject]@{} } }
$node = if (-not $SkipImages) { (Get-Command node -ErrorAction Stop).Source }
$bridgeSource = Join-Path $PSScriptRoot 'codex-images-mcp.mjs'
if (-not $SkipImages -and -not (Test-Path -LiteralPath $bridgeSource)) { throw 'Keep codex-images-mcp.mjs next to this script.' }
$port = if ($config.port) { $config.port } else { 18765 }
$url = "http://127.0.0.1:$port"
$provider = @($models | Where-Object { $_.name -eq 'Codex via Proxy' -and $_.vendor -eq 'customendpoint' })
if ($provider.Count -gt 1) { throw 'Multiple Codex via Proxy entries; merge them manually first.' }
if ($provider.Count -eq 0) {
    $provider = @([pscustomobject]@{ name = 'Codex via Proxy'; vendor = 'customendpoint'; apiKey = 'unused'; apiType = 'messages'; models = @() })
    $models += $provider[0]
}
$astra = [pscustomobject]@{
    id = 'gpt-6-astra'; name = 'GPT-6 Astra (Codex subscription)'; url = "$url/v1/messages"
    toolCalling = $true; vision = $true; maxInputTokens = 240000; maxOutputTokens = 32000
    thinking = $true; supportsReasoningEffort = @('low', 'medium', 'high', 'xhigh', 'max'); reasoningEffortFormat = 'messages'
}
Set-Property $provider[0] 'apiType' 'messages'
Set-Property $provider[0] 'models' (@($provider[0].models | Where-Object { $_.id -ne 'gpt-6-astra' }) + $astra)
if (-not $config.codex) { Set-Property $config 'codex' ([pscustomobject]@{}) }
if (-not $SkipImages) {
    Set-Property $config.codex 'imagesApi' $true
    if (-not $mcp.servers) { Set-Property $mcp 'servers' ([pscustomobject]@{}) }
    $bridge = Join-Path $InstallDir 'codex-images-mcp.mjs'
    [System.IO.Directory]::CreateDirectory($InstallDir) | Out-Null
    if ([System.IO.Path]::GetFullPath($bridgeSource) -ne [System.IO.Path]::GetFullPath($bridge)) { Copy-Item -LiteralPath $bridgeSource -Destination $bridge -Force }
    Set-Property $mcp.servers 'codex-images' ([pscustomobject]@{ type = 'stdio'; command = $node; args = @($bridge); env = [pscustomobject]@{ CCP_IMAGE_PROXY_URL = $url } })
    Save-Config $mcpFile $mcp
}
Save-Config $modelsFile @($models)
Save-Config $configFile $config
Write-Host 'Configured GPT-6 Astra in VS Code. Existing settings were backed up beside each file.'
Write-Host "Start the release binary with CCP_CONFIG_DIR=$ProxyConfigDir, then open a new VS Code chat and select GPT-6 Astra (Codex subscription)."
if (-not $SkipImages) { Write-Host 'Start codex-images from MCP: List Servers. Images are saved to Pictures\Codex.' }

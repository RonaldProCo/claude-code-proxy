param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\claude-code-proxy'),
    [string]$VSCodeUserDir = (Join-Path $env:APPDATA 'Code\User'),
    [string]$ProxyConfigDir = (Join-Path $env:USERPROFILE '.config\claude-code-proxy'),
    [string]$VsixPath,
    [switch]$SkipImages
)
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
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
$settingsFile = Join-Path $VSCodeUserDir 'settings.json'
$configFile = Join-Path $ProxyConfigDir 'config.json'
# Parse every existing file before any writes. JSONC needs manual merging.
$models = @()
if (Test-Path -LiteralPath $modelsFile) {
    $parsedModels = Get-Content -LiteralPath $modelsFile -Raw | ConvertFrom-Json
    foreach ($entry in $parsedModels) { $models += $entry }
}
$config = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$settings = if (Test-Path -LiteralPath $settingsFile) { Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$mcp = if (-not $SkipImages -and (Test-Path -LiteralPath $mcpFile)) { Get-Content -LiteralPath $mcpFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{ servers = [pscustomobject]@{} } }
if (-not $SkipImages) {
    if (-not $VsixPath) { $VsixPath = Join-Path $PSScriptRoot 'codex-proxy-tools.vsix' }
    if (-not (Test-Path -LiteralPath $VsixPath)) { throw 'Extract the current vscode-setup.zip, or supply -VsixPath with the native extension package.' }
    $codeCommand = (Get-Command code -ErrorAction Stop).Source
}
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
Set-Property $settings 'chat.requestQueuing.defaultAction' 'steer'
Set-Property $settings 'github.copilot.chat.summarizeAgentConversationHistory.enabled' $true
# Preserve explicit utility model choices; set a default for BYOK sessions only.
if (-not $settings.PSObject.Properties['chat.byokUtilityModelDefault']) { Set-Property $settings 'chat.byokUtilityModelDefault' 'mainAgent' }
if (-not $SkipImages) {
    Set-Property $config.codex 'imagesApi' $true
    & $codeCommand --install-extension $VsixPath --force
    if ($LASTEXITCODE -ne 0) { throw 'VS Code could not install the native extension. Configuration was not changed.' }
    Set-Property $settings 'codexProxyTools.proxyUrl' $url
    # Migrate only the bridge created by older versions of this setup.
    $oldBridge = $mcp.servers.'codex-images'
    if ($oldBridge -and $oldBridge.type -eq 'stdio' -and @($oldBridge.args).Count -eq 1 -and [System.IO.Path]::GetFileName($oldBridge.args[0]) -eq 'codex-images-mcp.mjs') {
        $mcp.servers.PSObject.Properties.Remove('codex-images')
        Save-Config $mcpFile $mcp
    }
}
Save-Config $modelsFile @($models)
Save-Config $configFile $config
Save-Config $settingsFile $settings
[System.IO.Directory]::CreateDirectory($InstallDir) | Out-Null
$starter = Join-Path $InstallDir 'start-proxy.ps1'
$starterSource = Join-Path $PSScriptRoot 'start-proxy.ps1'
if ([System.IO.Path]::GetFullPath($starterSource) -ne [System.IO.Path]::GetFullPath($starter)) { Copy-Item -LiteralPath $starterSource -Destination $starter -Force }
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $InstallDir 'Iniciar proxy.lnk'))
$shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $starter + '" -InstallDir "' + $InstallDir + '" -ProxyConfigDir "' + $ProxyConfigDir + '"'
$shortcut.WorkingDirectory = $InstallDir
$shortcut.WindowStyle = 7
$shortcut.Save()
Write-Host 'Configured GPT-6 Astra in VS Code. Existing settings were backed up beside each file.'
Write-Host "Start with: $InstallDir\Iniciar proxy.lnk. The proxy stays in the background; no terminal needs to remain open."
Write-Host 'Reload the VS Code window and select GPT-6 Astra (Codex subscription) in Agent chat. Follow-up messages use Steer.'
if (-not $SkipImages) { Write-Host 'Enable Codex: Generate Image and Codex: Edit Image in the tool picker. No image MCP server is needed.' }

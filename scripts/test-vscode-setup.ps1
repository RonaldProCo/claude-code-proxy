# Integration test of configuration merging. The VS Code CLI is stubbed here;
# native tool registration and image generation are validated separately in VS Code.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('ccp-setup-test-' + [guid]::NewGuid().ToString('N'))
$oldPath = $env:PATH
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Put-Json($Path, $Value) { [System.IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100)) }
try {
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $root 'code.cmd'), "@echo off`r`nexit /b 0`r`n")
    [System.IO.File]::WriteAllText((Join-Path $root 'test.vsix'), 'CLI fixture only')
    $env:PATH = $root + [System.IO.Path]::PathSeparator + $oldPath
    foreach ($scenario in @('clean', 'existing')) {
        $userDir = Join-Path $root "$scenario\User"
        $configDir = Join-Path $root "$scenario\config"
        $installDir = Join-Path $root "$scenario\install"
        [System.IO.Directory]::CreateDirectory($userDir) | Out-Null
        [System.IO.Directory]::CreateDirectory($configDir) | Out-Null
        if ($scenario -eq 'existing') {
            Put-Json (Join-Path $userDir 'chatLanguageModels.json') @(@{ name = 'Other'; vendor = 'other'; models = @() }, @{ name = 'Codex via Proxy'; vendor = 'customendpoint'; apiType = 'messages'; models = @(@{ id = 'gpt-5.6-sol' }) })
            Put-Json (Join-Path $userDir 'settings.json') @{ 'editor.fontSize' = 17; 'chat.agent.maxRequests' = 50; 'chat.byokUtilityModelDefault' = 'copilot' }
            Put-Json (Join-Path $userDir 'mcp.json') @{ servers = @{ other = @{ command = 'preserve' }; 'codex-images' = @{ type = 'stdio'; args = @('C:\installed\codex-images-mcp.mjs') } }; inputs = @() }
            Put-Json (Join-Path $configDir 'config.json') @{ port = 19999; aliasProvider = 'codex'; codex = @{ responsesApi = $true } }
        }
        foreach ($iteration in 1..2) {
            & "$PSScriptRoot\configure-vscode.ps1" -InstallDir $installDir -VSCodeUserDir $userDir -ProxyConfigDir $configDir -VsixPath (Join-Path $root 'test.vsix')
            $raw = Get-Content (Join-Path $userDir 'chatLanguageModels.json') -Raw
            Assert ($raw.TrimStart().StartsWith('[')) 'Model providers must remain an array, including a singleton.'
            $models = $raw | ConvertFrom-Json
            $provider = @($models | Where-Object { $_.name -eq 'Codex via Proxy' })
            Assert ($provider.Count -eq 1) 'Duplicate provider'
            Assert (@($provider[0].models | Where-Object { $_.id -eq 'gpt-6-astra' }).Count -eq 1) 'Duplicate Astra'
            $settings = Get-Content (Join-Path $userDir 'settings.json') -Raw | ConvertFrom-Json
            Assert ($settings.'chat.requestQueuing.defaultAction' -eq 'steer') 'Steering not configured'
            Assert ($settings.'github.copilot.chat.summarizeAgentConversationHistory.enabled' -eq $true) 'Compaction not enabled'
            Assert (Test-Path (Join-Path $installDir 'Iniciar proxy.lnk')) 'Background launcher missing'
            if ($scenario -eq 'existing') {
                Assert ($models[0].name -eq 'Other') 'Unrelated provider changed'
                Assert ($provider[0].models[0].id -eq 'gpt-5.6-sol') 'Sol lost'
                Assert ($settings.'editor.fontSize' -eq 17 -and $settings.'chat.agent.maxRequests' -eq 50) 'Unrelated settings changed'
                Assert ($settings.'chat.byokUtilityModelDefault' -eq 'copilot') 'Explicit utility preference changed'
                Assert ($settings.'codexProxyTools.proxyUrl' -eq 'http://127.0.0.1:19999') 'Custom port lost'
                $mcp = Get-Content (Join-Path $userDir 'mcp.json') -Raw | ConvertFrom-Json
                Assert ($mcp.servers.other.command -eq 'preserve' -and -not $mcp.servers.'codex-images') 'MCP migration changed unrelated server'
            } else {
                Assert (-not (Test-Path (Join-Path $userDir 'mcp.json'))) 'Clean install created an MCP configuration'
            }
        }
    }
    Write-Host 'PASS: clean install, repeat install, existing settings, custom port, native MCP migration, singleton array, launcher.'
} finally {
    $env:PATH = $oldPath
    $resolved = [System.IO.Path]::GetFullPath($root)
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temp, [System.StringComparison]::OrdinalIgnoreCase) -or [System.IO.Path]::GetFileName($resolved) -notlike 'ccp-setup-test-*') { throw 'Unsafe cleanup target' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}

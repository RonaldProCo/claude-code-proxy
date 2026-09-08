param(
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\dist\vscode'),
    [string]$SourceCommit
)
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vsix = Join-Path $repo 'vscode-extension\dist\codex-proxy-tools.vsix'
if (-not (Test-Path -LiteralPath $vsix)) { throw 'Run npm ci and npm run package inside vscode-extension first.' }
if (-not $SourceCommit) { $SourceCommit = (& git -C $repo rev-parse HEAD).Trim(); if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' } }
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('ccp-vscode-package-' + [guid]::NewGuid().ToString('N'))
try {
    [System.IO.Directory]::CreateDirectory($stage) | Out-Null
    foreach ($file in @('install.ps1', 'configure-vscode.ps1', 'start-proxy.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $stage
    }
    foreach ($file in @('FORK_SETUP.md', 'VSCODE_GUIDE.md', 'VALIDATION.md', 'LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $stage
    }
    Copy-Item -LiteralPath $vsix -Destination $stage
    $manifest = [ordered]@{ repository = 'RonaldProCo/claude-code-proxy'; setupCommit = $SourceCommit; binaryTag = 'v0.1.36-astra.1'; binaryCommit = 'e47fa9a'; extensionVersion = '1.0.0'; imageIntegration = 'native VS Code language model tools; no MCP' }
    [System.IO.File]::WriteAllText((Join-Path $stage 'SOURCE.json'), (ConvertTo-Json -InputObject $manifest))
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath (Join-Path $OutputDir 'vscode-setup.zip') -Force
    Copy-Item -LiteralPath $vsix -Destination (Join-Path $OutputDir 'codex-proxy-tools.vsix') -Force
    foreach ($name in @('vscode-setup.zip', 'codex-proxy-tools.vsix')) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $OutputDir $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        [System.IO.File]::WriteAllText((Join-Path $OutputDir "$name.sha256"), "$hash  $name`n")
    }
    Write-Host "Packaged VS Code setup from $SourceCommit in $OutputDir"
} finally {
    $resolved = [System.IO.Path]::GetFullPath($stage)
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temp, [System.StringComparison]::OrdinalIgnoreCase) -or [System.IO.Path]::GetFileName($resolved) -notlike 'ccp-vscode-package-*') { throw 'Unsafe cleanup target' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}

param(
    [string]$Version = 'v0.1.36-astra.1',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\claude-code-proxy')
)

$ErrorActionPreference = 'Stop'
$repo = 'RonaldProCo/claude-code-proxy'
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$platform = switch ($architecture) {
    'X64' { 'windows-amd64' }
    'Arm64' { 'windows-arm64' }
    default { throw "Unsupported Windows architecture: $architecture" }
}
$archive = "claude-code-proxy-$platform.zip"
$checksum = "claude-code-proxy-$platform.sha256"
$download = "https://github.com/$repo/releases/download/$Version"
$staging = Join-Path ([System.IO.Path]::GetTempPath()) "ccp-install-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    Invoke-WebRequest "$download/$archive" -OutFile (Join-Path $staging $archive)
    Invoke-WebRequest "$download/$checksum" -OutFile (Join-Path $staging $checksum)
    $expected = ((Get-Content -LiteralPath (Join-Path $staging $checksum) -Raw).Trim() -split '\s+')[0]
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $staging $archive)).Hash
    if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or $actual -ne $expected) {
        throw 'SHA-256 verification failed; installation stopped.'
    }
    Expand-Archive -LiteralPath (Join-Path $staging $archive) -DestinationPath $staging
    $binary = Join-Path $staging 'claude-code-proxy.exe'
    $reported = & $binary --version
    if ($LASTEXITCODE -ne 0 -or $reported -ne "claude-code-proxy $($Version.TrimStart('v'))") {
        throw "Unexpected binary version: $reported"
    }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $InstallDir 'claude-code-proxy.exe') -Force
    Write-Host "Installed $reported to $InstallDir (SHA-256 verified)."
    Write-Host "Run: & '$InstallDir\claude-code-proxy.exe' serve"
    Write-Host 'See FORK_SETUP.md for ChatGPT authentication and VS Code configuration.'
} finally {
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $resolvedStaging = [System.IO.Path]::GetFullPath($staging)
    if ($resolvedStaging.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($resolvedStaging) -like 'ccp-install-*') {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}

#Requires -Version 7
# Build system-agent binaries for all supported platforms

$ErrorActionPreference = "Stop"

$BinaryName = "system-agent"
$RootDir    = Join-Path $PSScriptRoot ".."
$OutDir     = Join-Path $RootDir "dist"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Output: $OutDir"
Write-Host ""
Write-Host "=== Building Go binaries ==="

function Build-Target {
    param($OS, $Arch, $GoArm, $OutName)

    $env:GOOS        = $OS
    $env:GOARCH      = $Arch
    $env:CGO_ENABLED = "0"
    if ($GoArm) { $env:GOARM = $GoArm } else { Remove-Item Env:\GOARM -ErrorAction SilentlyContinue }

    $out     = Join-Path $OutDir $OutName
    $entrySrc = Join-Path $RootDir "cmd\agent"
    & go build -trimpath -ldflags="-s -w" -o $out $entrySrc
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $OutName" }
    Write-Host "  OK  $OutName"
}

Push-Location $RootDir
try {
    Build-Target linux   amd64 $null "${BinaryName}-linux-amd64"
    Build-Target linux   arm64 $null "${BinaryName}-linux-arm64"
    Build-Target linux   arm   "7"   "${BinaryName}-linux-armv7"
    Build-Target windows amd64 $null "${BinaryName}.exe"
} finally {
    Pop-Location
    Remove-Item Env:\GOOS, Env:\GOARCH, Env:\CGO_ENABLED -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Artifacts in dist/:"
Get-ChildItem $OutDir | Select-Object Name, @{N="Size";E={"{0:N0} KB" -f ($_.Length / 1KB)}}

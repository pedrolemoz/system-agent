$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'SystemAgent must be uninstalled from an elevated PowerShell session.'
}

schtasks.exe /End /TN SystemAgent 2>$null | Out-Null
$processes = Get-Process -Name 'systemagent' -ErrorAction SilentlyContinue
if ($processes) {
    $processes | Stop-Process -Force
    $processes | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
}
schtasks.exe /Delete /TN SystemAgent /F 2>$null | Out-Null

Get-NetFirewallRule -DisplayName 'SystemAgent TCP 8732' -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

$installDir = Join-Path $env:ProgramFiles 'SystemAgent'
if (Test-Path -LiteralPath $installDir) {
    Remove-Item -LiteralPath $installDir -Recurse -Force
}

Write-Host 'SystemAgent has been completely removed.'

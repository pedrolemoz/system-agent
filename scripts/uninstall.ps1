#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$installDir = "C:\Program Files\SystemAgent"
$svcName    = "SystemAgent"

Write-Host "Uninstalling SystemAgent..."

if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping service..."
    Stop-Service -Name $svcName -Force
    sc.exe delete $svcName | Out-Null
}

if (Test-Path $installDir) {
    Write-Host "Removing files..."
    Remove-Item -Recurse -Force $installDir
}

Write-Host "Done. SystemAgent removed."

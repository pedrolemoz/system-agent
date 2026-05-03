#Requires -RunAsAdministrator
$ErrorActionPreference = "Continue"

$installDir = "C:\Program Files\SystemAgent"
$taskName   = "SystemAgent"

Write-Host "Uninstalling SystemAgent..." -ForegroundColor Cyan

Write-Host "Stopping and removing scheduled task..." -ForegroundColor Cyan
schtasks /end    /tn $taskName 2>$null
schtasks /delete /tn $taskName /f 2>$null

if (Test-Path $installDir) {
    Write-Host "Removing $installDir..." -ForegroundColor Cyan
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Done. SystemAgent removed." -ForegroundColor Green

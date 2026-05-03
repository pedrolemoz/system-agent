#Requires -RunAsAdministrator
$ErrorActionPreference = "Continue"

$installDir = "C:\SystemAgent"
$taskName   = "SystemAgent"

Write-Host "Uninstalling SystemAgent..." -ForegroundColor Cyan

Write-Host "Removing firewall rule..." -ForegroundColor Cyan
Remove-NetFirewallRule -DisplayName "SystemAgent" -ErrorAction SilentlyContinue

Write-Host "Stopping and removing scheduled task..." -ForegroundColor Cyan
Stop-ScheduledTask       -TaskName $taskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

if (Test-Path $installDir) {
    Write-Host "Removing $installDir..." -ForegroundColor Cyan
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Done. SystemAgent removed." -ForegroundColor Green

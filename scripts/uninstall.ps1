#Requires -RunAsAdministrator
$ErrorActionPreference = "Continue"

$installDir = "C:\Program Files\SystemAgent"
$svcName    = "SystemAgent"

Write-Host "Uninstalling SystemAgent..." -ForegroundColor Cyan

if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping and removing service..." -ForegroundColor Cyan
    Stop-Service -Name $svcName -Force
    sc.exe delete $svcName | Out-Null
    Start-Sleep -Seconds 2
}

if (Test-Path $installDir) {
    Write-Host "Removing $installDir..." -ForegroundColor Cyan
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Done. SystemAgent removed." -ForegroundColor Green

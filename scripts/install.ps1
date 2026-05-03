#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

Write-Host "Checking dependencies..." -ForegroundColor Cyan
$missing = @()
if (!(Get-Command "git" -ErrorAction SilentlyContinue)) { $missing += "git" }
if (!(Get-Command "go"  -ErrorAction SilentlyContinue)) { $missing += "golang" }

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing required dependencies: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Please install them and ensure they are in your system PATH before running this script." -ForegroundColor Yellow
    Write-Host "This script will not download them automatically." -ForegroundColor Yellow
    Exit 1
}

$installDir = "C:\SystemAgent"
$taskName   = "SystemAgent"
$exePath    = "$installDir\system-agent.exe"

if (Test-Path $installDir) {
    Write-Host "Removing existing installation at $installDir..." -ForegroundColor Yellow
    Stop-ScheduledTask       -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Cloning project to $installDir..." -ForegroundColor Cyan
git clone https://github.com/pedrolemoz/system-agent.git $installDir
if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

Write-Host "Building..." -ForegroundColor Cyan
Push-Location $installDir
try {
    go mod tidy
    if ($LASTEXITCODE -ne 0) { throw "go mod tidy failed" }
    go build -trimpath -ldflags="-s -w" -o system-agent.exe .\cmd\agent
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }
} finally {
    Pop-Location
}

Write-Host "Creating scheduled task..." -ForegroundColor Cyan
$action    = New-ScheduledTaskAction -Execute $exePath -WorkingDirectory $installDir
$trigger   = New-ScheduledTaskTrigger -AtStartup
$settings  = New-ScheduledTaskSettingsSet `
                -ExecutionTimeLimit 0 `
                -RestartCount 3 `
                -RestartInterval (New-TimeSpan -Minutes 1) `
                -StartWhenAvailable `
                -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Adding firewall rule..." -ForegroundColor Cyan
New-NetFirewallRule -DisplayName "SystemAgent" -Direction Inbound -Protocol TCP -LocalPort 8732 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host "Starting task now..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $taskName

Start-Sleep -Seconds 3
$state = (Get-ScheduledTask -TaskName $taskName).State
Write-Host "Task state: $state" -ForegroundColor Cyan

Write-Host ""
Write-Host "Installation complete! system-agent will run automatically on startup." -ForegroundColor Green
Write-Host "Available at: http://localhost:8732" -ForegroundColor Green

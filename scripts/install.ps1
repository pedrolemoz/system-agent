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

$installDir = "C:\Program Files\SystemAgent"
$taskName   = "SystemAgent"
$exePath    = "$installDir\system-agent.exe"

if (Test-Path $installDir) {
    Write-Host "Removing existing installation at $installDir..." -ForegroundColor Yellow
    schtasks /end    /tn $taskName 2>$null
    schtasks /delete /tn $taskName /f 2>$null
    Start-Sleep -Seconds 2
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Cloning project to $installDir..." -ForegroundColor Cyan
git clone https://github.com/pedrolemoz/system-agent.git $installDir

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
$cmd = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"cd '$installDir'; & '$exePath'`""
schtasks /create /tn $taskName /tr $cmd /sc onstart /ru SYSTEM /f
if ($LASTEXITCODE -ne 0) { throw "schtasks create failed" }

Write-Host "Starting task..." -ForegroundColor Cyan
schtasks /run /tn $taskName
if ($LASTEXITCODE -ne 0) { throw "schtasks run failed" }

Write-Host ""
Write-Host "Installation complete! system-agent will run automatically on startup." -ForegroundColor Green
Write-Host "Available at: http://localhost:8732" -ForegroundColor Green

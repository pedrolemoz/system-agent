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
$svcName    = "SystemAgent"
$exePath    = "$installDir\system-agent.exe"

if (Test-Path $installDir) {
    Write-Host "Removing existing installation at $installDir..." -ForegroundColor Yellow
    if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svcName -Force
        sc.exe delete $svcName | Out-Null
        Start-Sleep -Seconds 2
    }
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

Write-Host "Registering service..." -ForegroundColor Cyan
New-Service -Name $svcName `
            -BinaryPathName "`"$exePath`"" `
            -DisplayName "System Agent" `
            -Description "System metrics and control HTTP service" `
            -StartupType Automatic

Write-Host "Starting service..." -ForegroundColor Cyan
Start-Service -Name $svcName

Write-Host ""
Write-Host "Installation complete! system-agent will run automatically on startup." -ForegroundColor Green
Write-Host "Available at: http://localhost:8732" -ForegroundColor Green

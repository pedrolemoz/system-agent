#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$installDir = "C:\Program Files\SystemAgent"
$exeUrl     = "https://domain.com/releases/system-agent-windows-amd64.exe"
$exePath    = "$installDir\system-agent.exe"
$svcName    = "SystemAgent"

Write-Host "Installing SystemAgent..."

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

Write-Host "Downloading binary..."
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing

if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping existing service..."
    Stop-Service -Name $svcName -Force
    sc.exe delete $svcName | Out-Null
    Start-Sleep -Seconds 1
}

Write-Host "Registering service..."
New-Service -Name $svcName `
            -BinaryPathName "`"$exePath`"" `
            -DisplayName "System Agent" `
            -Description "System metrics and control HTTP service" `
            -StartupType Automatic

Write-Host "Starting service..."
Start-Service -Name $svcName

Write-Host "Done. SystemAgent running on http://127.0.0.1:8732"

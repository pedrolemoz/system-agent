$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'SystemAgent must be installed from an elevated PowerShell session.'
}

$installDir = Join-Path $env:ProgramFiles 'SystemAgent'
$binary = Join-Path $installDir 'systemagent.exe'
$temporary = Join-Path $env:TEMP 'systemagent.exe.download'

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri 'https://systemagent.pedrolemoz.dev/systemagent.exe' -OutFile $temporary

schtasks.exe /End /TN SystemAgent 2>$null | Out-Null
schtasks.exe /Delete /TN SystemAgent /F 2>$null | Out-Null
Move-Item -Force $temporary $binary

$escapedBinary = [Security.SecurityElement]::Escape($binary)
$taskDefinition = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><BootTrigger><Enabled>true</Enabled></BootTrigger></Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RestartOnFailure><Interval>PT1M</Interval><Count>999</Count></RestartOnFailure>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author"><Exec><Command>$escapedBinary</Command></Exec></Actions>
</Task>
"@
$taskFile = Join-Path $env:TEMP 'systemagent-task.xml'
try {
    $taskDefinition | Set-Content -Encoding Unicode -Path $taskFile
    schtasks.exe /Create /TN SystemAgent /XML $taskFile /F | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the SystemAgent startup task.' }
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $taskFile
}

if (-not (Get-NetFirewallRule -DisplayName 'SystemAgent TCP 8732' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'SystemAgent TCP 8732' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8732 -Profile Private | Out-Null
}

schtasks.exe /Run /TN SystemAgent | Out-Null
Write-Host 'SystemAgent installed and running on TCP port 8732.'

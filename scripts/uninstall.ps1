$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'SystemAgent must be uninstalled from an elevated PowerShell session.'
}

$firewallRuleNames = @('SystemAgent TCP 8732', 'SystemAgent UDP 8732')

function Remove-SystemAgentFirewallRule {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        foreach ($firewallRuleName in $firewallRuleNames) {
            netsh.exe advfirewall firewall delete rule name="$firewallRuleName" | Out-Null
        }
    } finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }
}

$existingTask = Get-ScheduledTask -TaskName SystemAgent -ErrorAction SilentlyContinue
if ($existingTask) {
    Stop-ScheduledTask -TaskName SystemAgent -ErrorAction SilentlyContinue
}
$processes = Get-Process -Name 'systemagent' -ErrorAction SilentlyContinue
if ($processes) {
    $processes | Stop-Process -Force
    $processes | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
}
if ($existingTask) {
    Unregister-ScheduledTask -TaskName SystemAgent -Confirm:$false
}

Remove-SystemAgentFirewallRule

$installDir = Join-Path $env:ProgramFiles 'SystemAgent'
if (Test-Path -LiteralPath $installDir) {
    Remove-Item -LiteralPath $installDir -Recurse -Force
}

Write-Host 'SystemAgent has been completely removed.'

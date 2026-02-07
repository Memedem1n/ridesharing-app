param(
  [int]$Tail = 60
)

$contextPath = Join-Path $PSScriptRoot '..\docs\AGENT_CONTEXT.md'
$logPath = Join-Path $PSScriptRoot '..\docs\AGENT_LOG.md'

Write-Output "=== AGENT CONTEXT ==="
Get-Content -Path $contextPath
Write-Output ""
Write-Output "=== AGENT LOG (tail) ==="
if (Test-Path $logPath) {
  Get-Content -Path $logPath -Tail $Tail
} else {
  Write-Output "No log file found at $logPath"
}
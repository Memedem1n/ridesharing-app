param(
  [ValidateSet('agent','sub-agent')]
  [string]$Level = 'agent',
  [Parameter(Mandatory=$true)][string]$Agent,
  [Parameter(Mandatory=$true)][string]$Task,
  [Parameter(Mandatory=$true)][string]$Summary,
  [string]$Commands = '-',
  [string]$Files = '-',
  [string]$Notes = ''
)

$logPath = Join-Path $PSScriptRoot '..\docs\AGENT_LOG.md'
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

$entry = @()
$entry += ""
$entry += "## $timestamp"
$entry += "Level: $Level"
$entry += "Agent: $Agent"
$entry += "Task: $Task"
$entry += "Summary: $Summary"
$entry += "Commands: $Commands"
$entry += "Files: $Files"
if ($Notes -and $Notes.Trim().Length -gt 0) { $entry += "Notes: $Notes" }

Add-Content -Path $logPath -Value ($entry -join "`r`n")

Write-Output "Logged to $logPath"
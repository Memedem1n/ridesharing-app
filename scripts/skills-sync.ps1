param(
  [ValidateSet('all','recommended')]
  [string]$Set = 'all',
  [switch]$DryRun = $false
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$destRoot = Join-Path $repoRoot '.codex\skills'
$sourceRoot = Join-Path $env:USERPROFILE '.codex\skills'

$recommended = @(
  'doc',
  'playwright',
  'security-best-practices',
  'security-ownership-map',
  'security-threat-model',
  'sentry',
  'screenshot',
  'pdf',
  'spreadsheet',
  'gh-address-comments',
  'gh-fix-ci',
  'figma',
  'figma-implement-design',
  'openai-docs',
  'jupyter-notebook',
  'linear',
  'notion-research-documentation',
  'notion-spec-to-implementation',
  'render-deploy',
  'vercel-deploy',
  'netlify-deploy',
  'cloudflare-deploy'
)

if ($Set -eq 'all') {
  $names = Get-ChildItem -Path $sourceRoot -Directory |
    Where-Object { $_.Name -ne '.system' } |
    Select-Object -ExpandProperty Name
} else {
  $names = $recommended
}

if (-not (Test-Path $destRoot)) { New-Item -ItemType Directory -Path $destRoot | Out-Null }

$copied = @()
$skipped = @()
$missing = @()

foreach ($name in $names) {
  $src = Join-Path $sourceRoot $name
  $dest = Join-Path $destRoot $name
  if (-not (Test-Path $src)) {
    $missing += $name
    continue
  }
  if (Test-Path $dest) {
    $skipped += $name
    continue
  }
  if (-not $DryRun) {
    Copy-Item -Recurse -Force $src $dest
  }
  $copied += $name
}

Write-Output ("Set: " + $Set)
Write-Output ("Copied: " + ($copied -join ', '))
Write-Output ("Skipped: " + ($skipped -join ', '))
Write-Output ("Missing: " + ($missing -join ', '))

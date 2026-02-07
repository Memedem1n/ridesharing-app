param(
  [switch]$InstallSkills = $true,
  [switch]$SyncSkills = $true,
  [switch]$CheckWeave = $false,
  [switch]$Log = $false,
  [string]$Agent = 'codex'
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$codexHome = Join-Path $env:USERPROFILE '.codex'
$skillsDir = Join-Path $codexHome 'skills'
$listScript = Join-Path $skillsDir '.system\skill-installer\scripts\list-skills.py'
$installer = Join-Path $skillsDir '.system\skill-installer\scripts\install-skill-from-github.py'

$staticSkills = @(
  'cloudflare-deploy',
  'develop-web-game',
  'doc',
  'figma',
  'figma-implement-design',
  'gh-address-comments',
  'gh-fix-ci',
  'imagegen',
  'jupyter-notebook',
  'linear',
  'netlify-deploy',
  'notion-knowledge-capture',
  'notion-meeting-intelligence',
  'notion-research-documentation',
  'notion-spec-to-implementation',
  'openai-docs',
  'pdf',
  'playwright',
  'render-deploy',
  'screenshot',
  'security-best-practices',
  'security-ownership-map',
  'security-threat-model',
  'sentry',
  'sora',
  'speech',
  'spreadsheet',
  'transcribe',
  'vercel-deploy',
  'yeet'
)

$installed = @()
$skipped = @()
$failed = @()

if ($InstallSkills) {
  if (-not (Test-Path $installer)) {
    Write-Output "Skill installer not found: $installer"
    Write-Output "Run from a machine with Codex system skills installed."
  } else {
    $names = @()
    if (Test-Path $listScript) {
      try {
        $json = & python $listScript --format json 2>&1
        if ($LASTEXITCODE -eq 0 -and $json) {
          $parsed = $json | ConvertFrom-Json
          $names = $parsed | ForEach-Object { $_.name }
        }
      } catch {
        $names = @()
      }
    }
    if (-not $names -or $names.Count -eq 0) {
      $names = $staticSkills
    }

    foreach ($name in $names) {
      $dest = Join-Path $skillsDir $name
      if (Test-Path $dest) {
        $skipped += $name
        continue
      }
      $path = "skills/.curated/$name"
      $output = & python $installer --repo openai/skills --path $path 2>&1
      if ($LASTEXITCODE -eq 0) {
        $installed += $name
      } else {
        $failed += $name
        Write-Output $output
      }
    }
  }
}

if ($CheckWeave) {
  $weaveCmd = Get-Command weave -ErrorAction SilentlyContinue
  if ($weaveCmd) {
    Write-Output "Weave CLI detected: $($weaveCmd.Source)"
  } elseif ($IsMacOS) {
    Write-Output "Weave CLI not installed. Install on macOS:"
    Write-Output "  npm install -g @rosem_soo/weave"
    Write-Output "  weave-service start"
    Write-Output "  weave --help"
  } else {
    Write-Output "Weave CLI is macOS-only (darwin). Use a macOS host for install/run."
  }
}

if ($InstallSkills) {
  if ($installed.Count -gt 0) { Write-Output ("Installed skills: " + ($installed -join ', ')) }
  if ($skipped.Count -gt 0) { Write-Output ("Already installed: " + ($skipped -join ', ')) }
  if ($failed.Count -gt 0) { Write-Output ("Failed: " + ($failed -join ', ')) }
}

if ($SyncSkills) {
  $syncScript = Join-Path $PSScriptRoot 'skills-sync.ps1'
  if (Test-Path $syncScript) {
    & $syncScript -Set all | Out-Null
  }
}

if ($Log) {
  $logScript = Join-Path $PSScriptRoot 'agent-log.ps1'
  if (Test-Path $logScript) {
    $summary = "Agent setup run. Installed: $($installed -join ', '); Skipped: $($skipped -join ', '); Failed: $($failed -join ', ')"
    & $logScript -Level agent -Agent $Agent -Task 'Agent setup' -Summary $summary -Commands 'agent-setup.ps1' -Files 'scripts/agent-setup.ps1' | Out-Null
  }
}

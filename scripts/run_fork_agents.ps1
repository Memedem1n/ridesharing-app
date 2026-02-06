param(
  [switch]$Windowed,
  [switch]$NoNewWindow,
  [int]$LaunchDelayMs = 250,
  [string]$SessionId,
  [int]$MaxParallel = 1
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$forksPath = Join-Path $root 'docs\TASK_FORKS.md'
$promptDir = Join-Path $root '.agent\fork-prompts'

if (-not (Test-Path $forksPath)) {
  throw "TASK_FORKS.md not found at $forksPath"
}

New-Item -ItemType Directory -Force -Path $promptDir | Out-Null

# Clean previously generated prompt launchers to avoid stale scripts.
Get-ChildItem -Path $promptDir -Filter '*.ps1' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $promptDir -Filter '*.txt' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# Clear previously generated prompts/scripts to avoid stale content.
Get-ChildItem -Path $promptDir -File -Filter 'T-*.ps1' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $promptDir -File -Filter 'T-*.txt' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$content = Get-Content -Raw $forksPath
$regex = [regex]'(?ms)^###\s+(T-\d+)\s*(?:\r?\n)```(?:\r?\n)?(.*?)```'
$matches = $regex.Matches($content)

if ($matches.Count -eq 0) {
  throw "No prompt blocks found in TASK_FORKS.md"
}

if ($Windowed) {
  # Resolve session id for codex fork (required to pass a prompt)
  if (-not $SessionId -or $SessionId.Trim().Length -eq 0) {
    $sessionsRoot = Join-Path $env:USERPROFILE '.codex\sessions'
    if (Test-Path $sessionsRoot) {
      $latest = Get-ChildItem -Recurse -File -Filter 'rollout-*.jsonl' $sessionsRoot |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($latest) {
        $firstLine = Get-Content -TotalCount 1 $latest.FullName
        try {
          $meta = $firstLine | ConvertFrom-Json
          if ($meta.payload.id) {
            $SessionId = $meta.payload.id
          }
        } catch {
          # ignore, will error below if still empty
        }
      }
    }
  }

  if (-not $SessionId -or $SessionId.Trim().Length -eq 0) {
    throw "SessionId not found. Provide -SessionId <uuid> or ensure ~/.codex/sessions has a recent rollout file."
  }
}

foreach ($m in $matches) {
  $id = $m.Groups[1].Value
  $prompt = $m.Groups[2].Value.Trim()
  $promptFile = Join-Path $promptDir ("{0}.txt" -f $id)
  Set-Content -Path $promptFile -Value $prompt -NoNewline

  if ($Windowed) {
    # Create a per-task PowerShell launcher to avoid editor popups and ensure a console TTY.
    $taskScript = Join-Path $promptDir ("{0}.ps1" -f $id)
    $taskScriptContent = @'
$prompt = Get-Content -Raw "{PROMPT_FILE}"
$prompt = $prompt -replace "`r?`n", "\n"
codex fork "{SESSION_ID}" -C "{ROOT}" -s danger-full-access -a never --no-alt-screen "$prompt"
'@
    $taskScriptContent = $taskScriptContent.Replace('{PROMPT_FILE}', $promptFile).Replace('{ROOT}', $root).Replace('{SESSION_ID}', $SessionId)
    Set-Content -Path $taskScript -Value $taskScriptContent -NoNewline

    $psArgs = @('-NoExit', '-File', $taskScript)
    $startArgs = @{
      FilePath = 'powershell'
      ArgumentList = $psArgs
    }

    if ($NoNewWindow) {
      $startArgs['NoNewWindow'] = $true
    }

    Start-Process @startArgs | Out-Null
  } else {
    # Headless mode: run codex exec in background and log output per task.
    $logDir = Join-Path $promptDir '..\fork-logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null

    $outJson = Join-Path $logDir ("{0}.jsonl" -f $id)
    $outErr = Join-Path $logDir ("{0}.err.log" -f $id)
    $outLast = Join-Path $logDir ("{0}.last.txt" -f $id)

    # Resolve codex command (cmd shim) and run via PowerShell so we can pipe stdin from file.
    $codexCmd = (Get-Command codex.cmd -ErrorAction SilentlyContinue).Source
    if (-not $codexCmd) { $codexCmd = 'codex.cmd' }

    # Escape single quotes for PowerShell single-quoted strings.
    $pf = $promptFile.Replace("'", "''")
    $rt = $root.Replace("'", "''")
    $cl = $codexCmd.Replace("'", "''")
    $ol = $outLast.Replace("'", "''")

    $cmd = "Get-Content -Raw '$pf' | & '$cl' exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -C '$rt' --json --output-last-message '$ol' -"

    if ($MaxParallel -lt 1) { $MaxParallel = 1 }

    # Throttle concurrent execs to avoid API rate limits.
    if (-not $script:procs) { $script:procs = @() }
    while ($script:procs.Count -ge $MaxParallel) {
      $p = $script:procs[0]
      try { Wait-Process -Id $p.Id } catch {}
      $script:procs = @($script:procs | Where-Object { -not $_.HasExited })
    }

    $startArgs = @{
      FilePath = 'powershell'
      ArgumentList = @('-NoProfile', '-Command', $cmd)
      RedirectStandardOutput = $outJson
      RedirectStandardError = $outErr
      NoNewWindow = $true
    }

    $proc = Start-Process @startArgs -PassThru
    $script:procs += $proc
  }
  Start-Sleep -Milliseconds $LaunchDelayMs
}

Write-Host ("Launched {0} forked agents from {1}" -f $matches.Count, $forksPath)

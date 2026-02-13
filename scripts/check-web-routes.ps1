param(
  [string]$BaseUrl = 'http://localhost:3000'
)

$root = Split-Path -Parent $PSScriptRoot
Set-Location "$root\backend"

$env:WEB_BASE_URL = $BaseUrl
node .\scripts\check-web-routes.mjs
$code = $LASTEXITCODE

if ($code -ne 0) {
  Write-Error "Web route check failed for $BaseUrl"
  exit $code
}

Write-Host "Web route check passed for $BaseUrl"

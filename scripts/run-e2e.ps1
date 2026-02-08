param(
    [string]$DatabaseUrl = $env:TEST_DATABASE_URL
)

if (-not $DatabaseUrl) {
    $DatabaseUrl = $env:DATABASE_URL
}

if (-not $DatabaseUrl) {
    Write-Host "DATABASE_URL or TEST_DATABASE_URL is required."
    exit 1
}

if ($DatabaseUrl -notmatch 'ridesharing_test') {
    Write-Host "Safety check: DATABASE_URL must target ridesharing_test database."
    exit 1
}

function Ensure-TestDatabase {
    param([string]$Url)

    $psql = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psql) {
        Write-Host "psql not found. Ensure the test DB exists before running."
        return
    }

    $dbName = ($Url -split '/')[(-1)]
    $adminUrl = $Url -replace "/$dbName$", "/postgres"

    $exists = & psql $adminUrl -tAc "SELECT 1 FROM pg_database WHERE datname='$dbName'" 2>$null
    if (-not $exists) {
        Write-Host "Creating database $dbName ..."
        & psql $adminUrl -c "CREATE DATABASE $dbName" | Out-Null
    }
}

Ensure-TestDatabase -Url $DatabaseUrl

Push-Location (Join-Path (Join-Path $PSScriptRoot '..') 'backend')
$env:DATABASE_URL = $DatabaseUrl

npm run db:generate
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: prisma generate failed, continuing with existing client."
}

npx prisma db push --skip-generate
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    exit $LASTEXITCODE
}

npm run test:e2e -- --runInBand
$exitCode = $LASTEXITCODE

Pop-Location
exit $exitCode

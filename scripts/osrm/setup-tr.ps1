param(
    [string]$ProjectRoot = "",
    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

$dataDir = Join-Path $ProjectRoot "backend\\.data\\osrm"
$pbfFile = Join-Path $dataDir "turkey-latest.osm.pbf"
$downloadUrl = "https://download.geofabrik.de/europe/turkey-latest.osm.pbf"

Write-Host "Project root: $ProjectRoot"
Write-Host "OSRM data dir: $dataDir"

if (!(Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
}

if ($ForceDownload -or !(Test-Path $pbfFile)) {
    Write-Host "Downloading turkey dataset from Geofabrik..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $pbfFile
} else {
    Write-Host "Using existing dataset: $pbfFile"
}

$dockerImage = "ghcr.io/project-osrm/osrm-backend:latest"
$volumeArg = "$dataDir`:/data"

function Invoke-DockerChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Step,
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    & docker @Args
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed during '$Step' (exit code: $LASTEXITCODE)."
    }
}

Write-Host "Running osrm-extract..."
Invoke-DockerChecked -Step "osrm-extract" -Args @(
    "run", "--rm", "-t", "-v", $volumeArg, $dockerImage,
    "osrm-extract", "-p", "/opt/car.lua", "/data/turkey-latest.osm.pbf"
)

Write-Host "Running osrm-partition..."
Invoke-DockerChecked -Step "osrm-partition" -Args @(
    "run", "--rm", "-t", "-v", $volumeArg, $dockerImage,
    "osrm-partition", "/data/turkey-latest.osrm"
)

Write-Host "Running osrm-customize..."
Invoke-DockerChecked -Step "osrm-customize" -Args @(
    "run", "--rm", "-t", "-v", $volumeArg, $dockerImage,
    "osrm-customize", "/data/turkey-latest.osrm"
)

Write-Host ""
Write-Host "Done. Start OSRM service with:"
Write-Host "docker compose up -d osrm"

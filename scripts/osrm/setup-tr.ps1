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

Write-Host "Running osrm-extract..."
docker run --rm -t -v $volumeArg $dockerImage osrm-extract -p /opt/car.lua /data/turkey-latest.osm.pbf

Write-Host "Running osrm-partition..."
docker run --rm -t -v $volumeArg $dockerImage osrm-partition /data/turkey-latest.osrm

Write-Host "Running osrm-customize..."
docker run --rm -t -v $volumeArg $dockerImage osrm-customize /data/turkey-latest.osrm

Write-Host ""
Write-Host "Done. Start OSRM service with:"
Write-Host "docker compose up -d osrm"


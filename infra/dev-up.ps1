param(
    [switch]$Build,
    [switch]$Logs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$composeArgs = @("compose", "-f", "infra/docker-compose.dev.yml", "up", "-d")
if ($Build) {
    $composeArgs += "--build"
}

docker @composeArgs | Out-Host

if ($Logs) {
    docker compose -f infra/docker-compose.dev.yml logs -f frontend-dev backend-dev
}

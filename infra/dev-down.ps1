$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

docker compose -f infra/docker-compose.dev.yml down | Out-Host

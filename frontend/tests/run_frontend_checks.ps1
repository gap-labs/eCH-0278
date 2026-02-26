param(
    [string]$BackendImageTag = "ech-0278-backend:test",
    [string]$FrontendImageTag = "ech-0278-frontend:test",
    [string]$BackendContainerName = "ech0278-frontend-check-backend",
    [string]$FrontendContainerName = "ech0278-frontend-check-frontend",
    [string]$NetworkName = "ech0278-frontend-check-net",
    [int]$FrontendPort = 18082,
    [switch]$KeepContainers
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$FrontendRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $FrontendRoot
$BackendRoot = Join-Path $RepoRoot "backend"

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Write-Host "Building backend image: $BackendImageTag"
docker build -f (Join-Path $BackendRoot "Dockerfile") -t $BackendImageTag $BackendRoot | Out-Host

Write-Host "Building frontend image: $FrontendImageTag"
docker build -f (Join-Path $FrontendRoot "Dockerfile") -t $FrontendImageTag $FrontendRoot | Out-Host

if ((docker network ls --format "{{.Name}}") -notcontains $NetworkName) {
    docker network create $NetworkName | Out-Null
}

if ((docker ps -a --format "{{.Names}}") -contains $BackendContainerName) {
    docker rm -f $BackendContainerName | Out-Null
}

if ((docker ps -a --format "{{.Names}}") -contains $FrontendContainerName) {
    docker rm -f $FrontendContainerName | Out-Null
}

Write-Host "Starting backend container"
docker run --name $BackendContainerName --network $NetworkName --network-alias backend -d $BackendImageTag | Out-Null

Write-Host "Starting frontend container"
docker run --name $FrontendContainerName --network $NetworkName -d -p "$FrontendPort`:80" $FrontendImageTag | Out-Null

try {
    $frontendReady = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $index = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$FrontendPort/" -TimeoutSec 2
            if ($index.StatusCode -eq 200) {
                $frontendReady = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 400
        }
    }

    Assert-Condition -Condition $frontendReady -Message "Frontend did not become ready on port $FrontendPort."

    $schemaSummary = $null
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $schemaSummary = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$FrontendPort/api/schema/summary" -TimeoutSec 5
            if ($schemaSummary.StatusCode -eq 200) {
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 400
        }
    }

    Assert-Condition -Condition ($null -ne $schemaSummary -and $schemaSummary.StatusCode -eq 200) -Message "Proxy call /api/schema/summary did not return 200."

    $summaryJson = $schemaSummary.Content | ConvertFrom-Json
    Assert-Condition -Condition ($summaryJson.targetNamespace -eq "http://www.ech.ch/xmlns/eCH-0278/1") -Message "Frontend proxy returned unexpected schema summary payload."

    Write-Host ""
    Write-Host "Frontend Docker checks passed." -ForegroundColor Green
}
finally {
    if (-not $KeepContainers) {
        if ((docker ps -a --format "{{.Names}}") -contains $FrontendContainerName) {
            docker rm -f $FrontendContainerName | Out-Null
        }
        if ((docker ps -a --format "{{.Names}}") -contains $BackendContainerName) {
            docker rm -f $BackendContainerName | Out-Null
        }
        if ((docker network ls --format "{{.Name}}") -contains $NetworkName) {
            docker network rm $NetworkName | Out-Null
        }
    }
}

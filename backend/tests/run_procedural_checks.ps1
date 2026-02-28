param(
    [string]$ImageTag = "ech-0278-backend:procedural-tests",
    [string]$ContainerName = "ech0278-procedural-tests",
    [int]$Port = 18082,
    [switch]$KeepContainer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$TestsRoot = $PSScriptRoot
$BackendRoot = Split-Path -Parent $TestsRoot
$FixturesDir = Join-Path $TestsRoot "fixtures"

function Invoke-Validate {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$FixturePath
    )

    $raw = curl.exe -sS -X POST $Url -F "file=@$FixturePath"
    if (-not $raw) {
        throw "No response from $Url"
    }
    return ($raw | ConvertFrom-Json)
}

Write-Host "Building backend image: $ImageTag"
docker build -f (Join-Path $BackendRoot "Dockerfile") -t $ImageTag $BackendRoot | Out-Host

if ((docker ps -a --format "{{.Names}}") -contains $ContainerName) {
    docker rm -f $ContainerName | Out-Null
}

Write-Host "Starting container: $ContainerName on port $Port"
docker run --name $ContainerName -d -p "$Port`:8000" $ImageTag | Out-Null

try {
    $ready = $false
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$Port/docs" -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $ready) {
        throw "Backend did not become ready on port $Port."
    }

    $validTaxationFixture = Join-Path $FixturesDir "golden_valid.taxation.xml"
    $invalidFixture = Join-Path $FixturesDir "incomplete_minimal.xml"

    if (-not (Test-Path $validTaxationFixture)) {
        throw "Missing fixture: $validTaxationFixture"
    }
    if (-not (Test-Path $invalidFixture)) {
        throw "Missing fixture: $invalidFixture"
    }

    $base = "http://localhost:$Port/api/validate"

    Write-Host "Test 1: procedural=false -> proceduralFindings must be []"
    $test1 = Invoke-Validate -Url $base -FixturePath $validTaxationFixture
    if ($null -eq $test1.proceduralFindings -or $test1.proceduralFindings.Count -ne 0) {
        throw "Expected proceduralFindings to be empty for procedural=false."
    }

    Write-Host "Test 2: procedural=true with xsdValid=false -> proceduralFindings must be []"
    $test2 = Invoke-Validate -Url "${base}?procedural=true" -FixturePath $invalidFixture
    if ($test2.xsdValid) {
        throw "Expected xsdValid=false for invalid fixture."
    }
    if ($null -eq $test2.proceduralFindings -or $test2.proceduralFindings.Count -ne 0) {
        throw "Expected proceduralFindings to be empty when xsdValid=false."
    }

    Write-Host "Test 3: procedural=true with xsdValid=true and rule-hit -> at least one finding"
    $test3 = Invoke-Validate -Url "${base}?procedural=true" -FixturePath $validTaxationFixture
    if (-not $test3.xsdValid) {
        throw "Expected xsdValid=true for golden_valid.taxation fixture."
    }
    if ($null -eq $test3.proceduralFindings -or $test3.proceduralFindings.Count -lt 1) {
        throw "Expected at least one procedural finding for valid taxation fixture."
    }

    $codes = @($test3.proceduralFindings | ForEach-Object { $_.code })
    if (-not ($codes -contains "time_taxation_marker_present")) {
        throw "Expected finding code 'time_taxation_marker_present' not found."
    }

    Write-Host ""
    Write-Host "All procedural API checks passed." -ForegroundColor Green
}
finally {
    if (-not $KeepContainer) {
        docker rm -f $ContainerName | Out-Null
    }
}

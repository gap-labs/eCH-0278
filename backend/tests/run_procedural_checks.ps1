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

function Wait-BackendReady {
    param(
        [Parameter(Mandatory = $true)][string]$ContainerName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$MaxAttempts = 120,
        [int]$SleepMilliseconds = 500
    )

    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$Port/docs" -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                return
            }
        }
        catch {
        }

        Start-Sleep -Milliseconds $SleepMilliseconds
    }

    $containerState = docker ps -a --filter "name=$ContainerName" --format "{{.Status}}"
    $logTail = "(not available)"
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $logTail = ((docker logs --tail 30 $ContainerName 2>&1) | Out-String).Trim()
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    throw "Backend did not become ready on port $Port. Container status: $containerState`nRecent logs:`n$logTail"
}

Write-Host "Building backend image: $ImageTag"
docker build -f (Join-Path $BackendRoot "Dockerfile") -t $ImageTag --build-arg SCHEMATRON_INCLUDE_GLOB=tests/rules/procedural_smoke.sch $BackendRoot | Out-Host

if ((docker ps -a --format "{{.Names}}") -contains $ContainerName) {
    docker rm -f $ContainerName | Out-Null
}

Write-Host "Starting container: $ContainerName on port $Port"
docker run --name $ContainerName -d -p "$Port`:8000" $ImageTag | Out-Null

try {
    Wait-BackendReady -ContainerName $ContainerName -Port $Port

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

    docker rm -f $ContainerName | Out-Null

    $badContainerName = "$ContainerName-bad"
    if ((docker ps -a --format "{{.Names}}") -contains $badContainerName) {
        docker rm -f $badContainerName | Out-Null
    }

    Write-Host "Test 4: procedural validator init failure -> graceful procedural error finding"
    docker run --name $badContainerName -d -p "$Port`:8000" --entrypoint sh $ImageTag -lc "echo not-a-stylesheet > /app/app/generated/schematron/tests/rules/procedural_smoke.xsl; /opt/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000" | Out-Null

    Wait-BackendReady -ContainerName $badContainerName -Port $Port

    $test4 = Invoke-Validate -Url "${base}?procedural=true" -FixturePath $validTaxationFixture
    if (-not $test4.xsdValid) {
        throw "Expected xsdValid=true for valid fixture in init-failure scenario."
    }
    if ($null -eq $test4.proceduralFindings -or $test4.proceduralFindings.Count -lt 1) {
        throw "Expected at least one procedural finding in init-failure scenario."
    }
    $test4Codes = @($test4.proceduralFindings | ForEach-Object { $_.code })
    if (-not ($test4Codes -contains "procedural_validator_unavailable")) {
        throw "Expected 'procedural_validator_unavailable' finding code in init-failure scenario."
    }

    Write-Host ""
    Write-Host "All procedural API checks passed." -ForegroundColor Green
}
finally {
    $badContainerName = "$ContainerName-bad"
    if ((docker ps -a --format "{{.Names}}") -contains $badContainerName) {
        docker rm -f $badContainerName | Out-Null
    }

    if (-not $KeepContainer) {
        if ((docker ps -a --format "{{.Names}}") -contains $ContainerName) {
            docker rm -f $ContainerName | Out-Null
        }
    }
}

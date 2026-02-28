param(
    [string]$ImageTag = "ech-0278-backend:test",
    [string]$ContainerName = "ech0278-validation-tests",
    [int]$Port = 18080,
    [switch]$KeepContainer,
    [switch]$RequireGolden
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$TestsRoot = $PSScriptRoot
$BackendRoot = Split-Path -Parent $TestsRoot
$RepoRoot = Split-Path -Parent $BackendRoot
$FixturesDir = Join-Path $TestsRoot "fixtures"
$ExpectedDir = Join-Path $TestsRoot "expected"
$ResultsDir = Join-Path $TestsRoot "results"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

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

function Normalize-Json {
    param([Parameter(Mandatory = $true)][string]$Json)
    return ($Json | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress)
}

function Invoke-Validation {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][string]$FixturePath
    )

    $url = "http://localhost:$Port/api/validate"
    $raw = curl.exe -sS -X POST $url -F "file=@$FixturePath"

    if (-not $raw) {
        throw "No response received for fixture '$BaseName'."
    }

    $normalizedActual = Normalize-Json -Json $raw
    $actualPath = Join-Path $ResultsDir "$BaseName.actual.json"
    Set-Content -Path $actualPath -Value $normalizedActual -NoNewline -Encoding utf8

    $expectedPath = Join-Path $ExpectedDir "$BaseName.expected.json"
    if (-not (Test-Path $expectedPath)) {
        throw "Expected snapshot missing: $expectedPath"
    }

    $expectedRaw = Get-Content -Path $expectedPath -Raw
    $normalizedExpected = Normalize-Json -Json $expectedRaw

    return [PSCustomObject]@{
        Case = $BaseName
        Match = ($normalizedActual -eq $normalizedExpected)
        ActualPath = $actualPath
        ExpectedPath = $expectedPath
    }
}

Write-Host "Building backend image: $ImageTag"
docker build -f (Join-Path $BackendRoot "Dockerfile") -t $ImageTag $BackendRoot | Out-Host

if ((docker ps -a --format "{{.Names}}") -contains $ContainerName) {
    docker rm -f $ContainerName | Out-Null
}

Write-Host "Starting container: $ContainerName on port $Port"
docker run --name $ContainerName -d -p "$Port`:8000" $ImageTag | Out-Null

try {
    Wait-BackendReady -ContainerName $ContainerName -Port $Port

    $cases = @(
        "invalid_malformed",
        "incomplete_minimal",
        "incomplete_with_attributes"
    )

    $results = @()
    foreach ($case in $cases) {
        $fixturePath = Join-Path $FixturesDir "$case.xml"
        if (-not (Test-Path $fixturePath)) {
            throw "Fixture missing: $fixturePath"
        }
        $results += Invoke-Validation -BaseName $case -FixturePath $fixturePath
    }

    $optionalCases = @("mixed_sample")
    foreach ($case in $optionalCases) {
        $fixturePath = Join-Path $FixturesDir "$case.xml"
        if (Test-Path $fixturePath) {
            $results += Invoke-Validation -BaseName $case -FixturePath $fixturePath
        }
    }

    $goldenCandidates = @(
        @{ BaseName = "golden_valid.declaration"; Fixture = "golden_valid.declaration.xml" },
        @{ BaseName = "golden_valid.taxation"; Fixture = "golden_valid.taxation.xml" },
        @{ BaseName = "golden_valid"; Fixture = "golden_valid.xml" }
    )

    $goldenCases = @()
    foreach ($candidate in $goldenCandidates) {
        $candidatePath = Join-Path $FixturesDir $candidate.Fixture
        if (Test-Path $candidatePath) {
            $goldenCases += [PSCustomObject]@{
                BaseName = $candidate.BaseName
                FixturePath = $candidatePath
            }
        }
    }

    if ($goldenCases.Count -gt 0) {
        foreach ($goldenCase in $goldenCases) {
            $results += Invoke-Validation -BaseName $goldenCase.BaseName -FixturePath $goldenCase.FixturePath

            $goldenActualPath = Join-Path $ResultsDir ($goldenCase.BaseName + ".actual.json")
            $goldenActualRaw = Get-Content -Path $goldenActualPath -Raw
            $goldenActual = $goldenActualRaw | ConvertFrom-Json

            if (-not $goldenActual.xsdValid) {
                throw "Golden sample '$($goldenCase.BaseName)' is not XSD valid. See $goldenActualPath"
            }

            if ($goldenActual.errors -and $goldenActual.errors.Count -gt 0) {
                throw "Golden sample '$($goldenCase.BaseName)' returned validation errors. See $goldenActualPath"
            }
        }
    }
    elseif ($RequireGolden) {
        throw "Golden sample missing. Expected one of: $(Join-Path $FixturesDir 'golden_valid.declaration.xml'), $(Join-Path $FixturesDir 'golden_valid.xml')"
    }
    else {
        Write-Host ""
        Write-Host "Golden sample not present (optional): $(Join-Path $FixturesDir 'golden_valid.declaration.xml')" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Validation snapshot comparison"
    $results | Format-Table -AutoSize Case, Match, ActualPath

    $failed = @($results | Where-Object { -not $_.Match })
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host "Mismatches detected:" -ForegroundColor Red
        foreach ($item in $failed) {
            Write-Host "- $($item.Case): expected $($item.ExpectedPath), got $($item.ActualPath)" -ForegroundColor Red
        }
        exit 1
    }

    Write-Host ""
    Write-Host "All validation snapshots match expected output." -ForegroundColor Green
}
finally {
    if (-not $KeepContainer) {
        docker rm -f $ContainerName | Out-Null
    }
}

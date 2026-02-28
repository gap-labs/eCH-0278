param(
    [string]$ImageTag = "ech-0278-backend:schema-tests",
    [string]$ContainerName = "ech0278-schema-tests",
    [int]$Port = 18081,
    [switch]$KeepContainer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$TestsRoot = $PSScriptRoot
$BackendRoot = Split-Path -Parent $TestsRoot

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

function Invoke-ApiGet {
    param([Parameter(Mandatory = $true)][string]$Path)

    $url = "http://localhost:$Port$Path"
    $raw = curl.exe -sS $url
    if (-not $raw) {
        throw "No response received from '$url'."
    }
    return ($raw | ConvertFrom-Json)
}

function Find-NodeByName {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Node.name -eq $Name) {
        return $Node
    }

    if ($Node.children) {
        foreach ($child in $Node.children) {
            $found = Find-NodeByName -Node $child -Name $Name
            if ($null -ne $found) {
                return $found
            }
        }
    }

    return $null
}

function Find-AttributeSource {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$Source
    )

    if ($Node.attributes) {
        foreach ($attribute in $Node.attributes) {
            if ($attribute.source -eq $Source) {
                return $true
            }
        }
    }

    if ($Node.children) {
        foreach ($child in $Node.children) {
            if (Find-AttributeSource -Node $child -Source $Source) {
                return $true
            }
        }
    }

    return $false
}

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
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

    $summary = Invoke-ApiGet -Path "/api/schema/summary"

    Assert-Condition -Condition ($summary.targetNamespace -eq "http://www.ech.ch/xmlns/eCH-0278/1") -Message "Unexpected targetNamespace in schema summary."
    Assert-Condition -Condition ($summary.schemaLocation -eq "schema/eCH-0278-1-0.xsd") -Message "Unexpected schemaLocation in schema summary."
    Assert-Condition -Condition ($summary.rootElements -contains "naturalPersonTaxData") -Message "Root element naturalPersonTaxData missing in schema summary."
    Assert-Condition -Condition (($summary.topLevelTypes | Measure-Object).Count -gt 0) -Message "topLevelTypes should not be empty."

    $treeResponse = Invoke-ApiGet -Path "/api/schema/tree"
    $root = $treeResponse.root

    Assert-Condition -Condition ($root.name -eq "naturalPersonTaxData") -Message "Tree root must be naturalPersonTaxData."

    $expectedSections = @("header", "domesticAndForeignIncome", "deductions", "domesticAndForeignAssets", "taxationData")
    foreach ($section in $expectedSections) {
        $node = Find-NodeByName -Node $root -Name $section
        Assert-Condition -Condition ($null -ne $node) -Message "Expected section '$section' missing in schema tree."
    }

    $personalDetailNode = Find-NodeByName -Node $root -Name "personalDetail"
    Assert-Condition -Condition ($null -ne $personalDetailNode) -Message "Node personalDetail not found (cardinality check)."
    Assert-Condition -Condition ($personalDetailNode.cardinality.max -eq "unbounded") -Message "Expected personalDetail max cardinality to be unbounded."

    $hasTaxProcedure = Find-AttributeSource -Node $root -Source "taxProcedureGroup"
    $hasTaxFactor = Find-AttributeSource -Node $root -Source "taxFactorGroup"
    $hasTaxCompetence = Find-AttributeSource -Node $root -Source "taxCompetenceGroup"

    Assert-Condition -Condition $hasTaxProcedure -Message "Expected at least one attribute from taxProcedureGroup."
    Assert-Condition -Condition $hasTaxFactor -Message "Expected at least one attribute from taxFactorGroup."
    Assert-Condition -Condition $hasTaxCompetence -Message "Expected at least one attribute from taxCompetenceGroup."

    Write-Host ""
    Write-Host "Schema explorer checks passed." -ForegroundColor Green
}
finally {
    if (-not $KeepContainer) {
        docker rm -f $ContainerName | Out-Null
    }
}

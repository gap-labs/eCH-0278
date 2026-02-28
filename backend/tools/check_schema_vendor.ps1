param(
    [string]$RootSchemaPath = "",
    [string]$VendorRootPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RootSchemaPath)) {
    $RootSchemaPath = Join-Path $PSScriptRoot "..\schema\eCH-0278-1-0.xsd"
}
if ([string]::IsNullOrWhiteSpace($VendorRootPath)) {
    $VendorRootPath = Join-Path $PSScriptRoot "..\schema\vendor"
}

$RootSchemaPath = (Resolve-Path $RootSchemaPath).Path
if (-not (Test-Path $RootSchemaPath)) {
    throw "Root schema not found: $RootSchemaPath"
}
if (-not (Test-Path $VendorRootPath)) {
    throw "Vendor schema directory not found: $VendorRootPath"
}

function Get-ImportedUrlsFromXsd {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    [xml]$xml = Get-Content -Raw $FilePath
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsMgr.AddNamespace("xs", "http://www.w3.org/2001/XMLSchema")

    $urls = @()
    $imports = $xml.SelectNodes("//xs:import[@schemaLocation]", $nsMgr)
    foreach ($importNode in $imports) {
        $location = [string]$importNode.schemaLocation
        if ($location -match "^https?://") {
            $urls += $location
        }
    }

    return $urls
}

function Get-VendorPathForUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$VendorRoot
    )

    $uriObj = [System.Uri]$Url
    $urlHost = $uriObj.Host.ToLowerInvariant()
    $urlPath = $uriObj.AbsolutePath.TrimStart("/")
    return Join-Path $VendorRoot (Join-Path $urlHost $urlPath.Replace("/", "\\"))
}

$seenUrls = New-Object "System.Collections.Generic.HashSet[string]"
$urlQueue = New-Object System.Collections.Queue
$missingVendorFiles = New-Object System.Collections.Generic.List[string]
$invalidVendorFiles = New-Object System.Collections.Generic.List[string]

foreach ($url in (Get-ImportedUrlsFromXsd -FilePath $RootSchemaPath)) {
    $urlQueue.Enqueue($url)
}

while ($urlQueue.Count -gt 0) {
    $url = [string]$urlQueue.Dequeue()
    if ($seenUrls.Contains($url)) {
        continue
    }
    $null = $seenUrls.Add($url)

    $vendorPath = Get-VendorPathForUrl -Url $url -VendorRoot $VendorRootPath
    if (-not (Test-Path $vendorPath)) {
        $missingVendorFiles.Add("$url -> $vendorPath")
        continue
    }

    try {
        foreach ($childUrl in (Get-ImportedUrlsFromXsd -FilePath $vendorPath)) {
            if (-not $seenUrls.Contains($childUrl)) {
                $urlQueue.Enqueue($childUrl)
            }
        }
    }
    catch {
        $invalidVendorFiles.Add("$vendorPath :: $($_.Exception.Message)")
    }
}

Write-Host "Vendored schema guard summary"
Write-Host "- Root schema: $RootSchemaPath"
Write-Host "- Vendor root: $VendorRootPath"
Write-Host "- Remote imports discovered: $($seenUrls.Count)"
Write-Host "- Missing vendor files: $($missingVendorFiles.Count)"
Write-Host "- Invalid vendor files: $($invalidVendorFiles.Count)"

if ($missingVendorFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing vendored schema files:" -ForegroundColor Red
    foreach ($line in $missingVendorFiles) {
        Write-Host "- $line" -ForegroundColor Red
    }
}

if ($invalidVendorFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Invalid vendored schema files:" -ForegroundColor Red
    foreach ($line in $invalidVendorFiles) {
        Write-Host "- $line" -ForegroundColor Red
    }
}

if ($missingVendorFiles.Count -gt 0 -or $invalidVendorFiles.Count -gt 0) {
    exit 1
}

Write-Host ""
Write-Host "Vendored schema guard passed." -ForegroundColor Green

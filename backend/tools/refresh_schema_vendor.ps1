param(
    [string]$RootSchemaPath = "backend/schema/eCH-0278-1-0.xsd",
    [string]$VendorRootPath = "backend/schema/vendor",
    [switch]$CleanVendor
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path $RootSchemaPath)) {
    throw "Root schema not found: $RootSchemaPath"
}

if ($CleanVendor -and (Test-Path $VendorRootPath)) {
    Remove-Item -Recurse -Force $VendorRootPath
}

New-Item -ItemType Directory -Force -Path $VendorRootPath | Out-Null

$seenUrls = New-Object "System.Collections.Generic.HashSet[string]"
$urlQueue = New-Object System.Collections.Queue

function Get-ImportedUrlsFromXsd {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    [xml]$xml = Get-Content -Raw $FilePath
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsMgr.AddNamespace("xs", "http://www.w3.org/2001/XMLSchema")

    $results = @()
    $imports = $xml.SelectNodes("//xs:import[@schemaLocation]", $nsMgr)
    foreach ($importNode in $imports) {
        $url = [string]$importNode.schemaLocation
        if ($url -match "^https?://") {
            $results += $url
        }
    }

    return $results
}

foreach ($url in (Get-ImportedUrlsFromXsd -FilePath $RootSchemaPath)) {
    $urlQueue.Enqueue($url)
}

$downloadedCount = 0
while ($urlQueue.Count -gt 0) {
    $url = [string]$urlQueue.Dequeue()
    if ($seenUrls.Contains($url)) {
        continue
    }
    $null = $seenUrls.Add($url)

    $uriObj = [System.Uri]$url
    $urlHost = $uriObj.Host.ToLowerInvariant()
    $urlPath = $uriObj.AbsolutePath.TrimStart("/")

    $targetPath = Join-Path $VendorRootPath (Join-Path $urlHost $urlPath.Replace("/", "\\"))
    $targetDir = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    try {
        Invoke-WebRequest -Uri $url -OutFile $targetPath -TimeoutSec 30 | Out-Null
        $downloadedCount += 1
        Write-Host "Downloaded [$downloadedCount]: $url"

        foreach ($childUrl in (Get-ImportedUrlsFromXsd -FilePath $targetPath)) {
            if (-not $seenUrls.Contains($childUrl)) {
                $urlQueue.Enqueue($childUrl)
            }
        }
    }
    catch {
        Write-Warning "Failed to download $url"
        Write-Warning $_.Exception.Message
    }
}

Write-Host "Done. URLs discovered: $($seenUrls.Count), files downloaded: $downloadedCount"

param(
    [string]$FixturePath = "backend/tests/fixtures/golden_valid.declaration.xml",
    [string]$Endpoint = "http://localhost:18081/api/validate",
    [int]$MaxIterations = 40,
    [ValidateSet("declaration", "taxation")]
    [string]$TaxProcedure = "declaration"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$nsUri = "http://www.ech.ch/xmlns/eCH-0278/1"

function Get-LocalNameFromSchemaToken {
    param([string]$Token)
    if ($Token -like "eCH-0278:*") {
        return $Token.Substring("eCH-0278:".Length)
    }
    return $Token
}

function Find-ChildElement {
    param(
        [System.Xml.XmlElement]$Parent,
        [string]$LocalName,
        [bool]$UseEchNamespace
    )

    foreach ($child in $Parent.ChildNodes) {
        if (-not ($child -is [System.Xml.XmlElement])) {
            continue
        }

        if ($child.LocalName -ne $LocalName) {
            continue
        }

        if ($UseEchNamespace) {
            if ($child.NamespaceURI -eq $nsUri) {
                return $child
            }
        }
        else {
            return $child
        }
    }

    return $null
}

function Resolve-ElementBySchemaPath {
    param(
        [xml]$Doc,
        [string]$SchemaPath
    )

    if (-not $SchemaPath.StartsWith("/")) {
        return $null
    }

    $parts = @($SchemaPath.TrimStart("/").Split("/") | Where-Object { $_ -ne "" })
    if ($parts.Count -eq 0) {
        return $null
    }

    $current = $Doc.DocumentElement
    if (-not $current) {
        return $null
    }

    $rootLocal = Get-LocalNameFromSchemaToken -Token $parts[0]
    if ($current.LocalName -ne $rootLocal) {
        return $null
    }

    for ($i = 1; $i -lt $parts.Count; $i++) {
        $token = $parts[$i]
        $useNs = $token -like "eCH-0278:*"
        $local = Get-LocalNameFromSchemaToken -Token $token
        $next = Find-ChildElement -Parent $current -LocalName $local -UseEchNamespace:$useNs
        if (-not $next) {
            return $null
        }
        $current = $next
    }

    return $current
}

function Ensure-DefaultAttributes {
    param([System.Xml.XmlElement]$Element)

    if (-not $Element.HasAttribute("person")) {
        if ($Element.LocalName -in @("personalDetail")) { $Element.SetAttribute("person", "1") }
    }
    if (-not $Element.HasAttribute("taxProcedure")) {
        if ($Element.LocalName -in @("totalAmountRevenue", "totalAmountDeduction", "totalAmountAssets", "totalNetIncome", "netAssets", "income", "assets", "totalAmountDeduction", "adjustedNetIncome")) {
            $Element.SetAttribute("taxProcedure", $script:TaxProcedure)
        }
    }
    if (-not $Element.HasAttribute("taxFactor")) {
        if ($Element.LocalName -in @("totalAmountRevenue", "totalAmountDeduction", "totalAmountAssets", "totalNetIncome", "netAssets", "income", "assets", "adjustedNetIncome")) {
            $Element.SetAttribute("taxFactor", "taxable")
        }
    }
    if (-not $Element.HasAttribute("taxCompetence")) {
        if ($Element.LocalName -in @("totalAmountRevenue", "totalAmountDeduction", "totalAmountAssets", "totalNetIncome", "netAssets", "income", "assets", "adjustedNetIncome")) {
            $Element.SetAttribute("taxCompetence", "cantonal")
        }
    }

    if ([string]::IsNullOrWhiteSpace($Element.InnerText) -and $Element.ChildNodes.Count -eq 0) {
        if ($Element.LocalName -in @("totalAmountRevenue", "totalAmountDeduction", "totalAmountAssets", "totalNetIncome", "netAssets", "income", "assets", "adjustedNetIncome")) {
            $Element.InnerText = "0.00"
        }
        elseif ($Element.LocalName -in @("officialName", "firstName")) {
            $Element.InnerText = "Muster"
        }
        elseif ($Element.LocalName -in @("canton")) {
            $Element.InnerText = "BE"
        }
    }
}

function Add-ExpectedChild {
    param(
        [xml]$Doc,
        [string]$ParentSchemaPath,
        [string]$ExpectedTag
    )

    if (-not $ExpectedTag.StartsWith("eCH-0278:")) {
        return $false
    }

    $parent = Resolve-ElementBySchemaPath -Doc $Doc -SchemaPath $ParentSchemaPath
    if (-not $parent -or -not ($parent -is [System.Xml.XmlElement])) {
        return $false
    }

    $localName = $ExpectedTag.Substring("eCH-0278:".Length)
    $existing = Find-ChildElement -Parent $parent -LocalName $localName -UseEchNamespace:$true
    if ($existing) {
        return $false
    }

    $child = $Doc.CreateElement("eCH-0278", $localName, $nsUri)
    Ensure-DefaultAttributes -Element $child
    $null = $parent.AppendChild($child)
    return $true
}

function Remove-UnexpectedChild {
    param(
        [xml]$Doc,
        [string]$ParentSchemaPath,
        [string]$ChildTag
    )

    $parent = Resolve-ElementBySchemaPath -Doc $Doc -SchemaPath $ParentSchemaPath
    if (-not $parent -or -not ($parent -is [System.Xml.XmlElement])) {
        return $false
    }

    $target = $null
    if ($ChildTag.StartsWith("eCH-0278:")) {
        $localName = $ChildTag.Substring("eCH-0278:".Length)
        $target = Find-ChildElement -Parent $parent -LocalName $localName -UseEchNamespace:$true
    } else {
        foreach ($node in $parent.ChildNodes) {
            if ($node -is [System.Xml.XmlElement] -and $node.LocalName -eq $ChildTag) {
                $target = $node
                break
            }
        }
    }

    if (-not $target) { return $false }
    $null = $parent.RemoveChild($target)
    return $true
}

function Apply-MissingAttributeFix {
    param(
        [xml]$Doc,
        [string]$ElementSchemaPath,
        [string]$AttributeName
    )

    $el = Resolve-ElementBySchemaPath -Doc $Doc -SchemaPath $ElementSchemaPath
    if (-not $el -or -not ($el -is [System.Xml.XmlElement])) { return $false }

    if ($el.HasAttribute($AttributeName)) { return $false }

    switch ($AttributeName) {
        "person" { $el.SetAttribute("person", "1") }
        "taxProcedure" { $el.SetAttribute("taxProcedure", $script:TaxProcedure) }
        "taxFactor" { $el.SetAttribute("taxFactor", "taxable") }
        "taxCompetence" { $el.SetAttribute("taxCompetence", "cantonal") }
        default { return $false }
    }

    return $true
}

for ($iteration = 1; $iteration -le $MaxIterations; $iteration++) {
    $raw = curl.exe -sS -X POST $Endpoint -F "file=@$FixturePath"
    if (-not $raw) { throw "No validation response from $Endpoint" }
    $result = $raw | ConvertFrom-Json

    $errCount = @($result.errors).Count
    Write-Host "Iteration ${iteration}: xsdValid=$($result.xsdValid) errors=$errCount"

    if ($result.xsdValid -eq $true) {
        Write-Host "Validation successful."
        break
    }

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load((Resolve-Path $FixturePath))

    $changed = $false

    foreach ($validationError in $result.errors) {
        if ($validationError -match "^(?<path>/.+): The content of element '.+' is not complete\. Tag '(?<tag>[^']+)' expected\.$") {
            $changed = (Add-ExpectedChild -Doc $doc -ParentSchemaPath $matches.path -ExpectedTag $matches.tag) -or $changed
            continue
        }

        if ($validationError -match "^(?<path>/.+): Unexpected child with tag '(?<tag>[^']+)' at position \d+\.") {
            $changed = (Remove-UnexpectedChild -Doc $doc -ParentSchemaPath $matches.path -ChildTag $matches.tag) -or $changed
            continue
        }

        if ($validationError -match "^(?<path>/.+): missing required attribute '(?<attr>[^']+)'") {
            $changed = (Apply-MissingAttributeFix -Doc $doc -ElementSchemaPath $matches.path -AttributeName $matches.attr) -or $changed
            continue
        }
    }

    if (-not $changed) {
        Write-Host "No automatic fix could be applied for current error set. Stopping." -ForegroundColor Yellow
        break
    }

    $doc.Save((Resolve-Path $FixturePath))
}

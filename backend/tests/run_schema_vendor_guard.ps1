param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$TestsRoot = $PSScriptRoot
$BackendRoot = Split-Path -Parent $TestsRoot
$GuardScript = Join-Path $BackendRoot "tools\check_schema_vendor.ps1"

if (-not (Test-Path $GuardScript)) {
    throw "Guard script not found: $GuardScript"
}

Write-Host "Running schema vendor guard..."
& $GuardScript

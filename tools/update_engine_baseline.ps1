[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^4\.\d+\.\d+$') {
    throw "Use a stable Godot 4.x semantic version such as 4.7.2."
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VersionPath = Join-Path $Root ".godot-version"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($VersionPath, "$Version`n", $Utf8NoBom)
Write-Host "CI validation baseline updated to Godot $Version."
Write-Host "This does not hard-lock local development to that patch version."

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

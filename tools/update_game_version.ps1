[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z-]+)*)?$') {
    throw "Use a semantic game version such as 0.1.0 or 1.0.0-rc.1."
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VersionPath = Join-Path $Root ".game-version"
$ProjectPath = Join-Path $Root "project.godot"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText($VersionPath, $Version + "`n", $Utf8NoBom)

$Project = [System.IO.File]::ReadAllText($ProjectPath)
if ($Project -match '(?m)^config/version="[^"]*"$') {
    $Project = [regex]::Replace($Project, '(?m)^config/version="[^"]*"$', ('config/version="' + $Version + '"'))
}
else {
    $Project = $Project -replace '(?m)^config/name="GameBase"$', ('config/name="GameBase"' + "`n" + 'config/version="' + $Version + '"')
}
[System.IO.File]::WriteAllText($ProjectPath, $Project, $Utf8NoBom)

Write-Host "GameBase application version updated to $Version."
Write-Host "The Godot engine baseline remains independent in .godot-version."

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

[CmdletBinding()]
param(
    [ValidateSet("Windows Desktop", "Linux", "Web")]
    [string[]]$Preset = @("Windows Desktop", "Linux", "Web"),
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $SkipValidation) {
    & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$Outputs = @{
    "Windows Desktop" = "build/windows/GameBase.exe"
    "Linux" = "build/linux/GameBase.x86_64"
    "Web" = "build/web/index.html"
}

Push-Location $Root
try {
    foreach ($Name in $Preset) {
        $RelativeOutput = $Outputs[$Name]
        $AbsoluteOutput = Join-Path $Root $RelativeOutput
        $Parent = Split-Path -Parent $AbsoluteOutput
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null

        Write-Host ""
        Write-Host "==> Exporting $Name -> $RelativeOutput"
        & $GodotBin --headless --path $Root --export-release $Name $RelativeOutput
        if ($LASTEXITCODE -ne 0) {
            throw "Export '$Name' failed with exit code $LASTEXITCODE"
        }
        if (-not (Test-Path $AbsoluteOutput)) {
            throw "Export '$Name' did not create '$RelativeOutput'."
        }
    }

    Write-Host ""
    Write-Host "Requested exports completed."
}
finally {
    Pop-Location
}

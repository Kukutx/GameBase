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
$Packs = @{
    "Windows Desktop" = "build/windows/GameBase.pck"
    "Linux" = "build/linux/GameBase.pck"
    "Web" = "build/web/index.pck"
}

Push-Location $Root
try {
    foreach ($Name in $Preset) {
        $RelativeOutput = $Outputs[$Name]
        $AbsoluteOutput = Join-Path $Root $RelativeOutput
        $Parent = Split-Path -Parent $AbsoluteOutput
        if (Test-Path $Parent) {
            Remove-Item -Recurse -Force $Parent
        }
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null

        Write-Host ""
        Write-Host "==> Exporting $Name -> $RelativeOutput"
        $SafeName = ($Name -replace '[^A-Za-z0-9._-]', '_')
        $LogPath = Join-Path ([System.IO.Path]::GetTempPath()) ("gamebase-export-" + $SafeName + ".log")
        Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

        & $GodotBin --headless --path $Root --export-release $Name $RelativeOutput 2>&1 | Tee-Object -FilePath $LogPath
        $ExitCode = $LASTEXITCODE
        $EngineErrors = @(Select-String -Path $LogPath -Pattern '^(?:ERROR|SCRIPT ERROR):' -CaseSensitive:$false -ErrorAction SilentlyContinue)
        Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

        if ($ExitCode -ne 0) {
            throw "Export '$Name' failed with exit code $ExitCode"
        }
        if ($EngineErrors.Count -gt 0) {
            throw "Export '$Name' emitted $($EngineErrors.Count) Godot error line(s)."
        }
        if (-not (Test-Path $AbsoluteOutput)) {
            throw "Export '$Name' did not create '$RelativeOutput'."
        }

        $PackPath = $Packs[$Name]
        if (-not (Test-Path (Join-Path $Root $PackPath))) {
            throw "Export '$Name' did not create expected resource pack '$PackPath'."
        }
        & (Join-Path $PSScriptRoot "verify_export_contents.ps1") -PckPath $PackPath -GodotBin $GodotBin
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }

        # Distribution licenses stay beside the executable/Web payload rather
        # than inside the Godot PCK. This keeps development/legal documents out
        # of res:// while ensuring every packaged artifact carries notices.
        $LicenseTarget = Join-Path $Parent "licenses"
        Copy-Item -Path (Join-Path $Root "licenses") -Destination $LicenseTarget -Recurse -Force
        Copy-Item -Path (Join-Path $Root "THIRD_PARTY_NOTICES.md") -Destination (Join-Path $Parent "THIRD_PARTY_NOTICES.md") -Force
        if (-not (Test-Path (Join-Path $LicenseTarget "GODOT_LICENSE.txt")) -or
            -not (Test-Path (Join-Path $LicenseTarget "GODOT_COPYRIGHT.txt")) -or
            -not (Test-Path (Join-Path $LicenseTarget "DIALOGUE_MANAGER_LICENSE.txt")) -or
            -not (Test-Path (Join-Path $LicenseTarget "GAMEBASE_LICENSE.txt"))) {
            throw "Export '$Name' is missing required distribution license files."
        }
    }

    Write-Host ""
    Write-Host "Requested exports completed."
}
finally {
    Pop-Location
}

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
    }

    Write-Host ""
    Write-Host "Requested exports completed."
}
finally {
    Pop-Location
}

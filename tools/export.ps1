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

$GameVersionPath = Join-Path $Root ".game-version"
if (-not (Test-Path $GameVersionPath)) {
    throw "Missing .game-version."
}
$GameVersion = (Get-Content $GameVersionPath -Raw).Trim()
if ($GameVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z-]+)*)?$') {
    throw "Invalid .game-version: $GameVersion"
}
$EngineVersionOutput = & $GodotBin --version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve Godot version for BUILD_INFO.json."
}
$EngineVersion = [string]($EngineVersionOutput | Select-Object -First 1)
$GitCommit = "unknown"
$GitDirty = $true
if ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) {
    $CommitOutput = & git -C $Root rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        $GitCommit = ([string]($CommitOutput | Select-Object -First 1)).Trim()
    }
    $DirtyOutput = @(& git -C $Root status --porcelain 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $GitDirty = $DirtyOutput.Count -gt 0
    }
}
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

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

        $BuildInfo = [ordered]@{
            schema = 1
            game_version = $GameVersion
            engine = $EngineVersion
            git_commit = $GitCommit
            dirty = [bool]$GitDirty
            target = $Name
        }
        $BuildInfoJson = $BuildInfo | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText((Join-Path $Parent "BUILD_INFO.json"), $BuildInfoJson + [Environment]::NewLine, $Utf8NoBom)
    }

    Write-Host ""
    Write-Host "Requested exports completed."
}
finally {
    Pop-Location
}

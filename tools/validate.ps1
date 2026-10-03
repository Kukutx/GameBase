[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$PythonBin = $env:PYTHON_BIN,
    [switch]$SkipImport,
    [switch]$SkipSoak,
    [switch]$CleanImport
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
}
if ([string]::IsNullOrWhiteSpace($PythonBin)) {
    if ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) {
        $PythonBin = "python"
    }
    elseif ($null -ne (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $PythonBin = "python3"
    }
    else {
        throw "Python 3 is required for localization coverage validation. Install Python 3.12+ or set PYTHON_BIN."
    }
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BaselinePath = Join-Path $Root ".godot-version"
$Baseline = if (Test-Path $BaselinePath) { (Get-Content $BaselinePath -Raw).Trim() } else { "" }
$GodotLegalVersionPath = Join-Path $Root "licenses/GODOT_VERSION.txt"
$GodotLegalVersion = if (Test-Path $GodotLegalVersionPath) { (Get-Content $GodotLegalVersionPath -Raw).Trim() } else { "" }
$GameVersionPath = Join-Path $Root ".game-version"
$GameVersion = if (Test-Path $GameVersionPath) { (Get-Content $GameVersionPath -Raw).Trim() } else { "" }

function Invoke-GodotStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host ""
    Write-Host "==> $Name"
    $SafeName = ($Name -replace '[^A-Za-z0-9._-]', '_')
    $TempRoot = [System.IO.Path]::GetTempPath()
    $LogPath = Join-Path $TempRoot ("gamebase-" + $PID + "-" + $SafeName + ".log")
    Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

    & $GodotBin @Arguments 2>&1 | Tee-Object -FilePath $LogPath
    $ExitCode = $LASTEXITCODE
    $EngineErrors = @(Select-String -Path $LogPath -Pattern '^(?:ERROR|SCRIPT ERROR):' -CaseSensitive:$false -ErrorAction SilentlyContinue)
    Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

    if ($ExitCode -ne 0) {
        throw "$Name failed with exit code $ExitCode"
    }
    if ($EngineErrors.Count -gt 0) {
        throw "$Name emitted $($EngineErrors.Count) Godot error line(s)."
    }
}

Push-Location $Root
try {
    if ($CleanImport -and (Test-Path (Join-Path $Root ".godot"))) {
        Write-Host "Removing generated .godot cache for a clean validation..."
        Remove-Item -Recurse -Force (Join-Path $Root ".godot")
    }

    $VersionOutput = & $GodotBin --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not run Godot executable '$GodotBin'."
    }

    $Version = [string]($VersionOutput | Select-Object -First 1)
    Write-Host "Godot: $Version"

    if ([string]::IsNullOrWhiteSpace($GameVersion) -or $GameVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z-]+)*)?$') {
        throw "Missing or invalid .game-version. Expected semantic version such as 0.1.0 or 1.0.0-rc.1."
    }
    $ProjectText = Get-Content (Join-Path $Root "project.godot") -Raw
    $ExpectedProjectVersion = 'config/version="' + $GameVersion + '"'
    if ($ProjectText -notmatch ("(?m)^" + [regex]::Escape($ExpectedProjectVersion) + "$")) {
        throw "project.godot application version does not match .game-version ($GameVersion). Run tools/update_game_version.ps1."
    }
    Write-Host "GameBase: $GameVersion"

    if ($Version -notmatch '^4\.') {
        throw "GameBase requires Godot 4.x; detected '$Version'."
    }
    if ($Baseline -notmatch '^4\.\d+\.\d+$') {
        throw "Missing or invalid .godot-version stable 4.x baseline."
    }
    if ($GodotLegalVersion -ne $Baseline) {
        throw "Godot legal bundle version '$GodotLegalVersion' does not match .godot-version '$Baseline'. Run tools/update_engine_baseline.ps1."
    }
    $GodotLicensePath = Join-Path $Root "licenses/GODOT_LICENSE.txt"
    $GodotCopyrightPath = Join-Path $Root "licenses/GODOT_COPYRIGHT.txt"
    if (-not (Test-Path $GodotLicensePath) -or -not (Test-Path $GodotCopyrightPath)) {
        throw "Missing synchronized Godot legal files."
    }
    $GodotLicenseText = Get-Content $GodotLicensePath -Raw
    $GodotCopyrightText = Get-Content $GodotCopyrightPath -Raw
    if ($GodotLicenseText.Length -lt 500 -or $GodotLicenseText -notmatch "Godot Engine contributors") {
        throw "licenses/GODOT_LICENSE.txt does not look like the official Godot license."
    }
    if ($GodotCopyrightText.Length -lt 10000 -or $GodotCopyrightText -notmatch "Exhaustive licensing information") {
        throw "licenses/GODOT_COPYRIGHT.txt does not look like the official Godot copyright bundle."
    }

    if ($Version -notmatch ("^" + [regex]::Escape($Baseline))) {
        Write-Warning "Local Godot differs from CI baseline $Baseline. Newer stable Godot 4.x is allowed, but run the full validation before updating the shared baseline."
    }

    if (-not $SkipImport) {
        # Godot's dedicated import mode waits for importer/editor-plugin work to
        # settle before exiting. This is more deterministic than launching the
        # full editor and immediately quitting, especially on Windows headless
        # builds where GUT's editor-only font imports can otherwise race shutdown.
        Invoke-GodotStep -Name "Headless import / parse" -Arguments @(
            "--headless", "--path", $Root, "--import"
        )
    }

    Write-Host ""
    Write-Host "==> Simplified Chinese localization coverage"
    & $PythonBin "tools/check_localization.py"
    if ($LASTEXITCODE -ne 0) {
        throw "Localization coverage validation failed with exit code $LASTEXITCODE."
    }

    Write-Host ""
    Write-Host "==> Deterministic release packaging self-test"
    & $PythonBin "tools/package_release.py" "--self-test"
    if ($LASTEXITCODE -ne 0) {
        throw "Deterministic packaging self-test failed with exit code $LASTEXITCODE."
    }

    Invoke-GodotStep -Name "GUT unit tests" -Arguments @(
        "--headless", "--path", $Root,
        "-s", "addons/gut/gut_cmdln.gd",
        "-gconfig=.gutconfig.json"
    )

    Invoke-GodotStep -Name "Runtime integration smoke" -Arguments @(
        "--headless", "--path", $Root,
        "-s", "test/runtime/world_services_smoke.gd"
    )

    if (-not $SkipSoak) {
        Invoke-GodotStep -Name "Three-year save/load soak" -Arguments @(
            "--headless", "--path", $Root,
            "-s", "test/runtime/long_horizon_soak.gd"
        )
    }

    Invoke-GodotStep -Name "Main scene boot smoke" -Arguments @(
        "--headless", "--path", $Root,
        "--quit-after", "120"
    )

    Write-Host ""
    Write-Host "GameBase validation passed."
}
finally {
    Pop-Location
}

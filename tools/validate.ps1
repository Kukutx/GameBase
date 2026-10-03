[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$PythonBin = $env:PYTHON_BIN,
    [switch]$SkipImport,
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

function Invoke-GodotStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host ""
    Write-Host "==> $Name"
    $SafeName = ($Name -replace '[^A-Za-z0-9._-]', '_')
    $TempRoot = [System.IO.Path]::GetTempPath()
    $LogPath = Join-Path $TempRoot ("gamebase-" + $SafeName + ".log")
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

    if ($Version -notmatch '^4\.') {
        throw "GameBase requires Godot 4.x; detected '$Version'."
    }

    if (-not [string]::IsNullOrWhiteSpace($Baseline) -and $Version -notmatch ("^" + [regex]::Escape($Baseline))) {
        Write-Warning "Local Godot differs from CI baseline $Baseline. Newer stable Godot 4.x is allowed, but run the full validation before updating the shared baseline."
    }

    if (-not $SkipImport) {
        Invoke-GodotStep -Name "Headless import / parse" -Arguments @(
            "--headless", "--path", $Root, "--editor", "--quit"
        )
    }

    Write-Host ""
    Write-Host "==> Simplified Chinese localization coverage"
    & $PythonBin "tools/check_localization.py"
    if ($LASTEXITCODE -ne 0) {
        throw "Localization coverage validation failed with exit code $LASTEXITCODE."
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

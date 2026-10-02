[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$SkipImport
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
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
    & $GodotBin @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

Push-Location $Root
try {
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

    Invoke-GodotStep -Name "GUT unit tests" -Arguments @(
        "--headless", "--path", $Root,
        "-s", "addons/gut/gut_cmdln.gd",
        "-gconfig=.gutconfig.json"
    )

    Invoke-GodotStep -Name "Runtime integration smoke" -Arguments @(
        "--headless", "--path", $Root,
        "-s", "test/runtime/world_services_smoke.gd"
    )

    Write-Host ""
    Write-Host "GameBase validation passed."
}
finally {
    Pop-Location
}

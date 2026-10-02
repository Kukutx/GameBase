[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$SkipValidation,
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Push-Location $Root
try {
    $Required = @(
        "AGENTS.md",
        ".godot-version",
        "project.godot",
        "export_presets.cfg",
        ".github/workflows/ci.yml",
        ".github/workflows/release.yml",
        "tools/validate.ps1",
        "tools/export.ps1"
    )

    foreach ($Path in $Required) {
        if (-not (Test-Path $Path)) {
            throw "Missing required release infrastructure: $Path"
        }
    }

    $DuplicateAgentFiles = @(Get-ChildItem -Path $Root -Filter "CLAUDE.md" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.dev[\\/]' })
    if ($DuplicateAgentFiles.Count -gt 0) {
        throw "CLAUDE.md is not allowed; AGENTS.md is the project instruction source."
    }

    $TrackedLicensed = @(git ls-files -- "game/art/licensed")
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect tracked licensed assets."
    }
    if ($TrackedLicensed.Count -gt 0) {
        throw "Purchased raw art is tracked by Git. Remove it before releasing."
    }

    # Third-party addon sources are kept byte-for-byte close to upstream; some
    # upstream releases contain harmless whitespace that we should not rewrite.
    git diff --check -- . ":(exclude)addons/dialogue_manager/**" ":(exclude)addons/gut/**"
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check reported whitespace errors in project-owned files."
    }

    if (-not $SkipValidation) {
        & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if (-not $SkipExport) {
        & (Join-Path $PSScriptRoot "export.ps1") -GodotBin $GodotBin -SkipValidation
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    Write-Host ""
    Write-Host "Release readiness checks passed."
}
finally {
    Pop-Location
}

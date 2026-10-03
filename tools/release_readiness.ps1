[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$SkipValidation,
    [switch]$SkipExport,
    [switch]$SkipBrowserSmoke
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Push-Location $Root
try {
    $Required = @(
        "AGENTS.md",
        ".godot-version",
        ".game-version",
        "project.godot",
        "export_presets.cfg",
        ".github/workflows/ci.yml",
        ".github/workflows/release.yml",
        ".github/workflows/engine-compat.yml",
        "tools/validate.ps1",
        "tools/check_localization.py",
        "test/runtime/long_horizon_soak.gd",
        "dist/.gdignore",
        "tools/export.ps1",
        "tools/verify_export_contents.ps1",
        "tools/generate_release_manifest.py",
        "tools/package_release.py",
        "THIRD_PARTY_NOTICES.md",
        "licenses/GAMEBASE_LICENSE.txt",
        "licenses/GODOT_LICENSE.txt",
        "licenses/GODOT_COPYRIGHT.txt",
        "licenses/GODOT_VERSION.txt",
        "licenses/DIALOGUE_MANAGER_LICENSE.txt",
        "tools/install_export_templates.ps1",
        "tools/update_game_version.ps1",
        "tools/update_engine_baseline.ps1",
        "tools/smoke_export.ps1",
        "tools/web_smoke/.gdignore",
        "tools/web_smoke/run.js",
        "tools/web_smoke/package.json",
        "tools/web_smoke/package-lock.json"
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

    $DirtyEntries = @(git status --porcelain --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect Git working tree cleanliness."
    }
    if ($DirtyEntries.Count -gt 0) {
        Write-Host ($DirtyEntries -join [Environment]::NewLine)
        throw "Release readiness requires a clean Git working tree so BUILD_INFO.json can prove an exact commit."
    }

    # Third-party addon sources are kept byte-for-byte close to upstream; some
    # upstream releases contain harmless whitespace that we should not rewrite.
    git diff --check -- . ":(exclude)addons/dialogue_manager/**" ":(exclude)addons/gut/**"
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check reported whitespace errors in project-owned files."
    }

    if (-not $SkipValidation) {
        & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin -CleanImport
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if (-not $SkipExport) {
        & (Join-Path $PSScriptRoot "export.ps1") -GodotBin $GodotBin -SkipValidation
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        $SmokeTargets = @("Web")
        if ($env:OS -eq "Windows_NT") {
            $SmokeTargets = @("Windows", "Web")
        }
        & (Join-Path $PSScriptRoot "smoke_export.ps1") -Target $SmokeTargets
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }

        if (-not $SkipBrowserSmoke) {
            if ($null -eq (Get-Command npm -ErrorAction SilentlyContinue)) {
                throw "npm is required for the Web browser smoke. Install Node.js 24+ or use -SkipBrowserSmoke."
            }
            Write-Host ""
            Write-Host "==> Installing deterministic Web smoke dependencies"
            & npm ci --prefix tools/web_smoke --ignore-scripts
            if ($LASTEXITCODE -ne 0) {
                throw "npm ci failed with exit code $LASTEXITCODE."
            }

            Write-Host ""
            Write-Host "==> Ensuring Playwright Chromium is installed"
            & npm exec --prefix tools/web_smoke -- playwright install chromium
            if ($LASTEXITCODE -ne 0) {
                throw "Playwright Chromium installation failed with exit code $LASTEXITCODE."
            }

            Write-Host ""
            Write-Host "==> Browser smoke Web export"
            & npm run --prefix tools/web_smoke smoke:web
            if ($LASTEXITCODE -ne 0) {
                throw "Web browser smoke failed with exit code $LASTEXITCODE."
            }
        }

        $PythonCommand = $env:PYTHON_BIN
        if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
            if ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) {
                $PythonCommand = "python"
            }
            elseif ($null -ne (Get-Command python3 -ErrorAction SilentlyContinue)) {
                $PythonCommand = "python3"
            }
            else {
                throw "Python 3.12+ is required for deterministic release packaging."
            }
        }

        Write-Host ""
        Write-Host "==> Deterministic release archives"
        $DistRoot = Join-Path $Root "dist"
        New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
        Get-ChildItem -Path $DistRoot -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".gdignore" } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        & $PythonCommand "tools/package_release.py" "--target" "All"
        if ($LASTEXITCODE -ne 0) {
            throw "Deterministic release packaging failed with exit code $LASTEXITCODE."
        }

        Write-Host ""
        Write-Host "==> Release package identity + manifest"
        & $PythonCommand "tools/generate_release_manifest.py" "--dist" "dist"
        if ($LASTEXITCODE -ne 0) {
            throw "Release manifest generation failed with exit code $LASTEXITCODE."
        }
    }

    Write-Host ""
    Write-Host "Release readiness checks passed."
}
finally {
    Pop-Location
}

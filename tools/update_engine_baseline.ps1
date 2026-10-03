[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^4\.\d+\.\d+$') {
    throw "Use a stable Godot 4.x semantic version such as 4.7.2."
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VersionPath = Join-Path $Root ".godot-version"
$LicensesRoot = Join-Path $Root "licenses"
$LicenseVersionPath = Join-Path $LicensesRoot "GODOT_VERSION.txt"
$LicensePath = Join-Path $LicensesRoot "GODOT_LICENSE.txt"
$CopyrightPath = Join-Path $LicensesRoot "GODOT_COPYRIGHT.txt"
$DevRoot = Join-Path $Root ".dev"
New-Item -ItemType Directory -Force -Path $DevRoot, $LicensesRoot | Out-Null
if (-not (Test-Path (Join-Path $DevRoot ".gdignore"))) {
    New-Item -ItemType File -Force -Path (Join-Path $DevRoot ".gdignore") | Out-Null
}

$Tag = "$Version-stable"
$LicenseUri = "https://raw.githubusercontent.com/godotengine/godot/$Tag/LICENSE.txt"
$CopyrightUri = "https://raw.githubusercontent.com/godotengine/godot/$Tag/COPYRIGHT.txt"
$TempLicense = Join-Path $DevRoot "godot-license-$Version.tmp"
$TempCopyright = Join-Path $DevRoot "godot-copyright-$Version.tmp"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    Write-Host "Downloading official Godot $Tag legal files..."
    Invoke-WebRequest -Uri $LicenseUri -OutFile $TempLicense
    Invoke-WebRequest -Uri $CopyrightUri -OutFile $TempCopyright

    $LicenseText = [System.IO.File]::ReadAllText($TempLicense)
    $CopyrightText = [System.IO.File]::ReadAllText($TempCopyright)
    if ($LicenseText.Length -lt 500 -or $LicenseText -notmatch 'Godot Engine contributors') {
        throw "Downloaded LICENSE.txt does not look like the official Godot license for $Tag."
    }
    if ($CopyrightText.Length -lt 10000 -or $CopyrightText -notmatch 'Exhaustive licensing information') {
        throw "Downloaded COPYRIGHT.txt does not look like the official Godot copyright bundle for $Tag."
    }

    # Only commit the version move after both official files are available and
    # validated, so a network/404 failure cannot leave a half-upgraded baseline.
    [System.IO.File]::WriteAllText($VersionPath, $Version + "`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($LicenseVersionPath, $Version + "`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($LicensePath, $LicenseText, $Utf8NoBom)
    [System.IO.File]::WriteAllText($CopyrightPath, $CopyrightText, $Utf8NoBom)

    Write-Host "CI validation baseline updated to Godot $Version."
    Write-Host "Official Godot LICENSE/COPYRIGHT synchronized to the same stable tag."
    Write-Host "This does not hard-lock local development to that patch version."
}
finally {
    Remove-Item $TempLicense, $TempCopyright -Force -ErrorAction SilentlyContinue
}

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    & (Join-Path $PSScriptRoot "validate.ps1") -GodotBin $GodotBin
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

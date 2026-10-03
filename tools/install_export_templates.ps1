[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$CacheDirectory = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DevRoot = Join-Path $Root ".dev"
New-Item -ItemType Directory -Force -Path $DevRoot | Out-Null
$DevIgnore = Join-Path $DevRoot ".gdignore"
if (-not (Test-Path $DevIgnore)) {
    New-Item -ItemType File -Force -Path $DevIgnore | Out-Null
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content (Join-Path $Root ".godot-version") -Raw).Trim()
}
if ($Version -notmatch '^4\.\d+\.\d+$') {
    throw "Expected a stable Godot 4.x version such as 4.7.2; got '$Version'."
}

if ([string]::IsNullOrWhiteSpace($CacheDirectory)) {
    $CacheDirectory = Join-Path $Root ".dev\export-templates"
}
New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null

$StableName = "$Version.stable"
$Destination = Join-Path $env:APPDATA "Godot\export_templates\$StableName"
$Package = Join-Path $CacheDirectory "Godot_v$Version-stable_export_templates.tpz"
$Url = "https://github.com/godotengine/godot/releases/download/$Version-stable/Godot_v$Version-stable_export_templates.tpz"

$Required = @(
    "windows_release_x86_64.exe",
    "linux_release.x86_64",
    "web_nothreads_release.zip"
)
if (-not $Force -and (Test-Path $Destination)) {
    $Missing = @($Required | Where-Object { -not (Test-Path (Join-Path $Destination $_)) })
    if ($Missing.Count -eq 0) {
        Write-Host "Godot $Version export templates are already installed."
        Write-Host $Destination
        exit 0
    }
}

Write-Host "Downloading Godot $Version export templates (resumable)..."
& curl.exe -L --fail --retry 3 -C - -o $Package $Url
if ($LASTEXITCODE -ne 0) {
    throw "Export-template download failed with exit code $LASTEXITCODE."
}

$ExtractRoot = Join-Path $CacheDirectory "extract-$Version"
if (Test-Path $ExtractRoot) {
    Remove-Item -Recurse -Force $ExtractRoot
}
New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($Package, $ExtractRoot)

$Source = Join-Path $ExtractRoot "templates"
if (-not (Test-Path $Source)) {
    $Candidate = Get-ChildItem -Path $ExtractRoot -Directory | Select-Object -First 1
    if ($null -ne $Candidate -and (Test-Path (Join-Path $Candidate.FullName "version.txt"))) {
        $Source = $Candidate.FullName
    }
}
if (-not (Test-Path $Source)) {
    throw "Could not locate the templates directory inside '$Package'."
}

if (Test-Path $Destination) {
    Remove-Item -Recurse -Force $Destination
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force

$Missing = @($Required | Where-Object { -not (Test-Path (Join-Path $Destination $_)) })
if ($Missing.Count -gt 0) {
    throw "Template installation is incomplete. Missing: $($Missing -join ', ')"
}

Remove-Item -Recurse -Force $ExtractRoot
Write-Host "Installed Godot $Version export templates:"
Write-Host $Destination
